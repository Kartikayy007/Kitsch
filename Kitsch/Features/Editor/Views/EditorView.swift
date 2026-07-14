//
//  EditorView.swift
//  Kitsch
//
//  Created by kartikay on 10/07/26.
//

import SwiftUI

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var background = EditorBackground.defaultColor
    @State private var stickers: [EditorSticker] = []
    @State private var stickerLibrary: [StickerAsset] = []
    @State private var selectedStickerID: EditorSticker.ID?
    @State private var selectedTool: EditorTool?
    @State private var presentedTool: EditorTool?
    @State private var snipStickerID: EditorSticker.ID?
    @State private var undoStack: [EditorSnapshot] = []
    @State private var redoStack: [EditorSnapshot] = []
    @State private var backgroundRemovalOverlay = BackgroundRemovalOverlayState()
    @State private var backgroundRemovalSessionID = UUID()
    @State private var backgroundRemovalError: String?
    @State private var backgroundRemovalEntryFinished = false
    @State private var backgroundRemovalResult: StickerAsset?
    @State private var backgroundRemovalFailure: String?
    @State private var backgroundRemovalDismissalScheduled = false

    var body: some View {
        NavigationStack {
            canvas
                .ignoresSafeArea()
                .toolbar { editorToolbar }
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarBackground(.visible, for: .bottomBar)
                .sheet(item: $presentedTool, content: toolSheet)
                .fullScreenCover(item: snipSheetItem) { item in
                    if let sticker = stickers.first(where: { $0.id == item.id }) {
                        SnipSheetView(
                            sticker: sticker,
                            onCancel: { snipStickerID = nil },
                            onSave: { result in
                                applySnipResult(result, to: item.id)
                            }
                        )
                    }
                }
                .alert("Couldn't create sticker", isPresented: backgroundRemovalErrorIsPresented) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(backgroundRemovalError ?? "Try another image.")
                }
                .task {
                    ensureInitialSnapshot()
                }
        }
    }

    private var canvas: some View {
        ZStack {
            EditorCanvasView(
                scale: $scale,
                background: $background,
                stickers: $stickers,
                selectedStickerID: $selectedStickerID,
                isBackgroundTransformEnabled: selectedTool == .background && presentedTool == nil,
                onStickerTransformCommitted: { commitSnapshot() },
                onBackgroundTransformCommitted: { commitSnapshot() },
                onRequestSnip: { snipStickerID = $0 },
                onDeleteSticker: { _ in commitSnapshot() },
                onDuplicateSticker: { _ in commitSnapshot() }
            )
            .blur(radius: backgroundRemovalOverlay.isVisible ? 16 : 0)
            .scaleEffect(backgroundRemovalOverlay.isVisible ? 0.985 : 1)
            .animation(.easeInOut(duration: 1), value: backgroundRemovalOverlay.isVisible)

            if backgroundRemovalOverlay.isVisible {
                BackgroundRemovalOverlayView(
                    message: backgroundRemovalOverlay.message,
                    progress: backgroundRemovalOverlay.progress
                )
                .transition(.opacity)
            }
        }
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(undoStack.count < 2)
        }

        ToolbarItem(placement: .topBarLeading) {
            Button {
                redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(redoStack.isEmpty)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "checkmark")
            }
        }

        ToolbarItemGroup(placement: .bottomBar) {
            ForEach(EditorTool.allCases) { tool in
                bottomToolButton(tool)
            }
        }
    }

    private func bottomToolButton(_ tool: EditorTool) -> some View {
        Button {
            selectedTool = tool
            if tool.opensSheet {
                presentedTool = tool
            }
        } label: {
            Label(tool.title, systemImage: tool.systemImage)
        }
        .labelStyle(.iconOnly)
        .tint(selectedTool == tool ? Color.primary : Color.secondary)
    }

    private func toolSheet(_ tool: EditorTool) -> some View {
        EditorToolSheet(
            tool: tool,
            background: $background,
            stickers: $stickers,
            selectedStickerID: $selectedStickerID,
            stickerLibrary: $stickerLibrary,
            onAddSticker: addStickerToCanvas,
            onBackgroundChanged: {
                commitSnapshot()
                presentedTool = nil
            },
            onBackgroundRemovalStart: beginBackgroundRemoval,
            onBackgroundRemovalFinished: finishBackgroundRemoval,
            onBackgroundRemovalFailed: failBackgroundRemoval
        )
    }

    private var snipSheetItem: Binding<SnipStickerSheetItem?> {
        Binding(
            get: {
                guard let snipStickerID else { return nil }
                return SnipStickerSheetItem(id: snipStickerID)
            },
            set: { value in
                snipStickerID = value?.id
            }
        )
    }

    private var backgroundRemovalErrorIsPresented: Binding<Bool> {
        Binding(
            get: { backgroundRemovalError != nil },
            set: { isPresented in
                if !isPresented {
                    backgroundRemovalError = nil
                }
            }
        )
    }

    private func addStickerToCanvas(_ sticker: EditorSticker) {
        stickers.append(sticker)
        selectedStickerID = sticker.id
        commitSnapshot()
    }

    private func addStickerToCanvas(from asset: StickerAsset) {
        addStickerToCanvas(asset.makeSticker())
    }

    private func ensureInitialSnapshot() {
        guard undoStack.isEmpty else { return }
        undoStack = [currentSnapshot]
        redoStack = []
    }

    private var currentSnapshot: EditorSnapshot {
        EditorSnapshot(
            canvasScale: scale,
            background: background,
            stickers: stickers,
            selectedStickerID: selectedStickerID
        )
    }

    private func apply(snapshot: EditorSnapshot) {
        scale = snapshot.canvasScale
        background = snapshot.background
        stickers = snapshot.stickers
        selectedStickerID = snapshot.selectedStickerID
    }

    private func commitSnapshot() {
        ensureInitialSnapshot()
        let snapshot = currentSnapshot
        guard undoStack.last != snapshot else { return }
        undoStack.append(snapshot)
        if undoStack.count > 7 {
            undoStack.removeFirst(undoStack.count - 7)
        }
        redoStack.removeAll()
    }

    private func undo() {
        guard undoStack.count > 1 else { return }
        let snapshot = undoStack.removeLast()
        redoStack.append(snapshot)
        if redoStack.count > 7 {
            redoStack.removeFirst(redoStack.count - 7)
        }
        if let previous = undoStack.last {
            apply(snapshot: previous)
        }
    }

    private func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(snapshot)
        if undoStack.count > 7 {
            undoStack.removeFirst(undoStack.count - 7)
        }
        apply(snapshot: snapshot)
    }

    private func applySnipResult(_ result: SnipSheetResult, to id: EditorSticker.ID) {
        guard let index = stickers.firstIndex(where: { $0.id == id }) else {
            snipStickerID = nil
            return
        }

        stickers[index].content = .image(result.data)
        stickers[index].name = result.name
        stickers[index].editingSourceData = result.editingSourceData
        stickers[index].editState = result.editState
        snipStickerID = nil
        commitSnapshot()
    }

    private func beginBackgroundRemoval() {
        backgroundRemovalSessionID = UUID()
        presentedTool = nil
        backgroundRemovalOverlay.progress = 0.14
        backgroundRemovalEntryFinished = false
        backgroundRemovalResult = nil
        backgroundRemovalFailure = nil
        backgroundRemovalDismissalScheduled = false

        withAnimation(.easeInOut(duration: 1)) {
            backgroundRemovalOverlay.isVisible = true
        }

        let sessionID = backgroundRemovalSessionID
        Task {
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                guard backgroundRemovalSessionID == sessionID,
                      backgroundRemovalOverlay.isVisible else { return }

                backgroundRemovalEntryFinished = true
                withAnimation(.easeInOut(duration: 0.9)) {
                    backgroundRemovalOverlay.progress = 0.78
                }
                scheduleBackgroundRemovalDismissalIfReady()
            }
        }
    }

    private func finishBackgroundRemoval(_ asset: StickerAsset) {
        backgroundRemovalResult = asset
        scheduleBackgroundRemovalDismissalIfReady()
    }

    private func failBackgroundRemoval(_ message: String) {
        backgroundRemovalFailure = message
        scheduleBackgroundRemovalDismissalIfReady()
    }

    private func scheduleBackgroundRemovalDismissalIfReady() {
        guard backgroundRemovalEntryFinished,
              backgroundRemovalResult != nil || backgroundRemovalFailure != nil,
              !backgroundRemovalDismissalScheduled else {
            return
        }

        backgroundRemovalDismissalScheduled = true
        let sessionID = backgroundRemovalSessionID

        Task {
            // Keep a completed fast cutout visibly loading after entrance settles.
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                guard backgroundRemovalSessionID == sessionID else { return }

                if let asset = backgroundRemovalResult {
                    stickerLibrary.insert(asset, at: 0)
                    addStickerToCanvas(from: asset)
                }

                withAnimation(.easeInOut(duration: 0.2)) {
                    backgroundRemovalOverlay.progress = 1
                }
                withAnimation(.easeInOut(duration: 1)) {
                    backgroundRemovalOverlay.isVisible = false
                }
            }

            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                guard backgroundRemovalSessionID == sessionID else { return }

                if let failure = backgroundRemovalFailure {
                    backgroundRemovalError = failure
                }

                backgroundRemovalOverlay.progress = 0.12
                backgroundRemovalEntryFinished = false
                backgroundRemovalResult = nil
                backgroundRemovalFailure = nil
                backgroundRemovalDismissalScheduled = false
            }
        }
    }
}

#Preview {
    EditorView()
}

private struct BackgroundRemovalOverlayView: View {
    let message: String
    let progress: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)

                ProgressView(value: progress, total: 1)
                    .progressViewStyle(.linear)
                    .tint(.white)

                Text(message)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(maxWidth: 300)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }
}
