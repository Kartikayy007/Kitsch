//
//  BackgroundSheetView.swift
//  Kitsch
//
//  Created by kartikay on 10/07/26.
//

import ImagePlayground
import PhotosUI
import SwiftUI
import UIKit

struct BackgroundSheetView: View {
    @Binding var background: EditorBackground
    let onCommit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var prompt = ""
    @State private var isImagePlaygroundPresented = false

    private let solidColors: [SolidBackground] = [
        .init(id: "blue", colorValue: .init(red: 0.25, green: 0.55, blue: 0.95)),
        .init(id: "indigo", colorValue: .init(red: 0.35, green: 0.3, blue: 0.85)),
        .init(id: "pink", colorValue: .init(red: 0.95, green: 0.4, blue: 0.6)),
        .init(id: "orange", colorValue: .init(red: 0.95, green: 0.5, blue: 0.25)),
        .init(id: "yellow", colorValue: .init(red: 0.95, green: 0.8, blue: 0.25)),
        .init(id: "green", colorValue: .init(red: 0.25, green: 0.75, blue: 0.45)),
        .init(id: "teal", colorValue: .init(red: 0.2, green: 0.7, blue: 0.75)),
        .init(id: "gray", colorValue: .init(red: 0.45, green: 0.45, blue: 0.45)),
        .init(id: "black", colorValue: .init(red: 0.12, green: 0.12, blue: 0.12))
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Image")
                        .font(.headline.weight(.semibold))
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            photoPicker
                            imagePlaygroundOption
                        }
                        .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Playground prompt")
                            .font(.headline.weight(.semibold))
                            .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Describe portrait background", text: $prompt, axis: .vertical)
                                .textFieldStyle(.plain)
                                .foregroundStyle(.primary)
                                .lineLimit(2 ... 4)

                            HStack {
                                Label("Portrait", systemImage: "rectangle.portrait")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button("Open Playground") {
                                    isImagePlaygroundPresented = true
                                }
                                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !supportsImagePlayground)
                            }
                        }
                        .padding(16)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Colour")
                            .font(.headline.weight(.semibold))
                            .padding(.horizontal, 20)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                            ForEach(solidColors) { item in
                                Button {
                                    background = .color(item.colorValue)
                                    onCommit()
                                    dismiss()
                                } label: {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(item.colorValue.color)
                                        .frame(height: 112)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .navigationTitle("Background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.regularMaterial)
        .presentationCornerRadius(30)
        .imagePlaygroundSheet(
            isPresented: $isImagePlaygroundPresented,
            concept: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceImage: nil,
            onCompletion: { url in
                guard let data = try? Data(contentsOf: url), UIImage(data: data) != nil else { return }
                background = .image(EditorBackgroundImage(data: data))
                onCommit()
                dismiss()
            },
            onCancellation: nil
        )
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      UIImage(data: data) != nil else {
                    return
                }

                await MainActor.run {
                    selectedPhoto = nil
                    background = .image(EditorBackgroundImage(data: data))
                    onCommit()
                    dismiss()
                }
            }
        }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            sourceButton(title: "Photos", systemImage: "photo.stack")
        }
        .buttonStyle(.plain)
    }

    private var imagePlaygroundOption: some View {
        Button {
            isImagePlaygroundPresented = true
        } label: {
            sourceButton(title: "Image Playground", systemImage: "sparkles")
        }
        .buttonStyle(.plain)
        .disabled(!supportsImagePlayground)
        .opacity(supportsImagePlayground ? 1 : 0.45)
    }

    private func sourceButton(title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .medium))
                .frame(width: 66, height: 66)

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

private struct SolidBackground: Identifiable {
    let id: String
    let colorValue: EditorColorValue
}

#Preview {
    BackgroundSheetView(background: .constant(.defaultColor), onCommit: {})
}
