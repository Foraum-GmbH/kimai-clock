internal import Combine
import Foundation
import XCTest
@testable import KimaiClock

@MainActor
final class ApiManagerSyncTests: XCTestCase {
    var apiManager: ApiManager!
    var cancellables = Set<AnyCancellable>()
    private var storedSyncOption: String?

    private let coding = Activity(
        id: 10, name: "Coding", parentTitle: "Kimai", project: 20, color: nil, timesheetId: nil
    )

    override func setUp() {
        super.setUp()
        storedSyncOption = UserDefaults.standard.string(forKey: "syncTimer")
        UserDefaults.standard.set("sync_on_open", forKey: "syncTimer")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        apiManager = ApiManager(session: URLSession(configuration: config))
        apiManager.serverIP = "https://demo.kimai.org"
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        cancellables.removeAll()
        apiManager = nil
        if let storedSyncOption {
            UserDefaults.standard.set(storedSyncOption, forKey: "syncTimer")
        } else {
            UserDefaults.standard.removeObject(forKey: "syncTimer")
        }
        super.tearDown()
    }

    private func respond(_ status: Int = 200, json: String) {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }
    }

    // MARK: - Remote timer sync

    func testCheckForRemoteTimerAdoptsRunningTimesheetWithDescription() {
        let begin = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        respond(json: """
        [{"id": 77, "begin": "\(begin)", "description": "Remote note",
          "activity": {"id": 10, "name": "Coding", "color": "#ff0000"},
          "project": {"id": 20, "name": "Kimai"}}]
        """)

        let expectation = expectation(description: "remote timer adopted")
        apiManager.checkForRemoteTimer(true) { seconds in
            XCTAssertEqual(seconds, 3600, accuracy: 5)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(apiManager.activeTimesheetId, 77)
        XCTAssertEqual(apiManager.activeActivity?.uniqueId, "10-20")
        XCTAssertEqual(apiManager.activeActivity?.parentTitle, "Kimai")
        XCTAssertEqual(apiManager.sessionDescription, "Remote note")
    }

    func testCheckForRemoteTimerStopsLocalTimerWhenRemoteStopped() {
        apiManager.activeActivity = coding
        apiManager.activeTimesheetId = 5
        respond(json: "[]")

        let expectation = expectation(description: "local timer stopped")
        apiManager.checkForRemoteTimer(true) { seconds in
            XCTAssertEqual(seconds, -1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        XCTAssertNil(apiManager.activeActivity)
        XCTAssertNil(apiManager.activeTimesheetId)
    }

    func testCheckForRemoteTimerRespectsSyncOption() {
        MockURLProtocol.requestHandler = { _ in
            XCTFail("No request expected for a periodic check with sync_on_open")
            throw URLError(.badURL)
        }
        apiManager.checkForRemoteTimer(false) { _ in XCTFail("No callback expected") }
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }

    // MARK: - Search

    func testSearchActivitysSendsTermAndLimitsResults() {
        var interceptedRequest: URLRequest?
        let activities = (1...10).map { #"{"id": \#($0), "name": "A\#($0)", "parentTitle": "P", "project": 1}"# }
        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[\(activities.joined(separator: ","))]".utf8))
        }

        let expectation = expectation(description: "search")
        apiManager.searchActivitys(query: "dev", 3)
            .sink { result in
                XCTAssertEqual(result.map(\.id), [1, 2, 3])
                expectation.fulfill()
            }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 2)

        let query = URLComponents(url: interceptedRequest!.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(query.first { $0.name == "term" }?.value, "dev")
        XCTAssertEqual(query.first { $0.name == "visible" }?.value, "1")
    }

    func testSearchWithVirtualsExpandsGlobalActivitiesPerProject() {
        MockURLProtocol.requestHandler = { request in
            let json = request.url?.path == "/api/projects"
                ? #"[{"id": 1, "name": "Alpha"}, {"id": 2, "name": "Beta"}]"#
                : #"[{"id": 9, "name": "Support"}]"#
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let expectation = expectation(description: "virtuals")
        apiManager.searchActivitiesWithVirtuals(query: "sup")
            .sink { result in
                XCTAssertEqual(result.map(\.uniqueId), ["9-1", "9-2"])
                XCTAssertEqual(result.map(\.parentTitle), ["Alpha", "Beta"])
                expectation.fulfill()
            }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 2)
    }

    func testSearchReturnsEmptyOnServerError() {
        respond(500, json: "nope")

        let expectation = expectation(description: "search error")
        apiManager.searchActivitys(query: "x")
            .sink { result in
                XCTAssertTrue(result.isEmpty)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 2)
    }

    // MARK: - Failure paths

    func testStartActivityFailureKeepsState() {
        apiManager.activeActivity = coding
        apiManager.pendingDescription = "Keep me"
        respond(500, json: "{}")

        let expectation = expectation(description: "start failed")
        apiManager.startActivity()
            .sink { id in
                XCTAssertNil(id)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 2)

        XCTAssertNil(apiManager.activeTimesheetId)
        XCTAssertEqual(apiManager.pendingDescription, "Keep me")
        XCTAssertEqual(apiManager.sessionDescription, "")
    }

    func testStartActivityExplicitDescriptionWinsOverPendingAndSession() {
        var interceptedRequest: URLRequest?
        apiManager.activeActivity = coding
        apiManager.pendingDescription = "typed"
        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id": 1}"#.utf8))
        }

        let expectation = expectation(description: "start")
        apiManager.startActivity(description: "  from url  ")
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(interceptedRequest?.jsonBody?["description"] as? String, "from url")
        XCTAssertEqual(apiManager.sessionDescription, "from url")
    }

    func testStartActivityWithoutActivityDoesNothing() {
        let expectation = expectation(description: "no activity")
        apiManager.startActivity()
            .sink { id in
                XCTAssertNil(id)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 2)
    }

    func testStopActivityFailureKeepsTimesheetAndOffset() {
        apiManager.activeActivity = coding
        apiManager.activeTimesheetId = 12
        apiManager.totalIdleOffset = 300
        respond(500, json: "{}")

        let expectation = expectation(description: "stop failed")
        apiManager.stopActivity()
            .sink { success in
                XCTAssertFalse(success)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(apiManager.activeTimesheetId, 12)
        XCTAssertEqual(apiManager.totalIdleOffset, 300)
        XCTAssertNil(apiManager.lastTimesheetId)
    }

    func testDeleteTimesheetFailureKeepsTimesheet() {
        apiManager.activeTimesheetId = 12
        respond(500, json: "{}")

        let expectation = expectation(description: "delete failed")
        apiManager.deleteTimesheet()
            .sink { success in
                XCTAssertFalse(success)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(apiManager.activeTimesheetId, 12)
    }

    func testUpdateDescriptionWithoutSessionFails() {
        let expectation = expectation(description: "no session")
        apiManager.updateTimesheetDescription("x")
            .sink { success in
                XCTAssertFalse(success)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 2)
    }

    func testUpdateDescriptionFailureKeepsSessionDescription() {
        apiManager.activeActivity = coding
        apiManager.activeTimesheetId = 12
        respond(500, json: "{}")

        let expectation = expectation(description: "update failed")
        apiManager.updateTimesheetDescription("new")
            .sink { success in
                XCTAssertFalse(success)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(apiManager.sessionDescription, "")
    }

    func testGetVersionMarksOldServersUnsupported() {
        respond(json: #"{"versionId": 10900, "copyright": "Kimai 1"}"#)

        let cancellable = apiManager.getVersion()
        let deadline = Date().addingTimeInterval(2)
        while apiManager.serverVersion == "..." && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        cancellable.cancel()

        XCTAssertEqual(apiManager.serverVersion, "Server: unsupported")
    }
}
