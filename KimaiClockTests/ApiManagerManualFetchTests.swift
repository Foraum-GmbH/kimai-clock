import Foundation
import XCTest
@testable import KimaiClock

/// "Fetch active server timer now" button: `checkForRemoteTimer(force: true)` ignores the sync option
@MainActor
final class ApiManagerManualFetchTests: XCTestCase {
    var apiManager: ApiManager!
    private var storedSyncOption: String?
    private var log = RequestLog()

    override func setUp() async throws {
        try await super.setUp()
        storedSyncOption = UserDefaults.standard.string(forKey: "syncTimer")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        apiManager = ApiManager(session: URLSession(configuration: config))
        apiManager.serverIP = "https://demo.kimai.org"

        log = RequestLog()
        MockURLProtocol.requestHandler = { [log] request in
            let code = log.record(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }
    }

    override func tearDown() async throws {
        MockURLProtocol.requestHandler = nil
        apiManager = nil
        if let storedSyncOption {
            UserDefaults.standard.set(storedSyncOption, forKey: "syncTimer")
        } else {
            UserDefaults.standard.removeObject(forKey: "syncTimer")
        }
        try await super.tearDown()
    }

    private func requestCount(option: String, onOpen: Bool, force: Bool) -> Int {
        UserDefaults.standard.set(option, forKey: "syncTimer")
        apiManager.checkForRemoteTimer(onOpen, force: force) { _ in }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        return log.requests.count
    }

    func testForceFetchesWithIntervalOption() {
        XCTAssertEqual(requestCount(option: "sync_every_15_min", onOpen: false, force: true), 1)
        XCTAssertEqual(log.requests.first?.url?.path, "/api/timesheets/active")
    }

    func testForceFetchesWithOnOpenOption() {
        XCTAssertEqual(requestCount(option: "sync_on_open", onOpen: false, force: true), 1)
    }

    func testWithoutForceOnOpenCheckIsSkippedForIntervalOption() {
        XCTAssertEqual(requestCount(option: "sync_every_15_min", onOpen: true, force: false), 0)
    }

    func testWithoutForceIntervalCheckIsSkippedForOnOpenOption() {
        XCTAssertEqual(requestCount(option: "sync_on_open", onOpen: false, force: false), 0)
    }

    func testForceStopsLocalTimerWhenServerHasNone() {
        UserDefaults.standard.set("sync_every_30_min", forKey: "syncTimer")
        apiManager.activeActivity = Activity(
            id: 10, name: "Coding", parentTitle: "Kimai", project: 20, color: nil, timesheetId: nil
        )
        apiManager.activeTimesheetId = 5

        let expectation = expectation(description: "local timer stopped")
        apiManager.checkForRemoteTimer(force: true) { seconds in
            XCTAssertEqual(seconds, -1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        XCTAssertNil(apiManager.activeActivity)
    }
}
