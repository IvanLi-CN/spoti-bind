@preconcurrency import AppKit
@preconcurrency import CoreGraphics
import SpotiBindCore

@MainActor
final class MediaKeyTapController {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?
    private weak var state: AppState?
    private var failureTracker = TapFailureTracker()

    func start(state: AppState) {
        self.state = state
        installIfPossible()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.installIfPossible()
            }
        }
    }

    func reconcile() {
        installIfPossible()
    }

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        removeEventTap()
    }

    private func removeEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
    }

    fileprivate func handle(
        event: CGEvent,
        type: CGEventType
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            handleDisabledTap()
            return Unmanaged.passUnretained(event)
        }

        guard let state else {
            return Unmanaged.passUnretained(event)
        }

        let systemDefinedEventType = UInt32(NSEvent.EventType.systemDefined.rawValue)
        let data1 = type.rawValue == systemDefinedEventType
            ? UInt32(truncatingIfNeeded: NSEvent(cgEvent: event)?.data1 ?? 0)
            : nil
        switch MediaKeyEventRouter().decision(
            eventType: type.rawValue,
            systemDefinedEventType: systemDefinedEventType,
            data1: data1,
            readiness: state.readiness
        ) {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .route(.passThrough):
            return Unmanaged.passUnretained(event)
        case .route(.consume):
            return nil
        case .route(.dispatch(let key)):
            state.dispatch(key)
            return nil
        }
    }

    private func installIfPossible() {
        guard let state, state.readiness.isReady else {
            removeEventTap()
            if state?.accessibilityTrusted == false {
                state?.setTapStatus("Waiting for Accessibility")
            }
            return
        }
        guard eventTap == nil else { return }

        let mask = CGEventMask(1) << CGEventMask(NSEvent.EventType.systemDefined.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyTapCallback,
            userInfo: userInfo
        ) else {
            state.setTapStatus("Media key capture unavailable")
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            state.setTapStatus("Media key capture unavailable")
            return
        }

        eventTap = tap
        runLoopSource = source
        failureTracker.reset()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        state.setTapStatus("Ready")
    }

    private func handleDisabledTap() {
        guard let eventTap else {
            state?.setPlayerMode(.off)
            state?.setTapStatus("Media key capture disabled after repeated failures")
            return
        }

        switch failureTracker.recordFailure(at: Date()) {
        case .disableForwarding:
            state?.setPlayerMode(.off)
            state?.setTapStatus("Media key capture disabled after repeated failures")
        case .retryOnce:
            CGEvent.tapEnable(tap: eventTap, enable: true)
            state?.setTapStatus("Media key capture restarted")
        }
    }
}

private func mediaKeyTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let systemDefinedEventType = UInt32(NSEvent.EventType.systemDefined.rawValue)
    let isTapNotification = type == .tapDisabledByTimeout || type == .tapDisabledByUserInput
    guard isTapNotification || type.rawValue == systemDefinedEventType else {
        // The tap mask is intentionally narrow, but keep this guard at the C
        // callback boundary so a mouse or keyboard event can never reach the
        // actor-isolated handler even if the system sends an unexpected type.
        return Unmanaged.passUnretained(event)
    }
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let controller = Unmanaged<MediaKeyTapController>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    guard Thread.isMainThread else {
        return Unmanaged.passUnretained(event)
    }
    return MainActor.assumeIsolated {
        controller.handle(event: event, type: type)
    }
}
