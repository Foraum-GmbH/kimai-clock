internal import Combine
import Foundation
import XCTest
@testable import KimaiClock

@MainActor
final class ApiManagerStartStopTests: XCTestCase {
    var apiManager: ApiManager!
    var cancellables = Set<AnyCancellable>()

    private let coding = Activity(id: 10, name: "Coding", parentTitle: nil, project: 20, color: nil, timesheetId: nil)

    override func setUp() async throws {
        try await super.setUp()
        cancellables.removeAll()

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

    func testStartActivityWithBeginSendsBeginTime() {
        let expectation = expectation(description: "start with begin")
        var interceptedRequest: URLRequest?
        apiManager.activeActivity = coding
        let begin = Date(timeIntervalSince1970: 1_800_000_000)

        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id": 7}"#.utf8))
        }

        apiManager.startActivity(begin: begin)
            .sink { id in
                XCTAssertEqual(id, 7)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        let sentBegin = interceptedRequest?.jsonBody?["begin"] as? String
        XCTAssertEqual(sentBegin.flatMap { ISO8601DateFormatter().date(from: $0) }, begin)
    }

    func testStartActivityWithoutBeginSendsNoBeginTime() {
        let expectation = expectation(description: "start without begin")
        var interceptedRequest: URLRequest?
        apiManager.activeActivity = coding

        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id": 7}"#.utf8))
        }

        apiManager.startActivity().sink { _ in expectation.fulfill() }.store(in: &cancellables)
        wait(for: [expectation], timeout: 2.0)

        XCTAssertNotNil(interceptedRequest?.jsonBody)
        XCTAssertNil(interceptedRequest?.jsonBody?["begin"])
    }

    func testLateStopResponseKeepsTimesheetStartedMeanwhile() {
        let expectation = expectation(description: "late stop")
        apiManager.activeActivity = coding
        apiManager.activeTimesheetId = 99

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        apiManager.stopActivity(at: Date())
            .sink { success in
                XCTAssertTrue(success)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        // a new timesheet was started before the stop response arrived
        apiManager.activeTimesheetId = 100
        apiManager.totalIdleOffset = 30

        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(apiManager.activeTimesheetId, 100)
        XCTAssertEqual(apiManager.totalIdleOffset, 30)
        XCTAssertNil(apiManager.lastTimesheetId)
    }

    func testPlainStopResponseKeepsTimesheetStartedMeanwhile() {
        let expectation = expectation(description: "late plain stop")
        apiManager.activeActivity = coding
        apiManager.activeTimesheetId = 99

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        apiManager.stopActivity().sink { _ in expectation.fulfill() }.store(in: &cancellables)
        apiManager.activeTimesheetId = 100

        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(apiManager.activeTimesheetId, 100)
    }
}
