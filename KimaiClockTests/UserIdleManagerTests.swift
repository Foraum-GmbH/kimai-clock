import XCTest
@testable import KimaiClock

@MainActor
final class UserIdleManagerTests: XCTestCase {
    func testInitializationAndReset() {
        var triggered = false
        let manager = UserIdleManager(threshold: 60.0, checkInterval: 10.0) { _, _ in
            triggered = true
        }

        manager.reset()
        XCTAssertFalse(triggered)
    }

    func testTriggersOnceWhenThresholdReached() {
        var idle: TimeInterval = 120
        var calls: [(Date, Date)] = []
        let manager = UserIdleManager(
            threshold: 60,
            checkInterval: 3600,
            idleTimeProvider: { idle },
            onIdle: { start, end in calls.append((start, end)) }
        )
        defer { manager.stop() }

        manager.checkIdle()
        idle = 121
        manager.checkIdle()

        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].1.timeIntervalSince(calls[0].0), 120, accuracy: 0.5)
    }

    func testDoesNotTriggerBelowThreshold() {
        var triggered = false
        let manager = UserIdleManager(threshold: 60, checkInterval: 3600, idleTimeProvider: { 59 }, onIdle: { _, _ in
            triggered = true
        })
        defer { manager.stop() }

        manager.checkIdle()
        XCTAssertFalse(triggered)
    }

    func testRearmsAfterUserActivity() {
        var idle: TimeInterval = 90
        var count = 0
        let manager = UserIdleManager(threshold: 60, checkInterval: 3600, idleTimeProvider: { idle }, onIdle: { _, _ in
            count += 1
        })
        defer { manager.stop() }

        manager.checkIdle()
        idle = 0
        manager.checkIdle()
        idle = 70
        manager.checkIdle()

        XCTAssertEqual(count, 2)
    }

    func testResetRearmsWhileStillIdle() {
        var count = 0
        let manager = UserIdleManager(threshold: 60, checkInterval: 3600, idleTimeProvider: { 90 }, onIdle: { _, _ in
            count += 1
        })
        defer { manager.stop() }

        manager.checkIdle()
        manager.reset()
        manager.checkIdle()

        XCTAssertEqual(count, 2)
    }
}
