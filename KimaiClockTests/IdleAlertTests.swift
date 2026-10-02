import XCTest
@testable import KimaiClock

final class IdleAlertTests: XCTestCase {
    func testIdleActionCases() {
        let action1 = IdleAction.continueTimer
        let action2 = IdleAction.stopTimer

        switch action1 {
        case .continueTimer:
            XCTAssertTrue(true)
        case .stopTimer:
            XCTFail("Expected continueTimer")
        }

        switch action2 {
        case .continueTimer:
            XCTFail("Expected stopTimer")
        case .stopTimer:
            XCTAssertTrue(true)
        }
    }

    func testFormattedAbsenceDurationWithNilStartTime() {
        let view = IdleAlertView(idleStartTime: nil, idleMinutes: 20) { _ in }
        XCTAssertEqual(view.formattedAbsenceDuration, "20 min")
    }

    func testFormattedAbsenceDurationWithMinutesOnly() {
        let startTime = Date().addingTimeInterval(-1800) // 30 minutes ago
        let view = IdleAlertView(idleStartTime: startTime, idleMinutes: 15) { _ in }
        // Should be formatted as minutes
        XCTAssertTrue(view.formattedAbsenceDuration.contains("min"))
    }

    func testFormattedAbsenceDurationWithHoursAndMinutes() {
        let startTime = Date().addingTimeInterval(-5400) // 1 hour 30 minutes ago
        let view = IdleAlertView(idleStartTime: startTime, idleMinutes: 15) { _ in }
        // Should be formatted as 1h ...m
        XCTAssertTrue(view.formattedAbsenceDuration.contains("1h"))
    }
}
