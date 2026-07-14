//
//  EditorSticker.swift
//  Kitsch
//

import Foundation
import CoreGraphics

struct EditorSticker: Identifiable, Equatable {
    enum Content: Equatable {
        case image(Data)
    }

    let id: UUID
    var name: String
    var content: Content
    var editingSourceData: Data?
    var editState: StickerEditState = .default
    var offset: CGSize = .zero
    var scale: CGFloat = 1
    var rotation: CGFloat = 0

    init(
        id: UUID = UUID(),
        name: String,
        content: Content,
        editingSourceData: Data? = nil,
        editState: StickerEditState = .default,
        offset: CGSize = .zero,
        scale: CGFloat = 1,
        rotation: CGFloat = 0
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.editingSourceData = editingSourceData
        self.editState = editState
        self.offset = offset
        self.scale = scale
        self.rotation = rotation
    }
}

struct StickerEditState: Equatable {
    var adjustmentValues = StickerAdjustmentValues()
    var style: StickerStylePreset = .original
    var cropScale: CGFloat = 1
    var cropOffset: CGSize = .zero

    static let `default` = StickerEditState()
}

struct StickerAdjustmentValues: Equatable {
    var brilliance: Double = 0
    var exposure: Double = 0
    var contrast: Double = 0
    var saturation: Double = 0
    var warmth: Double = 0
    var definition: Double = 0
}

enum StickerStylePreset: String, CaseIterable, Equatable {
    case original
    case chrome
    case fade
    case instant
    case noir
    case process
    case tonal
    case transfer

    var title: String {
        switch self {
        case .original: "Original"
        case .chrome: "Vivid"
        case .fade: "Fade"
        case .instant: "Instant"
        case .noir: "Noir"
        case .process: "Process"
        case .tonal: "Tonal"
        case .transfer: "Transfer"
        }
    }
}

struct StickerAsset: Identifiable {
    let id: UUID
    let name: String
    let content: EditorSticker.Content

    init(id: UUID = UUID(), name: String, content: EditorSticker.Content) {
        self.id = id
        self.name = name
        self.content = content
    }

    func makeSticker() -> EditorSticker {
        EditorSticker(name: name, content: content)
    }
}

struct BackgroundRemovalOverlayState {
    var isVisible = false
    var progress: Double = 0.12
    var message = "Removing background"
}
