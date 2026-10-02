import XCTest
@testable import KimaiClock

@MainActor
final class RecentActivitiesManagerTests: XCTestCase {
    var manager: RecentActivitiesManager!

    override func setUp() {
        super.setUp()
        manager = RecentActivitiesManager()
        manager.clearAll()
    }

    override func tearDown() {
        manager.clearAll()
        manager = nil
        super.tearDown()
    }

    private func createActivity(id: Int, project: Int = 1, name: String = "Test Activity") -> Activity {
        Activity(
            id: id,
            name: name,
            parentTitle: "Project \(project)",
            project: project,
            color: "#00FF00",
            timesheetId: nil
        )
    }

    func testInitialStateIsEmpty() {
        XCTAssertTrue(manager.activities.isEmpty)
    }

    func testAddActivity() {
        let activity = createActivity(id: 1)
        manager.add(activity)

        XCTAssertEqual(manager.activities.count, 1)
        XCTAssertEqual(manager.activities.first?.id, 1)
    }

    func testAddNilActivityDoesNothing() {
        manager.add(nil)
        XCTAssertTrue(manager.activities.isEmpty)
    }

    func testAddDuplicateActivityMovesToTop() {
        let activity1 = createActivity(id: 1)
        let activity2 = createActivity(id: 2)

        manager.add(activity1)
        manager.add(activity2)
        XCTAssertEqual(manager.activities.map(\.id), [2, 1])

        manager.add(activity1)
        XCTAssertEqual(manager.activities.map(\.id), [1, 2])
        XCTAssertEqual(manager.activities.count, 2)
    }

    func testMaxLengthCappedAtSix() {
        for id in 1...10 {
            manager.add(createActivity(id: id))
        }

        XCTAssertEqual(manager.activities.count, 6)
        XCTAssertEqual(manager.activities.first?.id, 10)
        XCTAssertEqual(manager.activities.last?.id, 5)
    }

    func testClearSpecificActivity() {
        let activity1 = createActivity(id: 1)
        let activity2 = createActivity(id: 2)

        manager.add(activity1)
        manager.add(activity2)
        XCTAssertEqual(manager.activities.count, 2)

        manager.clear(activity1)
        XCTAssertEqual(manager.activities.count, 1)
        XCTAssertEqual(manager.activities.first?.id, 2)
    }

    func testClearNilActivityDoesNothing() {
        let activity = createActivity(id: 1)
        manager.add(activity)
        manager.clear(nil)
        XCTAssertEqual(manager.activities.count, 1)
    }

    func testClearAllActivities() {
        manager.add(createActivity(id: 1))
        manager.add(createActivity(id: 2))
        XCTAssertEqual(manager.activities.count, 2)

        manager.clearAll()
        XCTAssertTrue(manager.activities.isEmpty)
    }
}
