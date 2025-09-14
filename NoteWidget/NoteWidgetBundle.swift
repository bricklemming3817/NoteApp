//
//  NoteWidgetBundle.swift
//  NoteWidget
//
//  Created by Kevin Varghese on 2025-09-14.
//

import WidgetKit
import SwiftUI

@main
struct NoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        NoteWidget()
        NoteWidgetControl()
        NoteWidgetLiveActivity()
    }
}
