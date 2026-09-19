import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate, SettingsWindowPresenting {
    private let hostingController: NSHostingController<AnyView>
    private let contentMetrics = SettingsContentMetrics()
    private var isProblemBannerVisible = false
    private var isFitScheduled = false
    private var needsContentHeightFit = false
    private var hasBeenPresented = false
    private var hasCompletedInitialFit = false
    private var isApplyingContentFit = false
    private var expectedContentFitHeight: CGFloat?
    private let onClose: () -> Void

    init(state: AppState, onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
        let contentView = Self.windowContent(for: state) { [contentMetrics] height in
            contentMetrics.update(height)
        } onProblemBannerVisibilityChange: { [contentMetrics] isVisible in
            contentMetrics.updateProblemBannerVisibility(isVisible)
        }
        self.hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "SpotiBind"
        window.identifier = NSUserInterfaceItemIdentifier("cc.ivanli.spotibind.settings-window")
        window.titleVisibility = .visible
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 640))
        window.minSize = NSSize(width: 600, height: 520)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        contentMetrics.onHeightChange = { [weak self] _ in
            self?.contentHeightDidChange()
        }
        contentMetrics.onProblemBannerVisibilityChange = { [weak self] isVisible in
            self?.problemBannerVisibilityDidChange(isVisible)
        }
        isProblemBannerVisible = state.statusAction != nil
        window.center()
    }

    private static func windowContent(
        for state: AppState,
        onContentHeightChange: @escaping (CGFloat) -> Void,
        onProblemBannerVisibilityChange: @escaping (Bool) -> Void
    ) -> AnyView {
        let content = SettingsView(
            state: state,
            onContentHeightChange: onContentHeightChange,
            onProblemBannerVisibilityChange: onProblemBannerVisibilityChange
        )

        if #available(macOS 15.0, *) {
            return AnyView(
                content.containerBackground(.thinMaterial, for: .window)
            )
        }

        return AnyView(content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndActivate() {
        showWindow(nil)
        window?.deminiaturize(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        if !hasBeenPresented {
            hasBeenPresented = true
            scheduleContentHeightFit()
        } else if hasCompletedInitialFit {
            needsContentHeightFit = false
        } else if needsContentHeightFit {
            scheduleContentHeightFit()
        }
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

    func windowDidResize(_ notification: Notification) {
        guard !isApplyingContentFit, hasBeenPresented else { return }
        if let window,
           let expectedContentFitHeight,
           abs(window.contentLayoutRect.height - expectedContentFitHeight) <= 1 {
            self.expectedContentFitHeight = nil
            return
        }

        expectedContentFitHeight = nil
        hasCompletedInitialFit = true
        needsContentHeightFit = false
    }

    private func problemBannerVisibilityDidChange(_ isVisible: Bool) {
        guard isProblemBannerVisible != isVisible else { return }

        isProblemBannerVisible = isVisible
        if window?.isVisible == true {
            scheduleContentHeightFit()
        }
    }

    private func scheduleContentHeightFit() {
        needsContentHeightFit = true
        guard !isFitScheduled else { return }
        isFitScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isFitScheduled = false
            self.fitHeightToContent()
        }
    }

    private func fitHeightToContent() {
        guard needsContentHeightFit else { return }
        guard let window, window.isVisible else { return }

        window.contentView?.layoutSubtreeIfNeeded()
        let contentHeight = contentMetrics.height
        guard contentHeight.isFinite, contentHeight > 0 else { return }

        let maximumHeight = max(
            window.minSize.height,
            (window.screen?.visibleFrame.height ?? contentHeight) - 80
        )
        let targetHeight = min(
            max(ceil(contentHeight), window.minSize.height),
            maximumHeight
        )

        hasCompletedInitialFit = true
        needsContentHeightFit = false
        guard abs(window.contentLayoutRect.height - targetHeight) > 1 else { return }
        expectedContentFitHeight = targetHeight
        isApplyingContentFit = true
        window.setContentSize(
            NSSize(width: window.contentLayoutRect.width, height: targetHeight)
        )
        isApplyingContentFit = false
    }

    private func contentHeightDidChange() {
        if needsContentHeightFit {
            scheduleContentHeightFit()
        }
    }
}

@MainActor
private final class SettingsContentMetrics {
    var onHeightChange: ((CGFloat) -> Void)?
    var onProblemBannerVisibilityChange: ((Bool) -> Void)?
    private(set) var height: CGFloat = 0

    func update(_ height: CGFloat) {
        guard height.isFinite, abs(self.height - height) > 0.5 else { return }
        self.height = height
        onHeightChange?(height)
    }

    func updateProblemBannerVisibility(_ isVisible: Bool) {
        onProblemBannerVisibilityChange?(isVisible)
    }
}
