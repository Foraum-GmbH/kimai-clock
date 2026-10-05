import Foundation
import XCTest
@testable import KimaiClock

@MainActor
final class QuickActionTests: XCTestCase {
    func testStartLastWithoutDescription() {
        guard let url = URL(string: "kimai-clock://startLast") else {
            XCTFail("Failed to construct URL")
            return
        }
        XCTAssertEqual(AppDelegate.QuickAction(url: url), .startLast(description: nil))
    }

    func testStartLastWithDescriptionQuery() {
        guard let url = URL(string: "kimai-clock://startLast?description=Refactor%20API") else {
            XCTFail("Failed to construct URL")
            return
        }
        XCTAssertEqual(AppDelegate.QuickAction(url: url), .startLast(description: "Refactor API"))
    }

    func testStartLastWithDescQuery() {
        guard let url = URL(string: "kimai-clock://startLast?desc=Bugfix") else {
            XCTFail("Failed to construct URL")
            return
        }
        XCTAssertEqual(AppDelegate.QuickAction(url: url), .startLast(description: "Bugfix"))
    }

    func testStartLastWithEmptyDescription() {
        guard let url = URL(string: "kimai-clock://startLast?description=%20%20") else {
            XCTFail("Failed to construct URL")
            return
        }
        XCTAssertEqual(AppDelegate.QuickAction(url: url), .startLast(description: nil))
    }

    func testPauseAction() {
        guard let url = URL(string: "kimai-clock://pause") else {
            XCTFail("Failed to construct URL")
            return
        }
        XCTAssertEqual(AppDelegate.QuickAction(url: url), .pause)
    }

    func testStopAction() {
        guard let url = URL(string: "kimai-clock://stop") else {
            XCTFail("Failed to construct URL")
            return
        }
        XCTAssertEqual(AppDelegate.QuickAction(url: url), .stop)
    }

    func testInvalidScheme() {
        guard let url = URL(string: "https://startLast") else {
            XCTFail("Failed to construct URL")
            return
        }
        XCTAssertNil(AppDelegate.QuickAction(url: url))
    }

    func testUnknownAction() {
        guard let url = URL(string: "kimai-clock://unknownAction") else {
            XCTFail("Failed to construct URL")
            return
        }
        XCTAssertNil(AppDelegate.QuickAction(url: url))
    }
}
