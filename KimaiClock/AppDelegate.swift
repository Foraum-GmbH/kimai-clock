internal import Combine
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()
    private var statusItem: NSStatusItem!
    private var popover = NSPopover()
    private var apiManager = ApiManager()
    private var iconModel = IconModel()
    private var timerModel = TimerModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

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
            })
            .environmentObject(iconModel)
            .environmentObject(timerModel)
        )
    }

    @objc func handleLeftClick(_ gesture: NSClickGestureRecognizer) {
        guard gesture.state == .ended else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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
