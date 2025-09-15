import AppKit

final class AppLaunchManager {
    private var observers: [NSObjectProtocol] = []
    private let watchedBundleIDs: Set<String>
    private let callback: (String) -> Void

    init(watch bundleIDs: [String], onLaunch: @escaping (String) -> Void) {
        self.watchedBundleIDs = Set(bundleIDs)
        self.callback = onLaunch

        let nc = NSWorkspace.shared.notificationCenter

        let observer = nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] notif in
            guard
                let self,
                let userInfo = notif.userInfo,
                let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let bundleID = app.bundleIdentifier
            else { return }

            if self.watchedBundleIDs.contains(bundleID) {
                self.callback(bundleID)
            }
        }

        observers.append(observer)
    }

    deinit {
        let nc = NSWorkspace.shared.notificationCenter
        observers.forEach { nc.removeObserver($0) }
    }
}
