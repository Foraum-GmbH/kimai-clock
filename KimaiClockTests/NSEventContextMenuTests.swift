import AppKit
import XCTest
@testable import KimaiClock

@MainActor
final class NSEventContextMenuTests: XCTestCase {
    private func mouseEvent(_ type: NSEvent.EventType, modifiers: NSEvent.ModifierFlags = []) -> NSEvent? {
        NSEvent.mouseEvent(
            with: type, location: .zero, modifierFlags: modifiers, timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        )
    }

    func testRightClickOpensContextMenu() {
        XCTAssertTrue(NSEvent.opensContextMenu(mouseEvent(.rightMouseDown)))
    }

    func testControlClickOpensContextMenu() {
        XCTAssertTrue(NSEvent.opensContextMenu(mouseEvent(.leftMouseDown, modifiers: .control)))
    }

    func testPlainLeftClickOpensDropdown() {
        XCTAssertFalse(NSEvent.opensContextMenu(mouseEvent(.leftMouseDown)))
        XCTAssertFalse(NSEvent.opensContextMenu(mouseEvent(.leftMouseDown, modifiers: .option)))
    }

    func testMissingEventIsNoContextMenu() {
        XCTAssertFalse(NSEvent.opensContextMenu(nil))
    }
}
