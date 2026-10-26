import Foundation
import XCTest
@testable import KimaiClock

@MainActor
final class AppDelegateSleepTests: AppDelegateTestCase {
    // MARK: - Sleep

    func testWillSleepStopsTimesheetAtLastInputButKeepsSessionPaused() {
        delegate.systemIdleTime = { 120 }
        startRunningSession()
        let before = Date()

        delegate.handleWillSleep()
        waitUntil { delegate.apiManager.activeTimesheetId == nil }

        let end = endDate(of: requests.first)?.timeIntervalSince1970 ?? 0
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(end, before.addingTimeInterval(-120).timeIntervalSince1970, accuracy: 2)
        XCTAssertEqual(delegate.apiManager.activeActivity?.uniqueId, coding.uniqueId)
        XCTAssertEqual(delegate.apiManager.lastTimesheetId, 99)
        XCTAssertEqual(delegate.timerModel.isActive, false)
        XCTAssertEqual(delegate.timerModel.timer, 3480, accuracy: 2)
        XCTAssertNotNil(delegate.sleepAbsenceStart)
    }

    func testWillSleepDuringOpenIdleAlertEndsAtIdleStart() {
        startRunningSession(timer: 2400)
        delegate.timerModel.pause()
        let idleStart = Date().addingTimeInterval(-1200)
        delegate.pendingIdleStart = idleStart

        delegate.handleWillSleep()
        waitUntil { requests.count == 1 }

        let end = endDate(of: requests.first)?.timeIntervalSince1970 ?? 0
        XCTAssertEqual(end, idleStart.timeIntervalSince1970, accuracy: 1)
        // already reduced on idle detection
        XCTAssertEqual(delegate.timerModel.timer, 2400)
        XCTAssertEqual(delegate.sleepAbsenceStart, idleStart)
    }

    func testWakeShowsIdleAlertForSleep() {
        delegate.systemIdleTime = { 60 }
        startRunningSession()

        delegate.handleWillSleep()
        waitUntil { delegate.apiManager.activeTimesheetId == nil }
        delegate.handleDidWake()
        drainMainQueue()

        XCTAssertEqual(shownAlerts.count, 1)
        XCTAssertEqual(shownAlerts.first, delegate.sleepAbsenceStart)
    }

    func testWakeWithOpenIdleAlertShowsNoSecondAlert() {
        sleepWithOpenIdleAlert(idleStart: Date().addingTimeInterval(-600))

        XCTAssertEqual(shownAlerts.count, 1)
    }

    /// Issue #7: "Continue and keep idle time" after sleep used to leave a stopped session at 00:00
    func testContinueKeepIdleAfterSleepStartsTimesheetAtAbsenceStart() {
        let idleStart = Date().addingTimeInterval(-600)
        sleepWithOpenIdleAlert(idleStart: idleStart)

        answerAlert?(.continueKeepIdle)
        waitUntil { delegate.timerModel.isActive == true }

        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.last?.httpMethod, "POST")
        XCTAssertEqual(date(of: requests.last, "begin")?.timeIntervalSince1970 ?? 0,
                       idleStart.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(delegate.apiManager.activeTimesheetId, 4711)
        XCTAssertEqual(delegate.timerModel.timer, 4200, accuracy: 2)
        XCTAssertNil(delegate.sleepAbsenceStart)
    }

    func testContinueDiscardIdleAfterSleepStartsTimesheetNow() {
        sleepWithOpenIdleAlert(idleStart: Date().addingTimeInterval(-600))

        answerAlert?(.continueDiscardIdle)
        waitUntil { delegate.timerModel.isActive == true }

        XCTAssertEqual(requests.last?.httpMethod, "POST")
        XCTAssertNil(body(requests.last!)["begin"])
        XCTAssertEqual(delegate.apiManager.totalIdleOffset, 0)
        XCTAssertEqual(delegate.timerModel.timer, 3600, accuracy: 1)
    }

    func testStopAfterSleepEndsSessionWithoutAnotherRequest() {
        sleepWithOpenIdleAlert(idleStart: Date().addingTimeInterval(-600))

        answerAlert?(.stopTimer)
        waitUntil { delegate.apiManager.activeActivity == nil }

        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(delegate.timerModel.timer, 0)
    }

