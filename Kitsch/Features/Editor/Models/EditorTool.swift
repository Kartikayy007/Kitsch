//
//  EditorTool.swift
//  Kitsch
//
//  Created by kartikay on 10/07/26.
//

import Foundation

enum EditorTool: String, Identifiable, CaseIterable {
    case background
    case stickers
    case layers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .background: "Background"
        case .stickers: "Stickers"
        case .layers: "Layers"
        }
    }

    var systemImage: String {
        switch self {
        case .background: "photo.on.rectangle"
        case .stickers: "face.smiling"
        case .layers: "square.2.layers.3d.bottom.filled"
        }
    }

    var opensSheet: Bool { true }
}
