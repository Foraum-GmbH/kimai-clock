import SwiftUI
import ServiceManagement
internal import Combine

public enum LaunchAtLogin {
    fileprivate static let observable = Observable()

    public static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            observable.objectWillChange.send()
            do {
                if newValue {
                    if SMAppService.mainApp.status == .enabled {
                        try? SMAppService.mainApp.unregister()
                    }
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {}
        }
    }

    public static var wasLaunchedAtLogin: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}

extension LaunchAtLogin {
    final class Observable: ObservableObject {
        var isEnabled: Bool {
            get { LaunchAtLogin.isEnabled }
            set { LaunchAtLogin.isEnabled = newValue }
        }
    }
}

extension LaunchAtLogin {
    public struct Toggle<Label: View>: View {
        @ObservedObject private var launchAtLogin = LaunchAtLogin.observable
        private let label: Label

        public init(@ViewBuilder label: () -> Label) {
            self.label = label()
        }

        public var body: some View {
            SwiftUI.Toggle(isOn: $launchAtLogin.isEnabled) { label }
        }
    }
}

extension LaunchAtLogin.Toggle<Text> {
    public init(_ titleKey: LocalizedStringKey) {
        label = Text(titleKey)
    }

    public init(_ title: some StringProtocol) {
        label = Text(title)
    }

    public init() {
        self.init("Launch at login")
    }
}
