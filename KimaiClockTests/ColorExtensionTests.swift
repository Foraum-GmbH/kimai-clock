import SwiftUI
import XCTest
@testable import KimaiClock

@MainActor
final class ColorExtensionTests: XCTestCase {
    func testValidHexColors() {
        XCTAssertNotNil(Color(hex: "#FF0000"))
        XCTAssertNotNil(Color(hex: "00FF00"))
        XCTAssertNotNil(Color(hex: "#0000FF"))
        XCTAssertNotNil(Color(hex: " #abcdef "))
    }

    func testInvalidHexColors() {
        XCTAssertNil(Color(hex: ""))
        XCTAssertNil(Color(hex: " "))
        XCTAssertNil(Color(hex: "#ZZZZZZ"))
    }
}
