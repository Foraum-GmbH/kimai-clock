import AppKit
import XCTest
@testable import KimaiClock

@MainActor
final class IconModelTests: XCTestCase {
    func testDefaultInit() {
        let model = IconModel()
        XCTAssertNotNil(model.icon)
        XCTAssertTrue(model.icon.isTemplate)
    }

    func testCustomSystemIconInit() {
        let model = IconModel(systemName: "pause.circle")
        XCTAssertNotNil(model.icon)
        XCTAssertTrue(model.icon.isTemplate)
    }

    func testSetSystemIcon() {
        let model = IconModel()
        model.setSystemIcon("play.circle")
        XCTAssertNotNil(model.icon)
        XCTAssertTrue(model.icon.isTemplate)
    }

    func testSetImage() {
        let model = IconModel()
        let customImage = NSImage(size: NSSize(width: 16, height: 16))
        model.setImage(customImage)
        XCTAssertEqual(model.icon, customImage)
        XCTAssertTrue(model.icon.isTemplate)
    }
}
