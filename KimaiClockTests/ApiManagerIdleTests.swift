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

        if let bodyData = interceptedRequest?.httpBody,
           let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
            XCTAssertNotNil(json["end"])
            XCTAssertEqual(json["project"] as? Int, 5)
            XCTAssertEqual(json["activity"] as? Int, 3)
        }
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

    func testAdjustTimesheetBeginSendsPatchWithBeginDate() {
        let expectation = expectation(description: "adjustTimesheetBegin sent")
        var interceptedRequest: URLRequest?
        let activity = Activity(id: 3, name: "Meeting", parentTitle: nil, project: 5, color: nil, timesheetId: nil)
        apiManager.activeActivity = activity
        apiManager.activeTimesheetId = 888

        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let targetDate = Date(timeIntervalSince1970: 1_700_000_000)
        apiManager.adjustTimesheetBegin(to: targetDate)
            .sink { success in
                XCTAssertTrue(success)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(interceptedRequest?.url?.path, "/api/timesheets/888")
        XCTAssertEqual(interceptedRequest?.httpMethod, "PATCH")

        if let bodyData = interceptedRequest?.httpBody,
           let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
            XCTAssertNotNil(json["begin"])
        }
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

        guard let bodyData = interceptedRequest?.httpBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            XCTFail("Body failed to serialize or was empty")
            return
        }

        XCTAssertNotNil(json["end"])
        XCTAssertEqual(json["activity"] as? Int, 7)
        XCTAssertNil(json["project"])
    }
}
