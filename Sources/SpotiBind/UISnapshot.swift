import AppKit
import Darwin
import SwiftUI

@MainActor
enum UISnapshot {
    private enum Surface: String {
        case menu
        case settings
    }

    static func scheduleIfRequested(
        state: AppState,
        openSettings: @escaping () -> Void
    ) {
        let environment = ProcessInfo.processInfo.environment
        guard let directoryPath = environment["SPOTIBIND_UI_SNAPSHOT_DIR"],
              !directoryPath.isEmpty else {
            return
        }

        let surface = Surface(rawValue: environment["SPOTIBIND_UI_SNAPSHOT_SURFACE"] ?? "menu") ?? .menu
        let prefix = environment["SPOTIBIND_UI_SNAPSHOT_PREFIX"] ?? surface.rawValue
        let delayMilliseconds = Int(environment["SPOTIBIND_UI_SNAPSHOT_DELAY_MS"] ?? "") ?? 900
        let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
        let output = directory.appendingPathComponent("\(prefix).png")

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMilliseconds)) {
            let window: NSWindow?
            switch surface {
            case .menu:
                window = makeMenuWindow(state: state)
                window?.orderFrontRegardless()
            case .settings:
                openSettings()
                window = NSApp.windows.first {
                    $0.title == "SpotiBind" && $0.styleMask.contains(.titled)
                }
            }

            guard let window else {
                Darwin.exit(1)
            }
            window.displayIfNeeded()
            window.contentView?.layoutSubtreeIfNeeded()

            guard capture(window: window, to: output) else {
                Darwin.exit(1)
            }
            window.orderOut(nil)
            Darwin.exit(0)
        }
    }

    private static func makeMenuWindow(state: AppState) -> NSWindow {
        let hostingController = NSHostingController(rootView: MenuPanelView(state: state))
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 420),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        return window
    }

    private static func capture(window: NSWindow, to url: URL) -> Bool {
        guard let view = window.contentView else { return false }
        let bounds = view.bounds
        guard bounds.width > 4, bounds.height > 4,
              let representation = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            return false
        }

        representation.size = bounds.size
        view.cacheDisplay(in: bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            return false
        }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
    }
}
