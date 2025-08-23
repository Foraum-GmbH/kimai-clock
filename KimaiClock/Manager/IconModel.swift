import SwiftUI
internal import Combine

@MainActor
final class IconModel: ObservableObject {
    @Published var icon: NSImage

    init(systemName: String = "circle") {
        let img = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) ?? NSImage()
        img.isTemplate = true
        self.icon = img
    }

    func setSystemIcon(_ systemName: String) {
        let img = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) ?? NSImage()
        img.isTemplate = true
        self.icon = img
    }

    func setImage(_ image: NSImage) {
        image.isTemplate = true
        self.icon = image
    }
}
