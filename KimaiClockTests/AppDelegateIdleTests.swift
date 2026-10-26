internal import Combine
import Foundation
import XCTest
@testable import KimaiClock

@MainActor
final class AppDelegateIdleTests: AppDelegateTestCase {
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
        delegate.timerModel.pause()
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

    func testIdleActionIgnoredWhenResumedByHand() {
        startRunningSession()

        delegate.handleIdleAction(.continueKeepIdle, idleStart: Date().addingTimeInterval(-600))

        XCTAssertEqual(delegate.timerModel.timer, 3600, accuracy: 1)
        XCTAssertTrue(requests.isEmpty)
    }

    func testAskForIdleActionShowsAlertAndAppliesAnswer() {
        startRunningSession()
        delegate.timerModel.pause()
        let idleStart = Date().addingTimeInterval(-300)

        delegate.askForIdleAction(idleStart: idleStart)

        XCTAssertEqual(shownAlerts, [idleStart])
        XCTAssertEqual(delegate.pendingIdleStart, idleStart)

        answerAlert?(.continueDiscardIdle)

        XCTAssertNil(delegate.pendingIdleStart)
        XCTAssertEqual(delegate.timerModel.isActive, true)
        XCTAssertEqual(delegate.apiManager.totalIdleOffset, 300, accuracy: 2)
    }

    func testAskForIdleActionAppliesRememberedChoiceWithoutAlert() {
        UserDefaults.standard.set(true, forKey: IdleAction.rememberKey)
        UserDefaults.standard.set(IdleAction.continueKeepIdle.rawValue, forKey: IdleAction.rememberedActionKey)
        startRunningSession()
        delegate.timerModel.pause()

        delegate.askForIdleAction(idleStart: Date().addingTimeInterval(-300))

        XCTAssertTrue(shownAlerts.isEmpty)
        XCTAssertNil(delegate.pendingIdleStart)
        XCTAssertEqual(delegate.timerModel.isActive, true)
        XCTAssertEqual(delegate.timerModel.timer, 3900, accuracy: 2)
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
}
