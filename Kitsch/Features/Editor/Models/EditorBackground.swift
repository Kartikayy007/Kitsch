//
//  EditorBackground.swift
//  Kitsch
//

import Foundation
import CoreGraphics
import SwiftUI

struct EditorColorValue: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double = 1

    init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    init(color: Color) {
        #if canImport(UIKit)
        let resolved = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        self.init(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            opacity: Double(opacity)
        )
        #else
        self.init(red: 0.12, green: 0.12, blue: 0.12, opacity: 1)
        #endif
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

struct EditorBackgroundImage: Equatable {
    var data: Data
    var offset: CGSize = .zero
    var scale: CGFloat = 1
}

enum EditorBackground: Equatable {
    case color(EditorColorValue)
    case image(EditorBackgroundImage)

    static let defaultColor = EditorBackground.color(
        EditorColorValue(red: 0.12, green: 0.12, blue: 0.12)
    )
}

struct EditorSnapshot: Equatable {
    var canvasScale: CGFloat
    var background: EditorBackground
    var stickers: [EditorSticker]
    var selectedStickerID: EditorSticker.ID?
}
