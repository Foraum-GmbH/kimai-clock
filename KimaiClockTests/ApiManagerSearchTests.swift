internal import Combine
import Foundation
import XCTest
@testable import KimaiClock

@MainActor
final class ApiManagerSearchTests: XCTestCase {
    var apiManager: ApiManager!
    private var log = RequestLog()
    private let searchSubject = PassthroughSubject<String, Never>()

    override func setUp() async throws {
        try await super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        apiManager = ApiManager(session: URLSession(configuration: config))
        apiManager.serverIP = "https://demo.kimai.org"

        log = RequestLog()
        // eight project activities, one global activity and three projects for the global one
        let activities = (1...8).map { #"{"id": \#($0), "name": "A\#($0)", "parentTitle": "P", "project": 1}"# }
            + [#"{"id": 99, "name": "Global"}"#]
        let projects = (1...3).map { #"{"id": \#($0), "name": "Project \#($0)"}"# }
        MockURLProtocol.requestHandler = { [log] request in
            _ = log.record(request)
            let json = request.url?.path == "/api/projects"
                ? "[" + projects.joined(separator: ",") + "]"
                : "[" + activities.joined(separator: ",") + "]"
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }
        apiManager.bindSearch(to: searchSubject.eraseToAnyPublisher())
    }

    override func tearDown() async throws {
        MockURLProtocol.requestHandler = nil
        apiManager = nil
        try await super.tearDown()
    }

    private func query(of request: URLRequest?) -> [String: String] {
        let items = request?.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    private func search(_ text: String) -> [Activity] {
        let expectation = expectation(description: "results")
        var results: [Activity] = []
        let cancellable = apiManager.$searchResults
            .dropFirst()
            .sink { value in
                results = value
                expectation.fulfill()
            }
        searchSubject.send(text)
        wait(for: [expectation], timeout: 2)
        cancellable.cancel()
        return results
    }

    func testEmptySearchSuggestsFirstActivitiesAlphabetically() {
        let results = search("")

        XCTAssertEqual(results.count, ApiManager.suggestionCount)
        let activityRequest = log.requests.first { $0.url?.path == "/api/activities" }
        let items = query(of: activityRequest)
        XCTAssertNil(items["term"])
        XCTAssertEqual(items["order"], "ASC")
        XCTAssertEqual(items["visible"], "1")
    }

    func testSearchSendsTermAndKeepsOrder() {
        let results = search("dev")

        let items = query(of: log.requests.first { $0.url?.path == "/api/activities" })
        XCTAssertEqual(items["term"], "dev")
        XCTAssertEqual(items["order"], "DESC")
        // a typed search is not capped to the suggestion count
        XCTAssertFalse(results.isEmpty)
    }

    func testClearingSearchShowsSuggestionsAgain() {
        _ = search("dev")
        let results = search("")

        XCTAssertEqual(results.count, ApiManager.suggestionCount)
        XCTAssertNil(query(of: log.requests.last { $0.url?.path == "/api/activities" })["term"])
    }

    func testSearchActivitysWithoutQueryOmitsTerm() {
        let expectation = expectation(description: "activities")
        let cancellable = apiManager.searchActivitys(query: "", 3)
            .sink { activities in
                XCTAssertEqual(activities.count, 3)
                expectation.fulfill()
            }
        wait(for: [expectation], timeout: 2)
        cancellable.cancel()

        XCTAssertNil(query(of: log.requests.first)["term"])
    }
}
