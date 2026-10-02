import XCTest
@testable import KimaiClock

@MainActor
final class WidgetSyncTests: XCTestCase {
    override func tearDown() {
        WidgetSync.save(activity: nil)
        WidgetSync.save(timer: 0, isActive: nil)
        super.tearDown()
    }

    func testSaveActivityWithParentTitle() {
        let activity = Activity(
            id: 1,
            name: "Documentation",
            parentTitle: "KimaiClock",
            project: 10,
            color: nil,
            timesheetId: nil
        )

        WidgetSync.save(activity: activity)
        let saved = WidgetSync.defaults.string(forKey: "activity")
        XCTAssertEqual(saved, "KimaiClock / Documentation")
    }

    func testSaveActivityWithoutParentTitle() {
        let activity = Activity(
            id: 2,
            name: "General",
            parentTitle: nil,
            project: nil,
            color: nil,
            timesheetId: nil
        )

        WidgetSync.save(activity: activity)
        let saved = WidgetSync.defaults.string(forKey: "activity")
        XCTAssertEqual(saved, "General")
    }

    func testSaveNilActivityRemovesKey() {
        let activity = Activity(id: 3, name: "Task", parentTitle: nil, project: nil, color: nil, timesheetId: nil)
        WidgetSync.save(activity: activity)
        XCTAssertNotNil(WidgetSync.defaults.string(forKey: "activity"))

        WidgetSync.save(activity: nil)
        XCTAssertNil(WidgetSync.defaults.string(forKey: "activity"))
    }

    func testSaveTimerAndIsActive() {
        WidgetSync.save(timer: 450.0, isActive: true)
        XCTAssertEqual(WidgetSync.timer, 450.0)
        XCTAssertEqual(WidgetSync.isActive, true)

        WidgetSync.save(timer: 900.0, isActive: false)
        XCTAssertEqual(WidgetSync.timer, 900.0)
        XCTAssertEqual(WidgetSync.isActive, false)

        WidgetSync.save(timer: 0, isActive: nil)
        XCTAssertEqual(WidgetSync.timer, 0)
        XCTAssertNil(WidgetSync.isActive)
    }
}
