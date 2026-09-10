import AppKit
import SwiftUI

enum StatusBarIcon {
    static let resourceName = "StatusBarMark"
    static let fallbackSystemImage = "waveform"

    static func templateImage(bundle: Bundle = .main) -> NSImage? {
        guard let url = bundle.url(forResource: resourceName, withExtension: "svg"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
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
        .frame(width: 18, height: 18)
        .accessibilityLabel("SpotiBind")
        .help("SpotiBind")
    }
}
