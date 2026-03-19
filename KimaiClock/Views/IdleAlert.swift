//
//  IdleAlert.swift
//  KimaiClock
//
//  Created by Dominic on 05.02.26.
//

import SwiftUI
import AppKit

enum IdleAction {
    case continueTimer
    case stopTimer
}

struct IdleAlertView: View {
    let idleMinutes: Int
    let callback: (IdleAction) -> Void

    @State private var dontShowAgain = false

    private let isMacOS26OrNewer: Bool = {
        if #available(macOS 26, *) { return true }
        return false
    }()

    var body: some View {
        VStack(alignment: isMacOS26OrNewer ? .leading : .center, spacing: 16) {
            Image(systemName: "moon.zzz")
                .resizable()
                .frame(width: 48, height: 48)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: isMacOS26OrNewer ? .leading : .center)

            Text(String(format: NSLocalizedString("idle_alert_title", comment: ""), idleMinutes))
                .font(.title3.bold())
                .foregroundColor(.primary)
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

            HStack(spacing: 10) {
                actionButton("idle_stop_keep", action: .stopTimer, color: .red)
                actionButton("idle_continue_keep", action: .continueTimer, color: .accentColor)
            }
            .padding(.bottom, 4)
        }
        .padding(24)
        .frame(minWidth: 380)
    }

    private func handleAction(_ action: IdleAction) {
        if dontShowAgain {
            UserDefaults.standard.set(true, forKey: "userIdleManager.dontShowAgain")
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

func showIdleAlert(idleMinutes: Int, callback: @escaping (IdleAction) -> Void) {
    var alertWindow: NSWindow?

    let wrappedCallback: (IdleAction) -> Void = { action in
        NSApp.stopModal()
        alertWindow?.close()
        DispatchQueue.main.async {
            callback(action)
        }
    }

    let controller = NSHostingController(
        rootView: IdleAlertView(idleMinutes: idleMinutes, callback: wrappedCallback)
    )

    let window = NSWindow(contentViewController: controller)
    alertWindow = window
    window.styleMask = [.titled, .fullSizeContentView]
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true
    window.setContentSize(NSSize(width: 380, height: 260))
    window.center()

    NSApp.activate(ignoringOtherApps: true)
    NSApp.runModal(for: window)
}
