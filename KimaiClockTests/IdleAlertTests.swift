import XCTest
@testable import KimaiClock

@MainActor
final class IdleAlertTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: IdleAction.rememberKey)
        UserDefaults.standard.removeObject(forKey: IdleAction.rememberedActionKey)
        super.tearDown()
    }

    func testIdleActionRawValueRoundTrip() {
        for action in [IdleAction.continueDiscardIdle, .continueKeepIdle, .stopTimer] {
            XCTAssertEqual(IdleAction(rawValue: action.rawValue), action)
        }
    }

    func testRememberedActionRequiresCheckbox() {
        UserDefaults.standard.set(IdleAction.continueKeepIdle.rawValue, forKey: IdleAction.rememberedActionKey)
        UserDefaults.standard.set(false, forKey: IdleAction.rememberKey)
        XCTAssertNil(IdleAction.remembered)

        UserDefaults.standard.set(true, forKey: IdleAction.rememberKey)
        XCTAssertEqual(IdleAction.remembered, .continueKeepIdle)
    }

    func testRememberedActionIgnoresUnknownValue() {
        UserDefaults.standard.set("continueTimer", forKey: IdleAction.rememberedActionKey)
        UserDefaults.standard.set(true, forKey: IdleAction.rememberKey)
        XCTAssertNil(IdleAction.remembered)
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
