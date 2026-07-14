//
//  EditorHistoryEntry.swift
//  Kitsch
//
//  Created by kartikay on 10/07/26.
//

import Foundation

struct EditorHistoryEntry: Identifiable, Equatable {
    let id: UUID
    let title: String
    let timestampLabel: String

    init(
        id: UUID = UUID(),
        title: String,
        timestampLabel: String
    ) {
        self.id = id
        self.title = title
        self.timestampLabel = timestampLabel
    }
}
