import AppKit
import SwiftUI

enum StatusBarIcon {
    static let resourceName = "StatusBarMark"
    static let fallbackSystemImage = "waveform"
    static let templateSize = NSSize(width: 20, height: 20)

    static func templateImage(bundle: Bundle = .main) -> NSImage? {
        guard let url = bundle.url(forResource: resourceName, withExtension: "svg"),
              let image = templateImage(url: url) else {
            return nil
        }

        return image
    }

    static func templateImage(url: URL) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.isTemplate = true
        image.size = templateSize
        return image
    }
}

struct StatusBarIconView: View {
    private let image: NSImage?

    init(bundle: Bundle = .main) {
        image = StatusBarIcon.templateImage(bundle: bundle)
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: StatusBarIcon.fallbackSystemImage)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: StatusBarIcon.templateSize.width, height: StatusBarIcon.templateSize.height)
        .accessibilityLabel("SpotiBind")
        .help("SpotiBind")
    }
}
