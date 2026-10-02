import SwiftUI
import XCTest
@testable import KimaiClock

@MainActor
final class ApiManagerModelTests: XCTestCase {
    func testActivityUniqueIdWithProject() {
        let activity = Activity(
            id: 42,
            name: "Development",
            parentTitle: "Project Alpha",
            project: 10,
            color: "#FF5500",
            timesheetId: 100
        )

        XCTAssertEqual(activity.uniqueId, "42-10")
        XCTAssertEqual(activity.id, 42)
        XCTAssertEqual(activity.name, "Development")
        XCTAssertEqual(activity.parentTitle, "Project Alpha")
        XCTAssertEqual(activity.project, 10)
        XCTAssertEqual(activity.color, "#FF5500")
        XCTAssertEqual(activity.timesheetId, 100)
    }

    func testActivityUniqueIdWithoutProject() {
        let activity = Activity(
            id: 7,
            name: "Meeting",
            parentTitle: nil,
            project: nil,
            color: nil,
            timesheetId: nil
        )

        XCTAssertEqual(activity.uniqueId, "7-0")
        XCTAssertNil(activity.parentTitle)
        XCTAssertNil(activity.project)
        XCTAssertNil(activity.color)
        XCTAssertNil(activity.timesheetId)
    }

    func testActivityColorFallback() {
        let activityWithValidColor = Activity(
            id: 1,
            name: "Task",
            parentTitle: nil,
            project: nil,
            color: "#00FF00",
            timesheetId: nil
        )
        XCTAssertNotNil(activityWithValidColor.activityColor)

        let activityWithInvalidColor = Activity(
            id: 2,
            name: "Task",
            parentTitle: nil,
            project: nil,
            color: "invalid",
            timesheetId: nil
        )
        XCTAssertEqual(activityWithInvalidColor.activityColor, Color.kimai)

        let activityWithoutColor = Activity(
            id: 3,
            name: "Task",
            parentTitle: nil,
            project: nil,
            color: nil,
            timesheetId: nil
        )
        XCTAssertEqual(activityWithoutColor.activityColor, Color.kimai)
    }

    func testActivityEquality() {
        let activity1 = Activity(id: 1, name: "Task", parentTitle: "Proj", project: 2, color: "#FFF", timesheetId: nil)
        let activity2 = Activity(id: 1, name: "Task", parentTitle: "Proj", project: 2, color: "#FFF", timesheetId: nil)
        let activity3 = Activity(id: 2, name: "Task", parentTitle: "Proj", project: 2, color: "#FFF", timesheetId: nil)

        XCTAssertEqual(activity1, activity2)
        XCTAssertNotEqual(activity1, activity3)
    }

    func testActivityCodableRoundTrip() throws {
        let activity = Activity(
            id: 15,
            name: "Review",
            parentTitle: "Backend",
            project: 3,
            color: "#336699",
            timesheetId: 99
        )

        let data = try JSONEncoder().encode(activity)
        let decoded = try JSONDecoder().decode(Activity.self, from: data)

        XCTAssertEqual(decoded.id, activity.id)
        XCTAssertEqual(decoded.name, activity.name)
        XCTAssertEqual(decoded.parentTitle, activity.parentTitle)
        XCTAssertEqual(decoded.project, activity.project)
        XCTAssertEqual(decoded.color, activity.color)
        XCTAssertEqual(decoded.timesheetId, activity.timesheetId)
    }

    func testPendingDescriptionTrimming() {
        let manager = ApiManager()
        manager.pendingDescription = "   working on feature   \n"
        XCTAssertEqual(manager.pendingDescription.trimmingCharacters(in: .whitespacesAndNewlines), "working on feature")
    }
}
