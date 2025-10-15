internal import Combine
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()
    private var statusItem: NSStatusItem!
    private var popover = NSPopover()
    private var alreadyDisplaysAlert = false

    private var updateManager = UpdateManager()
    private var apiManager = ApiManager()
    private var iconModel = IconModel()
    private var timerModel = TimerModel()
    private var launchManager: AppLaunchManager!
    private var recentActivitiesManager = RecentActivitiesManager()
    private var userIdleManager: UserIdleManager!

    private var paragraph: NSMutableParagraphStyle = {
        let temp = NSMutableParagraphStyle()
        temp.alignment = .center
        return temp
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)

        if runningInstances.count > 1 {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("multiple_instances_title", comment: "")
            alert.informativeText = NSLocalizedString("multiple_instances_body", comment: "")
            alert.alertStyle = .warning
            alert.addButton(withTitle: NSLocalizedString("multiple_instances_button", comment: ""))
            alert.runModal()

            NSApp.terminate(nil)
        }

        NSWorkspace.shared.notificationCenter.addObserver(
                    forName: NSWorkspace.willPowerOffNotification,
                    object: nil,
                    queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.stopKimaiTask()
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = iconModel.icon
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

            let click = NSClickGestureRecognizer(target: self, action: #selector(handleLeftClick(_:)))
            button.addGestureRecognizer(click)

            let longPress = NSPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.5
            button.addGestureRecognizer(longPress)

            button.sendAction(on: [.rightMouseUp])
            button.action = #selector(handleRightClick(_:))
            button.target = self
        }

        timerModel.$timer
            .sink { [weak self] _ in
                guard let self = self else { return }

                let attrTitle = NSAttributedString(
                    string: self.timerModel.formattedTimeMenuBar,
                    attributes: [
                        .paragraphStyle: paragraph,
                        .baselineOffset: -1
                    ]
                )

                self.statusItem.button?.attributedTitle = attrTitle
            }
            .store(in: &cancellables)

        iconModel.$icon.sink { [weak self] newIcon in
            self?.statusItem.button?.image = newIcon
        }
        .store(in: &cancellables)

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopupView(closePopup: { [weak self] in
                self?.popover.performClose(nil)
            }, startRemoteTimerProcess: startRemoteTimerProcess)
            .environmentObject(iconModel)
            .environmentObject(timerModel)
            .environmentObject(updateManager)
            .environmentObject(apiManager)
            .environmentObject(recentActivitiesManager)
        )

        launchManager = AppLaunchManager(
            watch: [
                "com.microsoft.VSCode",
                "com.jetbrains.PhpStorm",
                "com.apple.dt.Xcode"
            ]
        ) { [weak self] bundleID in
            guard
                let self,
                UserDefaults.standard.bool(forKey: "appLaunchManager.dontShowAgain") == true,
                self.timerModel.isActive == false,
                alreadyDisplaysAlert == true
            else { return }

            alreadyDisplaysAlert = true

            let alert = NSAlert()
            alert.messageText = "Detected launch of \(bundleID)"
            alert.informativeText = "You opened a development app but have no active Kimai timer running."

            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                if let appName = app.localizedName {
                    alert.messageText = "Launched \(appName)"
                }
                if let appIcon = app.icon {
                    alert.icon = appIcon
                }
            }

            alert.addButton(withTitle: "Start Tracking")
            alert.addButton(withTitle: "Cancel")
            let dontShowButton = alert.addButton(withTitle: "Don’t Show Again")
            dontShowButton.hasDestructiveAction = true

            let response = alert.runModal()
            alreadyDisplaysAlert = false

            switch response {
            case .alertFirstButtonReturn:
                if let button = statusItem.button {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                    ChimeManager.shared.play(.start)
                }
            case .alertThirdButtonReturn:
                UserDefaults.standard.set(true, forKey: "appLaunchManager.dontShowAgain")
            default:
                break
            }
        }

        userIdleManager = UserIdleManager(threshold: 60 * 30) { [weak self] in
            guard
                let self,
                UserDefaults.standard.bool(forKey: "userIdleManager.dontShowAgain") == true,
                self.timerModel.isActive == true,
                alreadyDisplaysAlert == true
            else { return }

            alreadyDisplaysAlert = true

            // pause timer for now
            timerModel.pause()
            iconModel.setSystemIcon("play.circle")
            ChimeManager.shared.play(.pause)

            let alert = NSAlert()
            alert.messageText = "You’ve been idle"
            alert.informativeText = "You have a timer running but haven’t interacted with your Mac for 30 minutes."

            alert.icon = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: nil)

            alert.addButton(withTitle: "Stop Tracking")
            alert.addButton(withTitle: "Cancel")
            let dontShowButton = alert.addButton(withTitle: "Don’t Show Again")
            dontShowButton.hasDestructiveAction = true

            let response = alert.runModal()
            alreadyDisplaysAlert = false

            switch response {
            case .alertFirstButtonReturn:
                timerModel.stop()
                iconModel.setSystemIcon("circle")
                ChimeManager.shared.play(.stop)
            case .alertSecondButtonReturn:
                // resume paused timer
                timerModel.start()
                iconModel.setSystemIcon("pause.circle")
            case .alertThirdButtonReturn:
                UserDefaults.standard.set(true, forKey: "userIdleManager.dontShowAgain")
            default:
                break
            }
        }

        apiManager.startAtLaunch(startRemoteTimerProcess)
    }

    private func startRemoteTimerProcess(remoteTime: Double) {
        if remoteTime < 0 {
            timerModel.stop()
            timerModel.isActive = false
            iconModel.setSystemIcon("circle")
            ChimeManager.shared.play(.stop)

            let attrTitle = NSAttributedString(
                string: self.timerModel.formattedTimeMenuBar,
                attributes: [
                    .paragraphStyle: paragraph,
                    .baselineOffset: -1
                ]
            )

            self.statusItem.button?.attributedTitle = attrTitle
        } else {
            timerModel.start(remoteTime)
            timerModel.isActive = true
            iconModel.setSystemIcon("pause.circle")
            recentActivitiesManager.add(apiManager.activeActivity)
            ChimeManager.shared.play(.start)
        }
    }

    @objc func handleLeftClick(_ gesture: NSClickGestureRecognizer) {
        guard gesture.state == .ended else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            updateManager.checkForUpdateIfNeeded()
            apiManager.checkForRemoteTimer(true, startRemoteTimerProcess)
        }
    }

    @objc func handleLongPress(_ gesture: NSPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        if popover.isShown {
            popover.performClose(nil)
        }

        if let baseUrl = apiManager.serverIP,
           let url = URL(string: baseUrl) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func handleRightClick(_ sender: NSStatusBarButton) {
        guard let isActive = timerModel.isActive else { return }

        popover.performClose(sender)

        if isActive {
            timerModel.pause()
            iconModel.setSystemIcon("play.circle")
        } else {
            timerModel.start()
            iconModel.setSystemIcon("pause.circle")
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        stopKimaiTask {
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func stopKimaiTask(_ completion: (() -> Void)? = nil) {
        apiManager.stopActivity()
            .sink { _ in completion?() }
            .store(in: &cancellables)

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            completion?()
        }
    }
}
