import AppKit
import Darwin

@MainActor
enum UISnapshot {
    private enum Surface: String {
        case popover
        case settingsWindow = "settings-window"
    }

    private static let popoverMaxAttempts = 300
    private static let settingsMaxAttempts = 50
    private static let retryInterval: DispatchTimeInterval = .milliseconds(200)
    private static var hasTriggeredPopover = false

    static var isDemoRequested: Bool {
        UIDemoConfiguration.parse(environment: ProcessInfo.processInfo.environment) != nil
    }

    static func scheduleIfRequested(
        state: AppState,
        openSettings: @escaping () -> Void
    ) {
        guard state.isUIDemo else { return }
        guard let configuration = state.uiDemoConfiguration else {
            reportFailure("invalid demo scene or appearance")
            return
        }
        let environment = ProcessInfo.processInfo.environment
        guard let surface = Surface(rawValue: environment["SPOTIBIND_UI_SNAPSHOT_SURFACE"] ?? "") else {
            reportFailure("SPOTIBIND_UI_SNAPSHOT_SURFACE must be popover or settings-window")
            return
        }

        NSApp.appearance = NSAppearance(named: configuration.appearance.nsAppearance)
        switch surface {
        case .popover:
            guard let outputPath = environment["SPOTIBIND_UI_SNAPSHOT_OUTPUT"],
                  !outputPath.isEmpty else {
                reportFailure("popover capture requires SPOTIBIND_UI_SNAPSHOT_OUTPUT")
                return
            }
            triggerPopoverIfPossible()
            waitForPopover(output: URL(fileURLWithPath: outputPath), attempt: 0)
        case .settingsWindow:
            openSettings()
            waitForSettings(
                readyFile: environment["SPOTIBIND_UI_SNAPSHOT_READY_FILE"].map(URL.init(fileURLWithPath:)),
                attempt: 0
            )
        }
    }

    private static func waitForPopover(output: URL, attempt: Int) {
        guard let window = menuBarExtraHost() else {
            triggerPopoverIfPossible()
            guard attempt < popoverMaxAttempts else {
                reportFailure(
                    "the real MenuBarExtra(.window) host was not visible; "
                        + "no synthetic window fallback is permitted"
                )
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + retryInterval) {
                waitForPopover(output: output, attempt: attempt + 1)
            }
            return
        }

        window.displayIfNeeded()
        window.contentView?.layoutSubtreeIfNeeded()
        guard capture(contentView: window.contentView, to: output) else {
            reportFailure("failed to write the real MenuBarExtra host PNG")
            return
        }
        Darwin.exit(0)
    }

    private static func triggerPopoverIfPossible() {
        guard !hasTriggeredPopover else { return }
        // SwiftUI exposes no presentation action for MenuBarExtra. Its real
        // status-bar window remains in this process, so trigger its button
        // through public AppKit view APIs without creating another surface.
        let buttons = NSApp.windows
            .filter { $0.className.contains("NSStatusBarWindow") }
            .flatMap { window in
                window.contentView.map(statusBarButtons(in:)) ?? []
            }
        guard buttons.count == 1 else { return }
        hasTriggeredPopover = true
        buttons[0].performClick(nil)
    }

    private static func statusBarButtons(in view: NSView) -> [NSStatusBarButton] {
        var buttons = (view as? NSStatusBarButton).map { [$0] } ?? []
        for subview in view.subviews {
            buttons += statusBarButtons(in: subview)
        }
        return buttons
    }

    private static func waitForSettings(readyFile: URL?, attempt: Int) {
        guard let window = settingsWindow() else {
            guard attempt < settingsMaxAttempts else {
                reportFailure("the unique SpotiBind settings window was not visible")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + retryInterval) {
                waitForSettings(readyFile: readyFile, attempt: attempt + 1)
            }
            return
        }

        window.displayIfNeeded()
        window.contentView?.layoutSubtreeIfNeeded()
        if let readyFile {
            let contents = "pid=\(ProcessInfo.processInfo.processIdentifier)\nwindow=\(window.windowNumber)\n"
            do {
                try contents.write(to: readyFile, atomically: true, encoding: .utf8)
            } catch {
                reportFailure("failed to write settings readiness marker: \(error.localizedDescription)")
            }
        }
    }

    private static func menuBarExtraHost() -> NSWindow? {
        let candidates = NSApp.windows.filter { window in
            window.isVisible
                && window.windowNumber > 0
                && window.title.isEmpty
                && !window.styleMask.contains(.titled)
                && window.level == .popUpMenu
                && window.frame.width >= 360
                && window.frame.width <= 520
                && window.frame.height >= 280
                && window.frame.height <= 680
        }
        guard candidates.count == 1 else { return nil }
        return candidates[0]
    }

    private static func settingsWindow() -> NSWindow? {
        let candidates = NSApp.windows.filter { window in
            window.isVisible
                && window.windowNumber > 0
                && window.title == "SpotiBind"
                && window.identifier?.rawValue == "cc.ivanli.spotibind.settings-window"
                && window.styleMask.contains(.titled)
                && window.level == .normal
                && window.frame.width >= 600
                && window.frame.height >= 520
        }
        guard candidates.count == 1 else { return nil }
        return candidates[0]
    }

    private static func capture(contentView: NSView?, to url: URL) -> Bool {
        guard let contentView else { return false }
        let bounds = contentView.bounds.integral
        guard bounds.width > 4,
              bounds.height > 4,
              let representation = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
            return false
        }

        representation.size = bounds.size
        contentView.cacheDisplay(in: bounds, to: representation)
        guard let png = representation.representation(using: .png, properties: [:]),
              !png.isEmpty else {
            return false
        }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try png.write(to: url, options: [.atomic])
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attributes[.size] as? NSNumber else {
                return false
            }
            return size.intValue > 0
        } catch {
            return false
        }
    }

    private static func reportFailure(_ message: String) {
        FileHandle.standardError.write(Data("SpotiBind UI snapshot: \(message)\n".utf8))
        Darwin.exit(1)
    }
}
