//
//  KimaiWidget.swift
//  KimaiWidget
//
//  Created by Dominic on 31.01.26.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Entry

struct Activity {
    let name: String
    let parentTitle: String?
}

struct TimerEntry: TimelineEntry {
    let date: Date
    let timer: TimeInterval
    let isActive: Bool?
    let subtitle: String?
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TimerEntry {
        TimerEntry(date: Date(), timer: 0, isActive: nil, subtitle: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> ()) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> ()) {
        var entries: [TimerEntry] = []
        let now = Date()

        // Refresh every second while active, every 60s while paused
        let interval: TimeInterval = WidgetSync.isActive == true ? 1 : 60
        let count = WidgetSync.isActive == true ? 60 : 1

        for i in 0..<count {
            let entryDate = now.addingTimeInterval(Double(i) * interval)
            let timerValue = WidgetSync.timer + (WidgetSync.isActive == true ? Double(i) * interval : 0)
            entries.append(TimerEntry(date: entryDate, timer: timerValue, isActive: WidgetSync.isActive, subtitle: WidgetSync.subtitle))
        }

        // Re-fetch after the last entry
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

    private func currentEntry() -> TimerEntry {
        TimerEntry(
            date: Date(),
            timer: WidgetSync.timer,
            isActive: WidgetSync.isActive,
            subtitle: WidgetSync.subtitle
        )
    }
}

// MARK: - View

struct KimaiWidgetEntryView: View {
    var entry: TimerEntry

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text(formattedTime)
                .font(.system(size: 35, weight: .bold, design: .monospaced))
                .contentTransition(.identity)
                .transaction { $0.animation = nil }

            Text(entry.subtitle ?? "")
                .font(.system(size: 20, weight: .semibold))
                .contentTransition(.identity)
                .transaction { $0.animation = nil }

            HStack(spacing: 10) {
                // Play
                if entry.isActive != true {
                    Button(intent: StartTimerIntent()) {
                        Image(systemName: "play.fill")
                            .frame(width: 24, height: 24)
                    }
                    .disabled(entry.isActive == nil && entry.timer == 0)
                }

                // Pause
                if entry.isActive == true {
                    Button(intent: PauseTimerIntent()) {
                        Image(systemName: "pause.fill")
                            .frame(width: 24, height: 24)
                    }
                }

                // Stop
                Button(intent: StopTimerIntent()) {
                    Image(systemName: "stop.fill")
                        .frame(width: 24, height: 24)
                }
                .disabled(entry.timer == 0)
            }        }
        .animation(nil, value: entry.timer)
        .padding()
    }

    private var formattedTime: String {
        let hours = Int(entry.timer) / 3600
        let minutes = (Int(entry.timer) % 3600) / 60
        let seconds = Int(entry.timer) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Intents

struct StartTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Timer"

    func perform() async throws -> some IntentResult {
        // Main app handles this via AppShortcutsProvider or scene delegate
        return .result()
    }
}

struct PauseTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Timer"

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct StopTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Timer"

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Widget

struct KimaiWidget: Widget {
    let kind: String = "KimaiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            KimaiWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .transition(.identity)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Kimai Timer")
        .description("Track your active timer.")
    }
}
