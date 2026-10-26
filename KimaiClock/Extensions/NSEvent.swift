import AppKit

extension NSEvent {
    /// Context menus open on a right click or ctrl-click, dropdowns (pickers, menus) on a plain left click
    static func opensContextMenu(_ event: NSEvent?) -> Bool {
        guard let event else { return false }
        return event.type == .rightMouseDown
            || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
    }
}
