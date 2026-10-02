import XCTest
@testable import KimaiClock

@MainActor
final class LaunchAtLoginTests: XCTestCase {
    func testWasLaunchedAtLogin() {
        _ = LaunchAtLogin.wasLaunchedAtLogin
    }
}
