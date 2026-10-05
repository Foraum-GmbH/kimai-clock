//
//  IdleAlert.swift
//  KimaiClock
//
//  Created by Dominic on 05.02.26.
//

import AppKit
internal import Combine
import SwiftUI

enum IdleAction: String {
    /// keep running, idle time is deducted from the timesheet
    case continueDiscardIdle
    /// keep running, idle time stays on the timesheet (e.g. phone call)
    case continueKeepIdle
    /// stop the timesheet at the moment the user went idle
    case stopTimer

    static let rememberKey = "userIdleManager.dontShowAgain"
    static let rememberedActionKey = "userIdleManager.rememberedAction"

    /// The action chosen with "remember my choice" ticked, if any
    static var remembered: IdleAction? {
        guard UserDefaults.standard.bool(forKey: rememberKey),
              let raw = UserDefaults.standard.string(forKey: rememberedActionKey) else { return nil }
        return IdleAction(rawValue: raw)
    }
}

struct IdleAlertView: View {
    let idleStartTime: Date?
    let idleMinutes: Int
    let callback: (IdleAction) -> Void

    @State private var dontShowAgain = false
    @State private var currentDate = Date()

    init(idleStartTime: Date? = nil, idleMinutes: Int, callback: @escaping (IdleAction) -> Void) {
        self.idleStartTime = idleStartTime
        self.idleMinutes = idleMinutes
        self.callback = callback
    }

    private let isMacOS26OrNewer: Bool = {
        if #available(macOS 26, *) { return true }
        return false
    }()

    var formattedAbsenceDuration: String {
        guard let idleStartTime else {
            return "\(idleMinutes) min"
        }
        let seconds = max(0, currentDate.timeIntervalSince(idleStartTime))
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(max(1, minutes)) min"
        }
    }

    var body: some View {
        VStack(alignment: isMacOS26OrNewer ? .leading : .center, spacing: 16) {
            Image(systemName: "moon.zzz")
                .resizable()
                .frame(width: 48, height: 48)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: isMacOS26OrNewer ? .leading : .center)

            Text(NSLocalizedString("idle_alert_title", comment: ""))
                .font(.title3.bold())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: isMacOS26OrNewer ? .leading : .center)

            Text(String(format: NSLocalizedString("idle_absence_duration", comment: ""), formattedAbsenceDuration))
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: isMacOS26OrNewer ? .leading : .center)

            Text("idle_alert_message")
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: isMacOS26OrNewer ? .leading : .center)

            Toggle(isOn: $dontShowAgain) {
                Text("idle_dont_show_again")
                    .font(.body)
            }
            .toggleStyle(.checkbox)
            .frame(maxWidth: .infinity, alignment: isMacOS26OrNewer ? .leading : .center)

            VStack(spacing: 10) {
                actionButton("idle_continue_discard", action: .continueDiscardIdle, color: .accentColor)
                actionButton("idle_continue_keep", action: .continueKeepIdle, color: .accentColor)
                actionButton("idle_stop_keep", action: .stopTimer, color: .red)
            }
            .padding(.bottom, 4)
        }
        .padding(24)
        .frame(minWidth: 380)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
            currentDate = now
        }
    }

    private func handleAction(_ action: IdleAction) {
        if dontShowAgain {
            UserDefaults.standard.set(action.rawValue, forKey: IdleAction.rememberedActionKey)
            UserDefaults.standard.set(true, forKey: IdleAction.rememberKey)
        }
        callback(action)
    }

    @ViewBuilder
    private func actionButton(_ title: LocalizedStringKey, action: IdleAction, color: Color) -> some View {
        if #available(macOS 26.0, *) {
            Button {
                handleAction(action)
            } label: {
                Text(title)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(color)
        } else {
            Button {
                handleAction(action)
            } label: {
                Text(title)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .controlSize(.large)
            .tint(color)
        }
    }
}

extension View {
    @ViewBuilder
    func ifAvailable<T: View>(macOS14: (Self) -> T, fallback: (Self) -> T) -> some View {
        if #available(macOS 14, *) {
            macOS14(self)
        } else {
            fallback(self)
        }
    }
}

func showIdleAlert(idleStartTime: Date? = nil, idleMinutes: Int, callback: @escaping (IdleAction) -> Void) {
    var alertWindow: NSWindow?

    let wrappedCallback: (IdleAction) -> Void = { action in
        NSApp.stopModal()
        alertWindow?.close()
        DispatchQueue.main.async {
            callback(action)
        }
    }

    let controller = NSHostingController(
        rootView: IdleAlertView(idleStartTime: idleStartTime, idleMinutes: idleMinutes, callback: wrappedCallback)
    )

    let window = NSWindow(contentViewController: controller)
    alertWindow = window
    window.styleMask = [.titled, .fullSizeContentView]
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true
    window.setContentSize(controller.sizeThatFits(in: NSSize(width: 380, height: CGFloat.greatestFiniteMagnitude)))
    window.center()

    NSApp.activate(ignoringOtherApps: true)
    NSApp.runModal(for: window)
}
