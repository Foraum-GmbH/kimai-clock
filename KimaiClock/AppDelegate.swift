import SwiftUI
internal import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()
    private var statusItem: NSStatusItem!
    private var popover = NSPopover()
    private var iconModel = IconModel()
    private var timerModel = TimerModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = iconModel.icon
            button.imagePosition = .imageLeading
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            button.action = #selector(handleClick(_:))
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

    @objc
    func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            if let isActive = timerModel.isActive {
                popover.performClose(sender)
                if isActive {
                    timerModel.pause()
                    iconModel.setSystemIcon("play.circle")
                } else {
                    timerModel.start()
                    iconModel.setSystemIcon("pause.circle")
                }
                return
            }
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
