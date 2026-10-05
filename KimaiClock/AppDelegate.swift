internal import Combine
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()
    private var statusItem: NSStatusItem!
    private var popover = NSPopover()
    private var alreadyDisplaysAlert = false

    private var updateManager = UpdateManager()
    // internal (not private) so unit tests can inject them
    var apiManager = ApiManager()
    var iconModel = IconModel()
    var timerModel = TimerModel()
    private var launchManager: AppLaunchManager!
    var recentActivitiesManager = RecentActivitiesManager()
    private var userIdleManager: UserIdleManager?
    private var currentIdleThreshold: Double?
    private var popoverState = PopoverState()

    private var paragraph: NSMutableParagraphStyle = {
        let temp = NSMutableParagraphStyle()
        temp.alignment = .center
        return temp
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            _ = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Running unit tests")
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            return
        }

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

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isSystemSleeping = true
                self?.handleWillSleep()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isSystemSleeping = false
                self?.handleDidWake()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSPopover.willShowNotification,
            object: popover,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.popoverState.isPresented = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSPopover.didCloseNotification,
            object: popover,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.popoverState.isPresented = false
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = iconModel.icon
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            button.setAccessibilityTitle("KimaiClock")

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
            .environmentObject(popoverState)
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
                UserDefaults.standard.bool(forKey: "appLaunchManager.dontShowAgain") == false,
                self.timerModel.isActive == false,
                alreadyDisplaysAlert == false
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
        setupUserIdleManager()

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.setupUserIdleManager()
            }
            .store(in: &cancellables)

        apiManager.startAtLaunch(startRemoteTimerProcess)
    }

    private func setupUserIdleManager() {
        let newThreshold: Double? = {
            guard let thresholdStr = UserDefaults.standard.string(forKey: "idleThreshold"),
                  !thresholdStr.isEmpty,
                  let val = Double(thresholdStr),
                  val > 0 else { return nil }
            return val
        }()

        guard newThreshold != currentIdleThreshold else { return }
        currentIdleThreshold = newThreshold

        userIdleManager?.stop()
        userIdleManager = nil

        guard let idleThreshold = newThreshold else { return }

        userIdleManager = UserIdleManager(threshold: idleThreshold * 60) { [weak self] idleStart, idleEnd in
            guard
                let self,
                self.timerModel.isActive == true,
                self.alreadyDisplaysAlert == false
            else { return }

            let idleDuration = idleEnd.timeIntervalSince(idleStart)

            self.timerModel.pause()
            self.timerModel.timer = max(0, self.timerModel.timer - idleDuration)
            self.updateStatusBarTitle()
            self.iconModel.setSystemIcon("play.circle")

            if let remembered = IdleAction.remembered {
                self.userIdleManager?.reset()
                self.handleIdleAction(remembered, idleStart: idleStart)
                return
            }

            ChimeManager.shared.play(.pause)
            self.alreadyDisplaysAlert = true
            self.pendingIdleStart = idleStart

            let idleMinutes = max(1, Int(idleDuration / 60))

            showIdleAlert(idleStartTime: idleStart, idleMinutes: idleMinutes) { [weak self] selectedAction in
                guard let self else { return }

                self.alreadyDisplaysAlert = false
                self.pendingIdleStart = nil
                self.userIdleManager?.reset()
                self.handleIdleAction(selectedAction, idleStart: idleStart)
            }
        }
    }

    func handleIdleAction(_ action: IdleAction, idleStart: Date) {
        // session may have ended meanwhile (e.g. stopped on sleep while the alert was open)
        guard apiManager.activeActivity != nil, timerModel.timer != 0 else { return }

        switch action {
        case .continueDiscardIdle:
            apiManager.totalIdleOffset += Date().timeIntervalSince(idleStart)
            resumeAfterIdle()

        case .continueKeepIdle:
            // local timer was reduced and paused on detection -> add the whole absence back
            timerModel.timer += Date().timeIntervalSince(idleStart)
            resumeAfterIdle()

        case .stopTimer:
            apiManager.stopActivity(at: idleStart)
                .sink { [weak self] success in
                    guard let self else { return }
                    if success {
                        self.applyStoppedState()
                    } else {
                        self.resumeAfterIdle(chime: .error)
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func resumeAfterIdle(chime: ChimeType = .start) {
        timerModel.start()
        timerModel.isActive = true
        iconModel.setSystemIcon("pause.circle")
        updateStatusBarTitle()
        ChimeManager.shared.play(chime)
    }

    private func applyStoppedState() {
        apiManager.activeActivity = nil
        timerModel.stop()
        timerModel.isActive = false
        iconModel.setSystemIcon("circle")
        ChimeManager.shared.play(.stop)
        updateStatusBarTitle()
    }

    // MARK: - Sleep handling

    /// Sleep start of a session that still has to be stopped on the server
    private(set) var pendingSleepStop: Date?
    private var isSystemSleeping = false
    /// Start of an idle period whose alert is still open
    var pendingIdleStart: Date?

    func handleWillSleep() {
        guard timerModel.timer != 0 else { return }

        let sleepStart = pendingIdleStart ?? Date()
        pendingSleepStop = sleepStart
        timerModel.pause()
        stopAfterSleep(at: sleepStart, retries: 0)
    }

    func handleDidWake() {
        guard let sleepStart = pendingSleepStop else { return }
        // network is usually not back right after wake -> retry a few times
        stopAfterSleep(at: sleepStart, retries: 5)
    }

    private func stopAfterSleep(at sleepStart: Date, retries: Int) {
        apiManager.stopActivity(at: sleepStart)
            .sink { [weak self] success in
                guard let self, self.pendingSleepStop == sleepStart else { return }

                if success {
                    self.pendingSleepStop = nil
                    self.applyStoppedState()
                } else if retries > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.stopAfterSleep(at: sleepStart, retries: retries - 1)
                    }
                } else if !self.isSystemSleeping {
                    ChimeManager.shared.play(.error)
                }
            }
            .store(in: &cancellables)
    }

    private func startRemoteTimerProcess(remoteTime: Double) {
        if remoteTime < 0 {
            timerModel.stop()
            timerModel.isActive = false
            iconModel.setSystemIcon("circle")
            ChimeManager.shared.play(.stop)
            updateStatusBarTitle()
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

    enum QuickAction: Equatable {
        case startLast(description: String? = nil)
        case pause
        case stop

        init?(url: URL) {
            guard url.scheme == "kimai-clock" else { return nil }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let actionName: String
            if let host = components?.host, !host.isEmpty {
                actionName = host
            } else {
                actionName = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }

            switch actionName {
            case "startLast":
                let rawDescription = components?.queryItems?.first(where: {
                    ["description", "desc", "note", "comment"].contains($0.name.lowercased())
                })?.value
                let trimmed = rawDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
                let description = (trimmed?.isEmpty ?? true) ? nil : trimmed
                self = .startLast(description: description)
            case "pause":
                self = .pause
            case "stop":
                self = .stop
            default:
                return nil
            }
        }
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let action = QuickAction(url: url) else { continue }
            handleQuickAction(action)
        }
    }

    // MARK: - Core Quick Action Logic

    func handleQuickAction(_ action: QuickAction) {
        switch action {
        case .pause:
            guard timerModel.isActive == true else { return }

            apiManager.stopActivity()
                .sink { success in
                    if success {
                        self.timerModel.pause()
                        self.timerModel.isActive = false
                        self.iconModel.setSystemIcon("play.circle")
                        ChimeManager.shared.play(.pause)
                    } else {
                        ChimeManager.shared.play(.error)
                    }
                }
                .store(in: &cancellables)

        case .stop:
            guard timerModel.timer != 0 else { return }

            apiManager.stopActivity()
                .sink { success in
                    if success {
                        self.apiManager.activeActivity = nil
                        self.timerModel.stop()
                        self.timerModel.isActive = false
                        self.iconModel.setSystemIcon("circle")
                        ChimeManager.shared.play(.stop)
                    } else {
                        ChimeManager.shared.play(.error)
                    }
                }
                .store(in: &cancellables)

        case .startLast(let description):
            guard timerModel.isActive != true else { return }

            let isPaused = timerModel.isActive == false && timerModel.timer != 0 && apiManager.activeActivity != nil
            if !isPaused {
                // nothing to resume -> start the most recent activity from zero
                guard let last = recentActivitiesManager.activities.first else { return }
                timerModel.stop()
                apiManager.activeActivity = last
            }

            apiManager.startActivity(description: description)
                .sink { id in
                    if id != nil {
                        self.timerModel.start()
                        self.timerModel.isActive = true
                        self.iconModel.setSystemIcon("pause.circle")
                        self.recentActivitiesManager.add(self.apiManager.activeActivity)
                        ChimeManager.shared.play(.start)
                    } else {
                        ChimeManager.shared.play(.error)
                    }
                }
                .store(in: &cancellables)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        stopKimaiTask {
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func updateStatusBarTitle() {
        let attrTitle = NSAttributedString(
            string: timerModel.formattedTimeMenuBar,
            attributes: [
                .paragraphStyle: paragraph,
                .baselineOffset: -1
            ]
        )
        statusItem?.button?.attributedTitle = attrTitle
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
