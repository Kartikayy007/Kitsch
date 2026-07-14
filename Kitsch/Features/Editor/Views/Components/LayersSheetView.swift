//
//  LayersSheetView.swift
//  Kitsch
//

import SwiftUI
import UIKit

struct LayersSheetView: View {
    @Binding var stickers: [EditorSticker]
    @Binding var selectedStickerID: EditorSticker.ID?

    var body: some View {
        NavigationStack {
            Group {
                if stickers.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(displayLayers) { layer in
                            LayerRow(
                                sticker: layer.sticker,
                                isSelected: selectedStickerID == layer.id,
                                onSelect: {
                                    selectedStickerID = layer.id
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .onMove(perform: moveDisplayLayers)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(.active))
                }
            }
            .navigationTitle("Layers")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.regularMaterial)
        .presentationCornerRadius(30)
    }

    private var displayLayers: [LayerItem] {
        Array(stickers.reversed()).map { sticker in
            LayerItem(id: sticker.id, sticker: sticker)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No layers yet")
                .font(.headline)

            Text("Add a sticker or photo cutout first. It will show up here and you can drag to reorder it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
    }

    private func moveDisplayLayers(from source: IndexSet, to destination: Int) {
        var reorderedDisplay = displayLayers
        reorderedDisplay.move(fromOffsets: source, toOffset: destination)

        let currentStickers = stickers
        let reorderedIDs = reorderedDisplay.map(\.id)

        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            stickers = reorderedIDs.reversed().compactMap { id in
                currentStickers.first(where: { $0.id == id })
            }
        }
    }
}

private struct LayerItem: Identifiable {
    let id: EditorSticker.ID
    let sticker: EditorSticker
}

private struct LayerRow: View {
    let sticker: EditorSticker
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(sticker.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(isSelected ? "Selected" : "Drag to reorder")
                    .font(.footnote)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }

            Spacer(minLength: 12)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isSelected ? Color.primary : Color.primary.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: onSelect)
    }

    private var thumbnail: some View {
        Group {
            switch sticker.content {
            case let .image(data):
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else {
                    placeholderThumbnail
                }
            }
        }
        .frame(width: 64, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var placeholderThumbnail: some View {
        Image(systemName: "photo")
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(.secondary)
    }
}

#Preview {
    LayersSheetView(
        stickers: .constant([]),
        selectedStickerID: .constant(nil)
    )
}
