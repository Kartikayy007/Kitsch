//
//  EditorHistorySheet.swift
//  Kitsch
//
//  Created by kartikay on 10/07/26.
//

import SwiftUI

struct EditorHistorySheet: View {
    let entries: [EditorHistoryEntry]
    let onSelect: (UUID) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No history yet",
                        systemImage: "clock",
                        description: Text("Edits you make will show up here.")
                    )
                } else {
                    List(entries) { entry in
                        Button {
                            onSelect(entry.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title)
                                    .foregroundStyle(.primary)
                                Text(entry.timestampLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.regularMaterial)
        .presentationCornerRadius(30)
    }
}

#Preview {
    EditorHistorySheet(
        entries: [
            EditorHistoryEntry(title: "Canvas ready", timestampLabel: "Just now"),
            EditorHistoryEntry(title: "Started", timestampLabel: "Just now")
        ],
        onSelect: { _ in }
    )
    .preferredColorScheme(.dark)
}
