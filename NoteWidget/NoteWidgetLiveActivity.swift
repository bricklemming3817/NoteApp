//
//  NoteWidgetLiveActivity.swift
//  NoteWidget
//
//  Created by Kevin Varghese on 2025-09-14.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct NoteWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct NoteWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NoteWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension NoteWidgetAttributes {
    fileprivate static var preview: NoteWidgetAttributes {
        NoteWidgetAttributes(name: "World")
    }
}

extension NoteWidgetAttributes.ContentState {
    fileprivate static var smiley: NoteWidgetAttributes.ContentState {
        NoteWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: NoteWidgetAttributes.ContentState {
         NoteWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: NoteWidgetAttributes.preview) {
   NoteWidgetLiveActivity()
} contentStates: {
    NoteWidgetAttributes.ContentState.smiley
    NoteWidgetAttributes.ContentState.starEyes
}
