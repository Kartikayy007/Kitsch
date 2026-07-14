//
//  EditorViewModel.swift
//  Kitsch
//
//  Created by kartikay on 10/07/26.
//

import Foundation
import Observation
import CoreGraphics

@Observable
final class EditorViewModel {
    var title: String = "Editor"
    var scale: CGFloat = 1.0
    var isHistoryPresented: Bool = false

    private(set) var undoStack: [EditorHistoryEntry]
    private(set) var redoStack: [EditorHistoryEntry] = []

    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 3.0

    var canUndo: Bool { undoStack.count > 1 }
    var canRedo: Bool { !redoStack.isEmpty }

    var historyEntriesNewestFirst: [EditorHistoryEntry] {
        Array(undoStack.reversed())
    }

    init() {
        undoStack = [
            EditorHistoryEntry(title: "Started", timestampLabel: "Just now"),
            EditorHistoryEntry(title: "Canvas ready", timestampLabel: "Just now")
        ]
    }

    func undo() {
        guard canUndo, let entry = undoStack.popLast() else { return }
        redoStack.append(entry)
    }

    func redo() {
        guard let entry = redoStack.popLast() else { return }
        undoStack.append(entry)
    }

    func recordChange(_ entry: EditorHistoryEntry) {
        undoStack.append(entry)
        redoStack.removeAll()
    }

    func jumpToHistory(id: UUID) {
        guard let index = undoStack.firstIndex(where: { $0.id == id }) else { return }
        let removed = Array(undoStack[(index + 1)...])
        undoStack = Array(undoStack[...index])
        redoStack.append(contentsOf: removed.reversed())
        isHistoryPresented = false
    }

    func setScale(_ value: CGFloat) {
        scale = min(max(value, minScale), maxScale)
    }

    func save() {
        // Persistence comes later; save currently means confirm + dismiss.
    }
}
