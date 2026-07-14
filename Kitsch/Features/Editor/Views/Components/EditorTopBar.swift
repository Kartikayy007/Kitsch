//
//  EditorTopBar.swift
//  Kitsch
//
//  Created by kartikay on 10/07/26.
//

import SwiftUI

struct EditorTopBar: ToolbarContent {
    let canUndo: Bool
    let canRedo: Bool
    let onClose: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onHistory: () -> Void
    let onSave: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close")
        }

        ToolbarItemGroup(placement: .principal) {
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!canUndo)
            .accessibilityLabel("Undo")

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!canRedo)
            .accessibilityLabel("Redo")

            Button(action: onHistory) {
                Image(systemName: "clock.arrow.circlepath")
            }
            .accessibilityLabel("History")
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(action: onSave) {
                Image(systemName: "checkmark")
            }
            .accessibilityLabel("Save")
        }
    }
}