    func testFailedSleepStopIsRetriedOnceUserContinues() {
        startRunningSession()
        statusCode = 500

        delegate.handleWillSleep()
        waitUntil { requests.count == 1 }
        drainMainQueue()

        XCTAssertEqual(delegate.apiManager.activeTimesheetId, 99)
        XCTAssertEqual(delegate.timerModel.isActive, false)

        statusCode = 200
        delegate.handleDidWake()
        drainMainQueue()
        answerAlert?(.continueDiscardIdle)
        waitUntil { delegate.timerModel.isActive == true }

        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(endDate(of: requests[1]), endDate(of: requests[0]))
        XCTAssertEqual(requests[2].httpMethod, "POST")
        XCTAssertEqual(delegate.apiManager.activeTimesheetId, 4711)
    }

    func testSleepActionRetriesWhileNetworkIsDown() {
        startRunningSession()
        statusCode = 500
        delegate.handleWillSleep()
        waitUntil { requests.count == 1 }
        delegate.handleDidWake()
        drainMainQueue()

        answerAlert?(.stopTimer)
        waitUntil { requests.count == 3 }
        statusCode = 200
        waitUntil { delegate.apiManager.activeActivity == nil }

        XCTAssertEqual(delegate.timerModel.timer, 0)
    }

    func testRememberedActionIsAppliedOnWake() {
        UserDefaults.standard.set(true, forKey: IdleAction.rememberKey)
        UserDefaults.standard.set(IdleAction.stopTimer.rawValue, forKey: IdleAction.rememberedActionKey)
        startRunningSession()

        delegate.handleWillSleep()
        waitUntil { delegate.apiManager.activeTimesheetId == nil }
        delegate.handleDidWake()
        waitUntil { delegate.apiManager.activeActivity == nil }

        XCTAssertTrue(shownAlerts.isEmpty)
        XCTAssertEqual(requests.count, 1)
    }

    func testWillSleepWithoutSessionDoesNothing() {
        delegate.handleWillSleep()
        delegate.handleDidWake()
        drainMainQueue()

        XCTAssertNil(delegate.sleepAbsenceStart)
        XCTAssertTrue(shownAlerts.isEmpty)
        XCTAssertTrue(requests.isEmpty)
    }

    func testWillSleepWhilePausedKeepsSessionPaused() {
        startRunningSession()
        delegate.apiManager.activeTimesheetId = nil
        delegate.timerModel.pause()

        delegate.handleWillSleep()
        delegate.handleDidWake()
        drainMainQueue()

        XCTAssertTrue(requests.isEmpty)
        XCTAssertTrue(shownAlerts.isEmpty)
        XCTAssertEqual(delegate.apiManager.activeActivity?.uniqueId, coding.uniqueId)
        XCTAssertEqual(delegate.timerModel.timer, 3600, accuracy: 1)
    }

    // MARK: - Right click

    func testRightClickWhileRunningPausesOnServer() {
        startRunningSession(timer: 120)

        delegate.handleRightClick(NSStatusBarButton())
        waitUntil { delegate.timerModel.isActive == false }

        XCTAssertEqual(requests.first?.url?.path, "/api/timesheets/99/stop")
        XCTAssertNil(delegate.apiManager.activeTimesheetId)
    }

    func testRightClickWhilePausedStartsNewTimesheet() {
        startRunningSession(timer: 120)
        delegate.apiManager.activeTimesheetId = nil
        delegate.timerModel.pause()

        delegate.handleRightClick(NSStatusBarButton())
        waitUntil { delegate.timerModel.isActive == true }

        XCTAssertEqual(requests.first?.httpMethod, "POST")
        XCTAssertEqual(delegate.apiManager.activeTimesheetId, 4711)
        XCTAssertEqual(delegate.timerModel.timer, 120, accuracy: 1)
    }

    func testRightClickWithoutSessionDoesNothing() {
        delegate.timerModel.isActive = false

        delegate.handleRightClick(NSStatusBarButton())
        drainMainQueue()

        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(delegate.timerModel.isActive, false)
    }
}
