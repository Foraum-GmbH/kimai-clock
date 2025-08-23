import SwiftUI
internal import Combine

@MainActor
class TimerModel: ObservableObject {
    @Published var timer: TimeInterval = 0
    @Published var isActive: Bool? = nil
    private var cancellable: Timer?

    public func start() {
        isActive = true
        guard cancellable == nil else { return }
        cancellable = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.timer += 1
            }
        }
    }

    public func pause() {
        isActive = false
        cancellable?.invalidate()
        cancellable = nil
    }

    public func stop() {
        isActive = nil
        timer = 0
        cancellable?.invalidate()
        cancellable = nil
    }

    var formattedTimePopup: String {
        let hours = Int(timer) / 3600
        let minutes = (Int(timer) % 3600) / 60
        let seconds = Int(timer) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var formattedTimeMenuBar: String {
        let hours = Int(timer) / 3600
        let minutes = (Int(timer) % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}
