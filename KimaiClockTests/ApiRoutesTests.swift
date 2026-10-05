internal import Combine
import Foundation
import XCTest
@testable import KimaiClock

class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.host == "demo.kimai.org"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            do {
                let (response, data) = try handler(self.request)
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: data)
                self.client?.urlProtocolDidFinishLoading(self)
            } catch {
                self.client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}

@MainActor
final class ApiRoutesTests: XCTestCase {
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

    func testGetVersionRoute() {
        let expectation = expectation(description: "getVersion called")
        var interceptedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let json = Data("""
            {
                "versionId": 20400,
                "copyright": "Kimai 2.40.0"
            }
            """.utf8)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Length": "\(json.count)", "Content-Type": "application/json"]
            )!
            return (response, json)
        }

        apiManager.$serverVersion
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        apiManager.getVersion()
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(interceptedRequest?.url?.path, "/api/version")
        XCTAssertEqual(interceptedRequest?.httpMethod, "GET")
        XCTAssertEqual(apiManager.serverVersion, "Server: Kimai 2.40.0")
    }

    func testStartActivityRoute() {
        let expectation = expectation(description: "startActivity called")
        var interceptedRequest: URLRequest?

        apiManager.activeActivity = Activity(
            id: 42,
            name: "Coding",
            parentTitle: "App",
            project: 10,
            color: nil,
            timesheetId: nil
        )
        apiManager.pendingDescription = "Fixing bug"

        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let responseJson = Data("""
            {
                "id": 999
            }
            """.utf8)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, responseJson)
        }

        apiManager.startActivity()
            .sink { id in
                XCTAssertEqual(id, 999)
                XCTAssertEqual(self.apiManager.activeTimesheetId, 999)
                XCTAssertEqual(self.apiManager.pendingDescription, "")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(interceptedRequest?.url?.path, "/api/timesheets")
        XCTAssertEqual(interceptedRequest?.httpMethod, "POST")
        XCTAssertEqual(interceptedRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let json = interceptedRequest?.jsonBody ?? [:]
        XCTAssertFalse(json.isEmpty, "request body missing")
        XCTAssertEqual(json["activity"] as? Int, 42)
        XCTAssertEqual(json["project"] as? Int, 10)
        XCTAssertEqual(json["description"] as? String, "Fixing bug")
    }

    func testUpdateTimesheetDescriptionRoute() {
        let expectation = expectation(description: "updateTimesheetDescription called")
        var interceptedRequest: URLRequest?
        apiManager.activeTimesheetId = 555

        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        apiManager.updateTimesheetDescription("Updated notes")
            .sink { success in
                XCTAssertTrue(success)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(interceptedRequest?.url?.path, "/api/timesheets/555")
        XCTAssertEqual(interceptedRequest?.httpMethod, "PATCH")

        let json = interceptedRequest?.jsonBody ?? [:]
        XCTAssertFalse(json.isEmpty, "request body missing")
        XCTAssertEqual(json["description"] as? String, "Updated notes")
    }

    func testStopActivityRoute() {
        let expectation = expectation(description: "stopActivity called")
        var interceptedRequest: URLRequest?
        let activity = Activity(id: 1, name: "Task", parentTitle: nil, project: 1, color: nil, timesheetId: nil)
        apiManager.activeActivity = activity
        apiManager.activeTimesheetId = 777

        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        apiManager.stopActivity()
            .sink { success in
                XCTAssertTrue(success)
                XCTAssertNil(self.apiManager.activeTimesheetId)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(interceptedRequest?.url?.path, "/api/timesheets/777/stop")
        XCTAssertEqual(interceptedRequest?.httpMethod, "PATCH")
    }

    func testStopActivityAtRoute() {
        let expectation = expectation(description: "stopActivityAt called")
        var interceptedRequest: URLRequest?
        let activity = Activity(id: 3, name: "Meeting", parentTitle: nil, project: 5, color: nil, timesheetId: nil)
        apiManager.activeActivity = activity
        apiManager.activeTimesheetId = 888

        let targetDate = Date(timeIntervalSince1970: 1700000000)

        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        apiManager.stopActivityAt(targetDate)
            .sink { success in
                XCTAssertTrue(success)
                XCTAssertNil(self.apiManager.activeTimesheetId)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(interceptedRequest?.url?.path, "/api/timesheets/888")
        XCTAssertEqual(interceptedRequest?.httpMethod, "PATCH")

        let json = interceptedRequest?.jsonBody ?? [:]
        XCTAssertFalse(json.isEmpty, "request body missing")
        XCTAssertNotNil(json["end"])
        XCTAssertEqual(json["project"] as? Int, 5)
        XCTAssertEqual(json["activity"] as? Int, 3)
    }

    func testDeleteTimesheetRoute() {
        let expectation = expectation(description: "deleteTimesheet called")
        var interceptedRequest: URLRequest?
        apiManager.activeTimesheetId = 321

        MockURLProtocol.requestHandler = { request in
            interceptedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        apiManager.deleteTimesheet()
            .sink { success in
                XCTAssertTrue(success)
                XCTAssertNil(self.apiManager.activeTimesheetId)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(interceptedRequest?.url?.path, "/api/timesheets/321")
        XCTAssertEqual(interceptedRequest?.httpMethod, "DELETE")
    }

    func testIntervalForOptionValues() {
        XCTAssertEqual(apiManager.intervalForOption("sync_every_5_min"), 300)
        XCTAssertEqual(apiManager.intervalForOption("sync_every_15_min"), 900)
        XCTAssertEqual(apiManager.intervalForOption("sync_every_30_min"), 1800)
        XCTAssertNil(apiManager.intervalForOption("sync_on_open"))
        XCTAssertNil(apiManager.intervalForOption("invalid"))
    }
}
