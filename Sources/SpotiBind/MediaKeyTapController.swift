@preconcurrency import AppKit
@preconcurrency import CoreGraphics
import SpotiBindCore

// IOKit NX_SUBTYPE_AUX_CONTROL_BUTTONS is the subtype used by media keys;
// NX_SUBTYPE_AUX_MOUSE_BUTTONS (7) must remain pass-through.
private let mediaKeySystemDefinedSubtype: Int16 = 8

@MainActor
protocol MediaKeyTapState: AnyObject {
    var readiness: ForwardingReadiness { get }
    var accessibilityTrusted: Bool { get }

    func dispatch(_ key: MediaKey)
    func setTapStatus(_ status: String)
}

extension AppState: MediaKeyTapState {}

@MainActor
final class MediaKeyTapController {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private weak var state: (any MediaKeyTapState)?
    private(set) var isTapQuarantined = false
    private var observedUntrustedSinceQuarantine = false

    func start(state: any MediaKeyTapState) {
        self.state = state
        installIfPossible()
    }

    func reconcile() {
        installIfPossible()
    }

    func stop() {
        removeEventTap()
    }

    private func removeEventTap() {
        let hadEventTap = eventTap != nil
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
        if hadEventTap {
            InputSafetyDiagnostics.tapRemoved()
        }
    }

    func handle(
        event: CGEvent,
        type: CGEventType
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout {
            quarantineTap(after: .timeout)
            return Unmanaged.passUnretained(event)
        }
        if type == .tapDisabledByUserInput {
            quarantineTap(after: .userInput)
            return Unmanaged.passUnretained(event)
        }

        let systemDefinedEventType = UInt32(NSEvent.EventType.systemDefined.rawValue)
        guard type.rawValue == systemDefinedEventType else {
            return Unmanaged.passUnretained(event)
        }

        guard let state else {
            return Unmanaged.passUnretained(event)
        }

        guard let systemDefinedEvent = NSEvent(cgEvent: event),
              systemDefinedEvent.subtype.rawValue == mediaKeySystemDefinedSubtype else {
            return Unmanaged.passUnretained(event)
        }
        let data1 = UInt32(truncatingIfNeeded: systemDefinedEvent.data1)
        guard SystemDefinedMediaKeyDecoder().decode(data1: data1) != nil else {
            return Unmanaged.passUnretained(event)
        }
        guard !state.readiness.isReady || state.accessibilityTrusted else {
            return Unmanaged.passUnretained(event)
        }

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
        guard let state else {
            removeEventTap()
            return
        }
        updateTapQuarantine(for: state)
        guard !isTapQuarantined, state.readiness.isReady else {
            removeEventTap()
            if !state.accessibilityTrusted {
                state.setTapStatus("Waiting for Accessibility")
            } else if isTapQuarantined {
                state.setTapStatus("Media key capture paused")
            }
            return
        }
        guard eventTap == nil else { return }

        let mask = CGEventMask(1) << CGEventMask(NSEvent.EventType.systemDefined.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyTapCallback,
            userInfo: userInfo
        ) else {
            state.setTapStatus("Media key capture unavailable")
            InputSafetyDiagnostics.tapUnavailable()
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            state.setTapStatus("Media key capture unavailable")
            InputSafetyDiagnostics.tapUnavailable()
            return
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        state.setTapStatus("Ready")
        InputSafetyDiagnostics.tapInstalled()
    }

    private func updateTapQuarantine(for state: any MediaKeyTapState) {
        guard isTapQuarantined else { return }
        guard !state.accessibilityTrusted else {
            guard observedUntrustedSinceQuarantine else { return }
            isTapQuarantined = false
            observedUntrustedSinceQuarantine = false
            InputSafetyDiagnostics.tapQuarantineReleased()
            return
        }
        observedUntrustedSinceQuarantine = true
    }

    private func quarantineTap(after reason: TapDisableReason) {
        isTapQuarantined = true
        if state?.accessibilityTrusted == false {
            observedUntrustedSinceQuarantine = true
        }
        removeEventTap()
        state?.setTapStatus("Media key capture paused")
        switch reason {
        case .timeout:
            InputSafetyDiagnostics.tapQuarantinedAfterTimeout()
        case .userInput:
            InputSafetyDiagnostics.tapQuarantinedAfterUserInput()
        }
    }
}

private enum TapDisableReason {
    case timeout
    case userInput
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
