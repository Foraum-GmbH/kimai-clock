import Foundation
import IOKit

final class UserIdleManager {
    nonisolated(unsafe) private var timer: Timer?
    private let idleThreshold: TimeInterval
    private let callback: (Date, Date) -> Void
    private var hasTriggered = false

    init(threshold: TimeInterval, checkInterval: TimeInterval = 1.0, onIdle: @escaping (Date, Date) -> Void) {
        self.idleThreshold = threshold
        self.callback = onIdle

        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkIdle()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func reset() {
        hasTriggered = false
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func systemIdleTime() -> TimeInterval {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"), &iterator)
        guard result == KERN_SUCCESS, let entry = IOIteratorNext(iterator) as io_registry_entry_t? else {
            return 0
        }

        var properties: Unmanaged<CFMutableDictionary>?
        defer {
            IOObjectRelease(entry)
            IOObjectRelease(iterator)
        }

        guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? NSDictionary,
              let idleNS = dict["HIDIdleTime"] as? UInt64 else {
            return 0
        }

        return TimeInterval(idleNS) / 1_000_000_000
    }

    private func checkIdle() {
        let idleTime = systemIdleTime()

        if idleTime < idleThreshold {
            hasTriggered = false
            return
        }

        if idleTime >= idleThreshold && !hasTriggered {
            hasTriggered = true
            let now = Date()
            let idleStart = now.addingTimeInterval(-idleTime)
            let idleEnd = now
            callback(idleStart, idleEnd)
        }
    }
}
