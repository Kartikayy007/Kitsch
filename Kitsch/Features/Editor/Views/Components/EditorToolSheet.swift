//
//  EditorToolSheet.swift
//  Kitsch
//
//  Created by kartikay on 10/07/26.
//

import SwiftUI

struct EditorToolSheet: View {
    let tool: EditorTool
    @Binding var background: EditorBackground
    @Binding var stickers: [EditorSticker]
    @Binding var selectedStickerID: EditorSticker.ID?
    @Binding var stickerLibrary: [StickerAsset]
    let onAddSticker: (EditorSticker) -> Void
    let onBackgroundChanged: () -> Void
    let onBackgroundRemovalStart: () -> Void
    let onBackgroundRemovalFinished: (StickerAsset) -> Void
    let onBackgroundRemovalFailed: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if tool == .background {
                BackgroundSheetView(
                    background: $background,
                    onCommit: onBackgroundChanged
                )
            } else if tool == .stickers {
                StickersSheetView(
                    stickerLibrary: stickerLibrary,
                    onAddSticker: onAddSticker,
                    onBackgroundRemovalStart: onBackgroundRemovalStart,
                    onBackgroundRemovalFinished: onBackgroundRemovalFinished,
                    onBackgroundRemovalFailed: onBackgroundRemovalFailed
                )
            } else if tool == .layers {
                LayersSheetView(
                    stickers: $stickers,
                    selectedStickerID: $selectedStickerID
                )
            } else {
                emptySheet
            }
        }
        .presentationBackground(.regularMaterial)
        .presentationCornerRadius(30)
    }

    private var emptySheet: some View {
        NavigationStack {
            Color.clear
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(tool.title)
                            .fontWeight(.semibold)
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.regularMaterial)
    }
}

#Preview {
    EditorToolSheet(
        tool: .background,
        background: .constant(.defaultColor),
        stickers: .constant([]),
        selectedStickerID: .constant(nil),
        stickerLibrary: .constant([]),
        onAddSticker: { _ in },
        onBackgroundChanged: {},
        onBackgroundRemovalStart: {},
        onBackgroundRemovalFinished: { _ in },
        onBackgroundRemovalFailed: { _ in }
    )
}
