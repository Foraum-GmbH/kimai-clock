import SwiftUI
import XCTest
@testable import KimaiClock

@MainActor
final class ViewExtensionTests: XCTestCase {
    func testViewIfCondition() {
        let text = Text("Hello")
        let modifiedTrue = text.if(true) { view in
            view.bold()
        }
        XCTAssertNotNil(modifiedTrue)

        let modifiedFalse = text.if(false) { view in
            view.bold()
        }
        XCTAssertNotNil(modifiedFalse)
    }
}
