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

@MainActor
final class AppDelegateIdleTests: XCTestCase {
    var delegate: AppDelegate!
    private var log = RequestLog()
    private var requests: [URLRequest] { log.requests }
    private var statusCode: Int {
        get { log.statusCode }
        set { log.statusCode = newValue }
    }
    private var storedRecents: Data?

    private let coding = Activity(
        id: 10, name: "Coding", parentTitle: "Kimai", project: 20, color: nil, timesheetId: nil
    )
    private let meeting = Activity(
        id: 3, name: "Meeting", parentTitle: "Intern", project: 5, color: nil, timesheetId: nil
    )

    override func setUp() {
        super.setUp()
        storedRecents = UserDefaults.standard.data(forKey: "recentActivitys")
        UserDefaults.standard.removeObject(forKey: "recentActivitys")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        delegate = AppDelegate()
        delegate.apiManager = ApiManager(session: URLSession(configuration: config))
        delegate.apiManager.serverIP = "https://demo.kimai.org"
        delegate.timerModel = TimerModel()
        delegate.iconModel = IconModel()
        delegate.recentActivitiesManager = RecentActivitiesManager()

        log = RequestLog()
        MockURLProtocol.requestHandler = { [log] request in
            let code = log.record(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id": 4711}"#.utf8))
        }
    }

    override func tearDown() {
        delegate.timerModel.stop()
        MockURLProtocol.requestHandler = nil
        delegate = nil
        if let storedRecents {
            UserDefaults.standard.set(storedRecents, forKey: "recentActivitys")
        } else {
            UserDefaults.standard.removeObject(forKey: "recentActivitys")
        }
        super.tearDown()
    }

    // MARK: - Helpers

    private func startRunningSession(timer: TimeInterval = 3600, timesheetId: Int = 99) {
        delegate.apiManager.activeActivity = coding
        delegate.apiManager.activeTimesheetId = timesheetId
        delegate.timerModel.start(timer)
    }

    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 2) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(condition())
    }

    private func body(_ request: URLRequest) -> [String: Any] {
        request.jsonBody ?? [:]
    }

    private func endDate(of request: URLRequest?) -> Date? {
        guard let request, let end = body(request)["end"] as? String else { return nil }
        return ISO8601DateFormatter().date(from: end)
    }

    // MARK: - Idle actions

    func testContinueDiscardIdleAddsOffsetAndResumes() {
        startRunningSession()
        delegate.timerModel.pause()

        delegate.handleIdleAction(.continueDiscardIdle, idleStart: Date().addingTimeInterval(-600))

        XCTAssertEqual(delegate.apiManager.totalIdleOffset, 600, accuracy: 2)
        XCTAssertEqual(delegate.timerModel.isActive, true)
        XCTAssertEqual(delegate.timerModel.timer, 3600, accuracy: 1)
        XCTAssertTrue(requests.isEmpty)
    }

    func testContinueKeepIdleAddsAbsenceBackToLocalTimer() {
        startRunningSession()
        delegate.timerModel.pause()

        delegate.handleIdleAction(.continueKeepIdle, idleStart: Date().addingTimeInterval(-600))

        XCTAssertEqual(delegate.apiManager.totalIdleOffset, 0)
        XCTAssertEqual(delegate.timerModel.isActive, true)
        XCTAssertEqual(delegate.timerModel.timer, 4200, accuracy: 2)
        XCTAssertTrue(requests.isEmpty)
    }

    func testStopTimerEndsAtIdleStartMinusPreviousIdleOffset() {
        startRunningSession()
        delegate.apiManager.totalIdleOffset = 900
        let idleStart = Date().addingTimeInterval(-600)

        delegate.handleIdleAction(.stopTimer, idleStart: idleStart)
        waitUntil { delegate.apiManager.activeActivity == nil }

        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.url?.path, "/api/timesheets/99")
        XCTAssertEqual(endDate(of: requests.first)?.timeIntervalSince1970 ?? 0,
                       idleStart.addingTimeInterval(-900).timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(delegate.timerModel.isActive, false)
        XCTAssertEqual(delegate.timerModel.timer, 0)
    }

    func testStopTimerFailureResumesTimer() {
        startRunningSession()
        delegate.timerModel.pause()
        statusCode = 500

        delegate.handleIdleAction(.stopTimer, idleStart: Date().addingTimeInterval(-60))
        waitUntil { delegate.timerModel.isActive == true }

        XCTAssertNotNil(delegate.apiManager.activeActivity)
        XCTAssertEqual(delegate.apiManager.activeTimesheetId, 99)
    }

    func testIdleActionIgnoredWhenSessionAlreadyEnded() {
        delegate.handleIdleAction(.continueKeepIdle, idleStart: Date().addingTimeInterval(-600))

        XCTAssertNil(delegate.timerModel.isActive)
        XCTAssertEqual(delegate.timerModel.timer, 0)
        XCTAssertTrue(requests.isEmpty)
    }

    // MARK: - Sleep

    func testWillSleepStopsTimesheetAtSleepTime() {
        startRunningSession()
        let before = Date()

        delegate.handleWillSleep()
        waitUntil { delegate.apiManager.activeActivity == nil }

        let end = endDate(of: requests.first)?.timeIntervalSince1970 ?? 0
        XCTAssertEqual(end, before.timeIntervalSince1970, accuracy: 2)
        XCTAssertNil(delegate.pendingSleepStop)
        XCTAssertEqual(delegate.timerModel.timer, 0)
    }

    func testWillSleepDuringOpenIdleAlertEndsAtIdleStart() {
        startRunningSession()
        let idleStart = Date().addingTimeInterval(-1200)
        delegate.pendingIdleStart = idleStart

        delegate.handleWillSleep()
        waitUntil { delegate.apiManager.activeActivity == nil }

        let end = endDate(of: requests.first)?.timeIntervalSince1970 ?? 0
        XCTAssertEqual(end, idleStart.timeIntervalSince1970, accuracy: 1)
    }

    func testFailedSleepStopIsRetriedOnWake() {
        startRunningSession()
        statusCode = 500

        delegate.handleWillSleep()
        waitUntil { requests.count == 1 }
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        XCTAssertNotNil(delegate.pendingSleepStop)
        XCTAssertNotNil(delegate.apiManager.activeActivity)
        XCTAssertEqual(delegate.timerModel.isActive, false)

        statusCode = 200
        delegate.handleDidWake()
        waitUntil { delegate.apiManager.activeActivity == nil }

        XCTAssertNil(delegate.pendingSleepStop)
        XCTAssertEqual(endDate(of: requests.last), endDate(of: requests.first))
    }

    func testWillSleepWithoutTimerDoesNothing() {
        delegate.handleWillSleep()
        delegate.handleDidWake()

        XCTAssertNil(delegate.pendingSleepStop)
        XCTAssertTrue(requests.isEmpty)
    }

    func testWillSleepWhilePausedEndsSessionLocally() {
        startRunningSession()
        delegate.apiManager.activeTimesheetId = nil
        delegate.timerModel.pause()

        delegate.handleWillSleep()
        waitUntil { delegate.apiManager.activeActivity == nil }

        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(delegate.timerModel.timer, 0)
    }

    // MARK: - Quick actions

    func testStartLastWhileStoppedStartsRecentActivityFromZero() {
        delegate.recentActivitiesManager.add(meeting)

        delegate.handleQuickAction(.startLast(description: "Standup"))
        waitUntil { delegate.timerModel.isActive == true }

        XCTAssertEqual(delegate.apiManager.activeActivity?.uniqueId, meeting.uniqueId)
        XCTAssertEqual(delegate.timerModel.timer, 0, accuracy: 1)
        XCTAssertEqual(body(requests[0])["description"] as? String, "Standup")
        XCTAssertEqual(body(requests[0])["activity"] as? Int, meeting.id)
    }

    func testStartLastWhilePausedResumesSessionWithDescription() {
        delegate.recentActivitiesManager.add(meeting)
        delegate.apiManager.activeActivity = coding
        delegate.apiManager.pendingDescription = "Refactoring"

        let started = expectation(description: "started")
        delegate.apiManager.startActivity().sink { _ in started.fulfill() }.store(in: &cancellables)
        wait(for: [started], timeout: 2)
        delegate.timerModel.start(500)
        delegate.timerModel.pause()

        let paused = expectation(description: "paused")
        delegate.apiManager.stopActivity().sink { _ in paused.fulfill() }.store(in: &cancellables)
        wait(for: [paused], timeout: 2)

        delegate.handleQuickAction(.startLast(description: nil))
        waitUntil { delegate.timerModel.isActive == true }

        XCTAssertEqual(delegate.apiManager.activeActivity?.uniqueId, coding.uniqueId)
        XCTAssertEqual(delegate.timerModel.timer, 500, accuracy: 1)
        XCTAssertEqual(body(requests.last!)["activity"] as? Int, coding.id)
        XCTAssertEqual(body(requests.last!)["description"] as? String, "Refactoring")
    }

    func testStartLastIgnoredWhileRunning() {
        delegate.recentActivitiesManager.add(meeting)
        startRunningSession()

        delegate.handleQuickAction(.startLast(description: nil))
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(delegate.apiManager.activeActivity?.uniqueId, coding.uniqueId)
    }

    func testStartLastWithoutRecentActivitiesDoesNothing() {
        delegate.handleQuickAction(.startLast(description: nil))

        XCTAssertTrue(requests.isEmpty)
        XCTAssertNil(delegate.apiManager.activeActivity)
    }

    func testPauseQuickActionStopsTimesheetAndPausesTimer() {
        startRunningSession(timer: 120)

        delegate.handleQuickAction(.pause)
        waitUntil { delegate.timerModel.isActive == false }

        XCTAssertEqual(requests.first?.url?.path, "/api/timesheets/99/stop")
        XCTAssertNotNil(delegate.apiManager.activeActivity)
        XCTAssertEqual(delegate.apiManager.lastTimesheetId, 99)
        XCTAssertEqual(delegate.timerModel.timer, 120, accuracy: 1)
    }

    func testStopQuickActionEndsSession() {
        startRunningSession(timer: 120)

        delegate.handleQuickAction(.stop)
        waitUntil { delegate.apiManager.activeActivity == nil }

        XCTAssertEqual(delegate.timerModel.timer, 0)
        XCTAssertEqual(delegate.apiManager.sessionDescription, "")
    }

    private var cancellables = Set<AnyCancellable>()
}
