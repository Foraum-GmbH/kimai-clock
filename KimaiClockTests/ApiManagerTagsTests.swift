internal import Combine
import Foundation
import XCTest
@testable import KimaiClock

@MainActor
final class ApiManagerTagsTests: XCTestCase {
    var apiManager: ApiManager!
    var cancellables = Set<AnyCancellable>()

    private let coding = Activity(
        id: 10, name: "Coding", parentTitle: "Kimai", project: 20, color: nil, timesheetId: nil
    )

    override func setUp() async throws {
        try await super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        apiManager = ApiManager(session: URLSession(configuration: config))
        apiManager.serverIP = "https://demo.kimai.org"
    }

    override func tearDown() async throws {
        MockURLProtocol.requestHandler = nil
        cancellables.removeAll()
        apiManager = nil
        try await super.tearDown()
    }

    /// Answers every request with `json` and returns the captured requests
    private func respond(_ status: Int = 200, json: String) -> RequestLog {
        let log = RequestLog()
        log.statusCode = status
        MockURLProtocol.requestHandler = { [log] request in
            let code = log.record(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }
        return log
    }

    private func awaitTags() -> [String] {
        let expectation = expectation(description: "tags")
        var result: [String] = []
        apiManager.$availableTags
            .dropFirst()
            .sink { tags in
                result = tags
                expectation.fulfill()
            }
            .store(in: &cancellables)
        apiManager.fetchTags()
        wait(for: [expectation], timeout: 2)
        return result
    }

    private func start() -> URLRequest? {
        let log = respond(json: #"{"id": 5}"#)
        let expectation = expectation(description: "start")
        apiManager.startActivity()
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 2)
        return log.requests.last
    }

    // MARK: - Fetching

    func testFetchTagsLoadsNamesWithEmptyNameFilter() {
        let log = respond(json: #"[{"id": 1, "name": "billable", "color": null}, {"id": 2, "name": "urgent"}]"#)

        XCTAssertEqual(awaitTags(), ["billable", "urgent"])

        let url = log.requests.first?.url
        XCTAssertEqual(url?.path, "/api/tags/find")
        let query = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        // Kimai returns nothing without a name parameter
        XCTAssertEqual(query.first { $0.name == "name" }?.value, "")
    }

    func testFetchTagsFailureResultsInEmptyList() {
        _ = respond(500, json: "nope")
        apiManager.availableTags = ["stale"]

        XCTAssertEqual(awaitTags(), [])
    }

    func testFetchTagsFallsBackToNameListWhenFindIsEmpty() {
        let log = RequestLog()
        MockURLProtocol.requestHandler = { [log] request in
            _ = log.record(request)
            let json = request.url?.path == "/api/tags" ? #"["billable", "intern"]"# : "[]"
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        XCTAssertEqual(awaitTags(), ["billable", "intern"])
        XCTAssertEqual(log.requests.map { $0.url?.path }, ["/api/tags/find", "/api/tags"])
    }

    func testFetchTagsSkipsFallbackWhenFindHasTags() {
        let log = respond(json: #"[{"id": 1, "name": "billable"}]"#)

        XCTAssertEqual(awaitTags(), ["billable"])
        XCTAssertEqual(log.requests.count, 1)
    }

    func testFetchTagsWithNoTagsAnywhereIsEmpty() {
        let log = respond(json: "[]")

        XCTAssertEqual(awaitTags(), [])
        XCTAssertEqual(log.requests.count, 2)
    }

    func testFetchTagsWithoutServerDoesNothing() {
        apiManager.serverIP = nil
        let log = respond(json: "[]")

        apiManager.fetchTags()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        XCTAssertTrue(log.requests.isEmpty)
    }

    // MARK: - Starting

    func testStartActivitySendsSelectedTags() {
        apiManager.activeActivity = coding
        apiManager.sessionTags = ["billable", "urgent"]

        let request = start()

        XCTAssertEqual(request?.jsonBody?["tags"] as? String, "billable,urgent")
        // tags survive the start so a resume after pause sends them again
        XCTAssertEqual(apiManager.sessionTags, ["billable", "urgent"])
    }

    func testStartActivityWithoutTagsSendsNoTagsField() {
        apiManager.activeActivity = coding

        let request = start()

        XCTAssertNotNil(request?.jsonBody)
        XCTAssertNil(request?.jsonBody?["tags"])
    }

    func testTagsSurvivePauseAndResume() {
        apiManager.activeActivity = coding
        apiManager.sessionTags = ["billable"]
        _ = start()

        let paused = expectation(description: "paused")
        apiManager.stopActivity().sink { _ in paused.fulfill() }.store(in: &cancellables)
        wait(for: [paused], timeout: 2)

        let resume = start()

        XCTAssertEqual(resume?.jsonBody?["tags"] as? String, "billable")
    }

    // MARK: - Session

    func testChangingActivityClearsTags() {
        apiManager.activeActivity = coding
        apiManager.sessionTags = ["billable"]

        apiManager.activeActivity = Activity(
            id: 3, name: "Meeting", parentTitle: "Intern", project: 5, color: nil, timesheetId: nil
        )

        XCTAssertTrue(apiManager.sessionTags.isEmpty)
    }

    func testReassigningSameActivityKeepsTags() {
        apiManager.activeActivity = coding
        apiManager.sessionTags = ["billable"]

        apiManager.activeActivity = coding

        XCTAssertEqual(apiManager.sessionTags, ["billable"])
    }

    func testRemoteTimerWithoutTagsClearsTags() {
        let begin = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60))
        _ = respond(json: """
        [{"id": 77, "begin": "\(begin)",
          "activity": {"id": 10, "name": "Coding"}, "project": {"id": 20, "name": "Kimai"}}]
        """)
        apiManager.sessionTags = ["leftover"]

        let expectation = expectation(description: "remote timer adopted")
        apiManager.checkForRemoteTimer(force: true) { _ in expectation.fulfill() }
        wait(for: [expectation], timeout: 2)

        XCTAssertTrue(apiManager.sessionTags.isEmpty)
    }

    // MARK: - Options

    func testTagOptionsEmptyWithoutTagsSoDropdownIsHidden() {
        XCTAssertTrue(apiManager.tagOptions.isEmpty)
    }

    func testTagOptionsIncludeSessionTagsMissingOnServer() {
        apiManager.availableTags = ["billable", "urgent"]
        apiManager.sessionTags = ["urgent", "remote-only"]

        XCTAssertEqual(apiManager.tagOptions, ["billable", "urgent", "remote-only"])
    }

    func testTagOptionsFromRemoteTimerAloneShowDropdown() {
        apiManager.sessionTags = ["remote-only"]

        XCTAssertEqual(apiManager.tagOptions, ["remote-only"])
    }
}
