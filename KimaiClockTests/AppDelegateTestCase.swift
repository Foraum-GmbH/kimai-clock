internal import Combine
import Foundation
import XCTest
@testable import KimaiClock

/// Thread-safe log of mocked requests (MockURLProtocol calls handlers on a background queue)
nonisolated final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []
    private var code = 200

    var requests: [URLRequest] { lock.withLock { storage } }
    var statusCode: Int {
        get { lock.withLock { code } }
        set { lock.withLock { code = newValue } }
    }

    func record(_ request: URLRequest) -> Int {
        lock.withLock {
            storage.append(request)
            return code
        }
    }
}

/// Shared setup for AppDelegate tests: mocked Kimai server, injected managers and a fake idle alert
@MainActor
class AppDelegateTestCase: XCTestCase {
    var delegate: AppDelegate!
    var log = RequestLog()
    var requests: [URLRequest] { log.requests }
    var statusCode: Int {
        get { log.statusCode }
        set { log.statusCode = newValue }
    }
    var storedRecents: Data?
    var storedIdleRemember: Any?
    var storedIdleAction: Any?
    /// Absence starts the idle alert was shown for, plus the callback of the last one
    var shownAlerts: [Date] = []
    var answerAlert: ((IdleAction) -> Void)?

    let coding = Activity(
        id: 10, name: "Coding", parentTitle: "Kimai", project: 20, color: nil, timesheetId: nil
    )
    let meeting = Activity(
        id: 3, name: "Meeting", parentTitle: "Intern", project: 5, color: nil, timesheetId: nil
    )

    override func setUp() async throws {
        try await super.setUp()
        storedRecents = UserDefaults.standard.data(forKey: "recentActivitys")
        UserDefaults.standard.removeObject(forKey: "recentActivitys")
        storedIdleRemember = UserDefaults.standard.object(forKey: IdleAction.rememberKey)
        storedIdleAction = UserDefaults.standard.object(forKey: IdleAction.rememberedActionKey)
        UserDefaults.standard.removeObject(forKey: IdleAction.rememberKey)
        UserDefaults.standard.removeObject(forKey: IdleAction.rememberedActionKey)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        delegate = AppDelegate()
        delegate.apiManager = ApiManager(session: URLSession(configuration: config))
        delegate.apiManager.serverIP = "https://demo.kimai.org"
        delegate.timerModel = TimerModel()
        delegate.iconModel = IconModel()
        delegate.recentActivitiesManager = RecentActivitiesManager()
        delegate.systemIdleTime = { 0 }
        delegate.sleepRetryDelay = 0.05
        shownAlerts = []
        answerAlert = nil
        delegate.idleAlertPresenter = { [unowned self] idleStart, _, callback in
            self.shownAlerts.append(idleStart)
            self.answerAlert = callback
        }

        log = RequestLog()
        MockURLProtocol.requestHandler = { [log] request in
            let code = log.record(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id": 4711}"#.utf8))
        }
    }

    override func tearDown() async throws {
        delegate.timerModel.stop()
        MockURLProtocol.requestHandler = nil
        delegate = nil
        if let storedRecents {
            UserDefaults.standard.set(storedRecents, forKey: "recentActivitys")
        } else {
            UserDefaults.standard.removeObject(forKey: "recentActivitys")
        }
        UserDefaults.standard.set(storedIdleRemember, forKey: IdleAction.rememberKey)
        UserDefaults.standard.set(storedIdleAction, forKey: IdleAction.rememberedActionKey)
        try await super.tearDown()
    }

    // MARK: - Helpers

    func startRunningSession(timer: TimeInterval = 3600, timesheetId: Int = 99) {
        delegate.apiManager.activeActivity = coding
        delegate.apiManager.activeTimesheetId = timesheetId
        delegate.timerModel.start(timer)
    }

    func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 2) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(condition())
    }

    func body(_ request: URLRequest) -> [String: Any] {
        request.jsonBody ?? [:]
    }

    func endDate(of request: URLRequest?) -> Date? {
        date(of: request, "end")
    }

    func date(of request: URLRequest?, _ key: String) -> Date? {
        guard let request, let value = body(request)[key] as? String else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    /// Runs the main queue once, so `DispatchQueue.main.async` work (e.g. on wake) has happened
    func drainMainQueue() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }

    /// Running session, idle alert open (timer paused on detection), then the Mac sleeps and wakes up
    func sleepWithOpenIdleAlert(idleStart: Date) {
        startRunningSession()
        delegate.timerModel.pause()
        delegate.askForIdleAction(idleStart: idleStart)
        delegate.handleWillSleep()
        waitUntil { requests.count == 1 }
        waitUntil { delegate.apiManager.activeTimesheetId == nil }
        delegate.handleDidWake()
        drainMainQueue()
    }

    var cancellables = Set<AnyCancellable>()
}
