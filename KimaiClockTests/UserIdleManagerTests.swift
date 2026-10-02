import XCTest
@testable import KimaiClock

@MainActor
final class UserIdleManagerTests: XCTestCase {
    func testInitializationAndReset() {
        var triggered = false
        let manager = UserIdleManager(threshold: 60.0, checkInterval: 10.0) { _, _ in
            triggered = true
        }

        manager.reset()
        XCTAssertFalse(triggered)
    }
}
