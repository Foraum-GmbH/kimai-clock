import XCTest
@testable import KimaiClock

@MainActor
final class PopoverStateTests: XCTestCase {
    func testInitialState() {
        let state = PopoverState()
        XCTAssertFalse(state.isPresented)
    }

    func testToggleState() {
        let state = PopoverState()
        state.isPresented = true
        XCTAssertTrue(state.isPresented)
        state.isPresented = false
        XCTAssertFalse(state.isPresented)
    }
}
