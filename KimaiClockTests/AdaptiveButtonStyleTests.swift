import SwiftUI
import XCTest
@testable import KimaiClock

final class AdaptiveButtonStyleTests: XCTestCase {
    func testProperties() {
        let styleDefault = AdaptiveButtonStyle()
        XCTAssertFalse(styleDefault.isProminent)
        XCTAssertFalse(styleDefault.isDanger)
        XCTAssertFalse(styleDefault.isDisabled)

        let styleCustom = AdaptiveButtonStyle(isProminent: true, isDanger: false, isDisabled: true)
        XCTAssertTrue(styleCustom.isProminent)
        XCTAssertFalse(styleCustom.isDanger)
        XCTAssertTrue(styleCustom.isDisabled)
    }
}
