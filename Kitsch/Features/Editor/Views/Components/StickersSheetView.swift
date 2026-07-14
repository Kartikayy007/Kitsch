//
//  StickersSheetView.swift
//  Kitsch
//

import ImagePlayground
import Photos
import PhotosUI
import SwiftUI
import UIKit

struct StickersSheetView: View {
    let stickerLibrary: [StickerAsset]
    let onAddSticker: (EditorSticker) -> Void
    let onBackgroundRemovalStart: () -> Void
    let onBackgroundRemovalFinished: (StickerAsset) -> Void
    let onBackgroundRemovalFailed: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isGenmojiPresented = false

    private let libraryColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Create new")
                            .font(.title2.weight(.bold))
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                genmojiOption
                                photoOption
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    if !stickerLibrary.isEmpty {
                        librarySection
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .navigationTitle("Stickers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.regularMaterial)
        .presentationCornerRadius(30)
        .imagePlaygroundSheet(
            isPresented: $isGenmojiPresented,
            concepts: [],
            sourceImage: nil,
            onCompletion: { url in
                guard let data = try? Data(contentsOf: url), UIImage(data: data) != nil else {
                    return
                }
                onAddSticker(EditorSticker(name: "Genmoji", content: .image(data)))
                dismiss()
            },
            onCancellation: nil
        )
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                await MainActor.run {
                    selectedPhoto = nil
                    dismiss()
                    onBackgroundRemovalStart()
                }

                let stickerName = await photoName(for: item)

                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    await MainActor.run {
                        onBackgroundRemovalFailed("No subject found.")
                    }
                    return
                }

                let cutout = try? await ForegroundCutout.make(from: data)
                guard let cutout else {
                    await MainActor.run {
                        onBackgroundRemovalFailed("No subject found.")
                    }
                    return
                }

                await MainActor.run {
                    onBackgroundRemovalFinished(
                        StickerAsset(name: stickerName, content: .image(cutout))
                    )
                }
            }
        }
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Created stickers")
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 20)

            LazyVGrid(columns: libraryColumns, spacing: 12) {
                ForEach(stickerLibrary) { asset in
                    Button {
                        onAddSticker(asset.makeSticker())
                        dismiss()
                    } label: {
                        StickerLibraryCell(asset: asset)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func photoName(for item: PhotosPickerItem) async -> String {
        guard let itemIdentifier = item.itemIdentifier else {
            return "Photo"
        }

        return await MainActor.run {
            let results = PHAsset.fetchAssets(withLocalIdentifiers: [itemIdentifier], options: nil)
            guard let asset = results.firstObject,
                  let resource = PHAssetResource.assetResources(for: asset).first else {
                return "Photo"
            }

            let filename = resource.originalFilename
            let trimmed = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
            return trimmed.isEmpty ? "Photo" : trimmed
        }
    }

    private var genmojiOption: some View {
        Button {
            isGenmojiPresented = true
        } label: {
            StickerSourceButton(
                title: "Emoji & Genmoji",
                systemImage: "face.smiling"
            )
        }
        .buttonStyle(.plain)
        .disabled(!supportsImagePlayground)
        .opacity(supportsImagePlayground ? 1 : 0.45)
        .accessibilityHint(
            supportsImagePlayground
                ? "Opens the Genmoji creator"
                : "Genmoji is unavailable on this device"
        )
    }

    private var photoOption: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            StickerSourceButton(title: "Photos", systemImage: "photo.stack")
        }
        .buttonStyle(.plain)
    }
}

private struct StickerLibraryCell: View {
    let asset: StickerAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            thumbnail

            Text(asset.name)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
    }

    private var thumbnail: some View {
        Group {
            switch asset.content {
            case let .image(data):
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(height: 112)
    }
}

private struct StickerSourceButton: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .medium))
                .frame(width: 68, height: 68)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(width: 118)
        }
        .foregroundStyle(.primary)
        .frame(width: 142, height: 148)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

#Preview {
    StickersSheetView(
        stickerLibrary: [],
        onAddSticker: { _ in },
        onBackgroundRemovalStart: {},
        onBackgroundRemovalFinished: { _ in },
        onBackgroundRemovalFailed: { _ in }
    )
}
