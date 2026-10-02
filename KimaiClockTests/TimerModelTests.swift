import XCTest
@testable import KimaiClock

@MainActor
final class TimerModelTests: XCTestCase {
    var timerModel: TimerModel!

    override func setUp() {
        super.setUp()
        timerModel = TimerModel()
    }

    override func tearDown() {
        timerModel.stop()
        timerModel = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(timerModel.timer, 0)
        XCTAssertNil(timerModel.isActive)
        XCTAssertEqual(timerModel.formattedTimePopup, "00:00:00")
        XCTAssertEqual(timerModel.formattedTimeMenuBar, "00:00")
    }

    func testStartWithoutRemoteTime() {
        timerModel.start()
        XCTAssertEqual(timerModel.isActive, true)
        XCTAssertEqual(timerModel.timer, 0)
    }

    func testStartWithRemoteTime() {
        timerModel.start(125.0)
        XCTAssertEqual(timerModel.isActive, true)
        XCTAssertEqual(timerModel.timer, 125.0)
        XCTAssertEqual(timerModel.formattedTimePopup, "00:02:05")
        XCTAssertEqual(timerModel.formattedTimeMenuBar, "00:02")
    }

    func testPause() {
        timerModel.start(60.0)
        timerModel.pause()
        XCTAssertEqual(timerModel.isActive, false)
        XCTAssertEqual(timerModel.timer, 60.0)
    }

    func testStop() {
        timerModel.start(120.0)
        timerModel.stop()
        XCTAssertNil(timerModel.isActive)
        XCTAssertEqual(timerModel.timer, 0)
        XCTAssertEqual(timerModel.formattedTimePopup, "00:00:00")
    }

    func testFormattedTimePopupFormatting() {
        timerModel.timer = 0
        XCTAssertEqual(timerModel.formattedTimePopup, "00:00:00")

        timerModel.timer = 59
        XCTAssertEqual(timerModel.formattedTimePopup, "00:00:59")

        timerModel.timer = 3600
        XCTAssertEqual(timerModel.formattedTimePopup, "01:00:00")

        timerModel.timer = 3665
        XCTAssertEqual(timerModel.formattedTimePopup, "01:01:05")

        timerModel.timer = 86400
        XCTAssertEqual(timerModel.formattedTimePopup, "24:00:00")
    }

    func testFormattedTimeMenuBarFormatting() {
        timerModel.timer = 0
        XCTAssertEqual(timerModel.formattedTimeMenuBar, "00:00")

        timerModel.timer = 59
        XCTAssertEqual(timerModel.formattedTimeMenuBar, "00:00")

        timerModel.timer = 120
        XCTAssertEqual(timerModel.formattedTimeMenuBar, "00:02")

        timerModel.timer = 3661
        XCTAssertEqual(timerModel.formattedTimeMenuBar, "01:01")
    }

    func testFormattedTimeStartedAt() {
        timerModel.timer = 0
        XCTAssertFalse(timerModel.formattedTimeStartedAt.isEmpty)

        timerModel.timer = 120
        XCTAssertFalse(timerModel.formattedTimeStartedAt.isEmpty)
    }
}
