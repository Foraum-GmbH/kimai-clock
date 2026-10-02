import XCTest
@testable import KimaiClock

@MainActor
final class ChimeManagerTests: XCTestCase {
    func testChimeTypes() {
        let types: [ChimeType] = [.start, .pause, .stop, .error]
        XCTAssertEqual(types.count, 4)
    }

    func testPlayDoesNotCrash() {
        ChimeManager.shared.play(.start)
        ChimeManager.shared.play(.pause)
        ChimeManager.shared.play(.stop)
        ChimeManager.shared.play(.error)
    }
}
