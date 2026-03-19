//
//  KimaiWidgetBundle.swift
//  KimaiWidget
//
//  Created by Dominic on 31.01.26.
//

import WidgetKit
import SwiftUI

@main
struct KimaiWidgetBundle: WidgetBundle {
    var body: some Widget {
        // KimaiWidget()
        EmptyWidgetConfiguration()
    }
}

struct EmptyWidgetConfiguration: Widget {
    let kind: String = "EmptyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EmptyProvider()) { _ in
            Text("Widget is WIP")
                .containerBackground(.fill.tertiary, for: .widget)
                .transition(.identity)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Kimai Timer")
        .description("Track your active timer.")
    }
}

struct EmptyProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry(date: Date())], policy: .never))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}
