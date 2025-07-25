
//
//  Note.swift
//  NoteApp
//
//  Created by Kevin Varghese on 2025-07-25.
//

import Foundation
import SwiftData

@Model
final class Note {
    var content: String
    var createdAt: Date
    var isArchived: Bool = false
    var deletedAt: Date?
    
    init(content: String, createdAt: Date) {
        self.content = content
        self.createdAt = createdAt
    }
}
