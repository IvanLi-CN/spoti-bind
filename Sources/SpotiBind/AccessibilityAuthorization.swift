import ApplicationServices
import AppKit
import Foundation

@MainActor
protocol AccessibilityTrustChecking {
    func check(prompt: Bool) -> Bool
}

@MainActor
struct SystemAccessibilityTrustChecker: AccessibilityTrustChecking {
    func check(prompt: Bool) -> Bool {
        let options: CFDictionary? = prompt
            ? ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            : nil
        return AXIsProcessTrustedWithOptions(options)
    }
}

@MainActor
protocol AccessibilityPollingHandle: AnyObject {
    func cancel()
}

@MainActor
protocol AccessibilityPollingScheduling {
    func scheduleRepeating(
        every interval: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) -> any AccessibilityPollingHandle
}

@MainActor
private final class TimerAccessibilityPollingHandle: AccessibilityPollingHandle {
    private var timer: Timer?

    init(timer: Timer) {
        self.timer = timer
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }
}

@MainActor
struct MainRunLoopAccessibilityPollingScheduler: AccessibilityPollingScheduling {
    func scheduleRepeating(
        every interval: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) -> any AccessibilityPollingHandle {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                action()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        return TimerAccessibilityPollingHandle(timer: timer)
    }
}

@MainActor
protocol AccessibilitySettingsOpening {
    func open(_ url: URL) -> Bool
}

@MainActor
struct SystemAccessibilitySettingsOpener: AccessibilitySettingsOpening {
    func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}
