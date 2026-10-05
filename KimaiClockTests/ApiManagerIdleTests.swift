internal import Combine
import Foundation
import XCTest
@testable import KimaiClock

@MainActor
final class ApiManagerIdleTests: XCTestCase {
    var apiManager: ApiManager!
    var mockSession: URLSession!
    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        cancellables.removeAll()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)

        apiManager = ApiManager(session: mockSession)
        apiManager.serverIP = "https://demo.kimai.org"
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        cancellables.removeAll()
        apiManager = nil
        mockSession = nil
        super.tearDown()
    }

    func testStopActivityWithTotalIdleOffsetRoutesThroughStopActivityAt() {
        let expectation = expectation(description: "stopActivity with offset called")
        var interceptedRequest: URLRequest?
        let activity = Activity(id: 3, name: "Meeting", parentTitle: nil, project: 5, color: nil, timesheetId: nil)
        apiManager.activeActivity = activity
        apiManager.activeTimesheetId = 999
        apiManager.totalIdleOffset = 600

        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        apiManager.stopActivity()
            .sink { success in
                XCTAssertTrue(success)
                XCTAssertNil(self.apiManager.activeTimesheetId)
                XCTAssertEqual(self.apiManager.totalIdleOffset, 0)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(interceptedRequest?.url?.path, "/api/timesheets/999")
        XCTAssertEqual(interceptedRequest?.httpMethod, "PATCH")

        let json = interceptedRequest?.jsonBody ?? [:]
        XCTAssertFalse(json.isEmpty, "request body missing")
        XCTAssertNotNil(json["end"])
        XCTAssertEqual(json["project"] as? Int, 5)
        XCTAssertEqual(json["activity"] as? Int, 3)
    }

    func testStartActivityResetsTotalIdleOffset() {
        let expectation = expectation(description: "startActivity resets offset")
        let activity = Activity(id: 10, name: "Coding", parentTitle: nil, project: 20, color: nil, timesheetId: nil)
        apiManager.activeActivity = activity
        apiManager.totalIdleOffset = 450

        MockURLProtocol.requestHandler = { request in
            let json = Data("""
            {
                "id": 1234
            }
            """.utf8)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        apiManager.startActivity()
            .sink { id in
                XCTAssertEqual(id, 1234)
                XCTAssertEqual(self.apiManager.totalIdleOffset, 0)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)
    }

    func testStopActivityAtWithNilProjectSerializesSuccessfully() {
        let expectation = expectation(description: "stopActivityAt with nil project")
        var interceptedRequest: URLRequest?
        let activity = Activity(
            id: 7,
            name: "Global Activity",
            parentTitle: nil,
            project: nil,
            color: nil,
            timesheetId: nil
        )
        apiManager.activeActivity = activity
        apiManager.activeTimesheetId = 777

        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let stopDate = Date(timeIntervalSince1970: 1_700_000_500)
        apiManager.stopActivityAt(stopDate)
            .sink { success in
                XCTAssertTrue(success)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(interceptedRequest?.url?.path, "/api/timesheets/777")
        XCTAssertEqual(interceptedRequest?.httpMethod, "PATCH")

        let json = interceptedRequest?.jsonBody ?? [:]
        XCTAssertFalse(json.isEmpty, "request body missing")
        XCTAssertNotNil(json["end"])
        XCTAssertEqual(json["activity"] as? Int, 7)
        XCTAssertNil(json["project"])
    }

    private let meeting = Activity(id: 3, name: "Meeting", parentTitle: nil, project: 5, color: nil, timesheetId: nil)
    private let coding = Activity(id: 10, name: "Coding", parentTitle: nil, project: 20, color: nil, timesheetId: nil)

    func testStopActivityAtExplicitEndDeductsPreviousIdleOffset() {
        let expectation = expectation(description: "stop at idle start with previous offset")
        var interceptedRequest: URLRequest?
        apiManager.activeActivity = meeting
        apiManager.activeTimesheetId = 42
        apiManager.totalIdleOffset = 1800

        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let idleStart = Date(timeIntervalSince1970: 1_700_003_600)
        apiManager.stopActivity(at: idleStart)
            .sink { success in
                XCTAssertTrue(success)
                XCTAssertEqual(self.apiManager.totalIdleOffset, 0)
                XCTAssertEqual(self.apiManager.lastTimesheetId, 42)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        let formatter = ISO8601DateFormatter()
        let end = (interceptedRequest?.jsonBody?["end"] as? String).flatMap(formatter.date(from:))
        XCTAssertEqual(end, idleStart.addingTimeInterval(-1800))
    }

    func testStopActivityWithoutTimesheetSucceedsEvenWithOffset() {
        let expectation = expectation(description: "nothing to stop")
        apiManager.activeActivity = meeting
        apiManager.activeTimesheetId = nil
        apiManager.totalIdleOffset = 600

        MockURLProtocol.requestHandler = { _ in
            XCTFail("No request expected")
            throw URLError(.badURL)
        }

        apiManager.stopActivity(at: Date())
            .sink { success in
                XCTAssertTrue(success)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)
    }

    func testResumeAfterPauseReusesSessionDescription() {
        apiManager.activeActivity = coding
        apiManager.pendingDescription = "Refactoring"

        var bodies: [[String: Any]] = []
        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "POST", let body = request.jsonBody {
                bodies.append(body)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id": 1}"#.utf8))
        }

        let started = expectation(description: "start")
        apiManager.startActivity().sink { _ in started.fulfill() }.store(in: &cancellables)
        wait(for: [started], timeout: 2.0)
        XCTAssertEqual(apiManager.pendingDescription, "")
        XCTAssertEqual(apiManager.sessionDescription, "Refactoring")

        let paused = expectation(description: "pause")
        apiManager.stopActivity().sink { _ in paused.fulfill() }.store(in: &cancellables)
        wait(for: [paused], timeout: 2.0)

        let resumed = expectation(description: "resume")
        apiManager.startActivity().sink { _ in resumed.fulfill() }.store(in: &cancellables)
        wait(for: [resumed], timeout: 2.0)

        XCTAssertEqual(bodies.count, 2)
        XCTAssertEqual(bodies.last?["description"] as? String, "Refactoring")
    }

    func testChangingActivityClearsSessionDescription() {
        apiManager.activeActivity = coding
        apiManager.updateTimesheetDescription("Local only").sink { _ in }.store(in: &cancellables)
        XCTAssertEqual(apiManager.sessionDescription, "Local only")

        apiManager.activeActivity = nil
        XCTAssertEqual(apiManager.sessionDescription, "")
    }

    func testUpdateDescriptionWhilePausedTargetsLastSegment() {
        let expectation = expectation(description: "update last segment")
        var interceptedRequest: URLRequest?
        apiManager.activeActivity = coding
        apiManager.activeTimesheetId = 55

        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        apiManager.stopActivity()
            .flatMap { _ in self.apiManager.updateTimesheetDescription("Notes") }
            .sink { success in
                XCTAssertTrue(success)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(interceptedRequest?.url?.path, "/api/timesheets/55")
        XCTAssertEqual(interceptedRequest?.jsonBody?["description"] as? String, "Notes")
        XCTAssertEqual(apiManager.sessionDescription, "Notes")
    }
}
