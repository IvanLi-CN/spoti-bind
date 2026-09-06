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

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
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

        guard type.rawValue == UInt32(NSEvent.EventType.systemDefined.rawValue),
              let state,
              let systemEvent = NSEvent(cgEvent: event)
        else {
            return Unmanaged.passUnretained(event)
        }

        let data1 = UInt32(truncatingIfNeeded: systemEvent.data1)
        guard let decoded = SystemDefinedMediaKeyDecoder().decode(data1: data1) else {
            return Unmanaged.passUnretained(event)
        }

        switch RoutingPolicy().decision(for: decoded, readiness: state.readiness) {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .consume:
            return nil
        case .dispatch(let key):
            state.dispatch(key)
            return nil
        }
    }

    private func installIfPossible() {
        guard eventTap == nil else { return }
        guard state?.accessibilityTrusted == true else {
            state?.setTapStatus("Waiting for Accessibility")
            return
        }

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
            state?.setTapStatus("Media key capture unavailable")
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            state?.setTapStatus("Media key capture unavailable")
            return
        }

        eventTap = tap
        runLoopSource = source
        failureTracker.reset()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        state?.setTapStatus("Ready")
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
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let controller = Unmanaged<MediaKeyTapController>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    return MainActor.assumeIsolated {
        controller.handle(event: event, type: type)
    }
}
