import SwiftUI
internal import Combine

final class IconModel: ObservableObject {
    @Published var icon: NSImage

    init(systemName: String = "circle") {
        let img = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) ?? NSImage()
        img.isTemplate = true
        self.icon = img
    }

    func setSystemIcon(_ systemName: String) {
        DispatchQueue.main.async {
            let img = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) ?? NSImage()
            img.isTemplate = true
            self.icon = img
        }
    }

    func setImage(_ image: NSImage) {
        DispatchQueue.main.async {
            image.isTemplate = true
            self.icon = image
        }
    }
}
