import AppKit

@MainActor
final class ApplicationPresentationController {
    typealias PolicySetter = (NSApplication.ActivationPolicy) -> Bool

    private let isUIDemo: Bool
    private let setPolicy: PolicySetter
    private(set) var currentPolicy: NSApplication.ActivationPolicy?

    init(
        isUIDemo: Bool,
        setPolicy: @escaping PolicySetter = { NSApplication.shared.setActivationPolicy($0) }
    ) {
        self.isUIDemo = isUIDemo
        self.setPolicy = setPolicy
    }

    func configureForLaunch() {
        apply(isUIDemo ? .regular : .accessory)
    }

    func settingsDidOpen() {
        guard !isUIDemo else { return }
        apply(.regular)
    }

    func settingsDidClose() {
        guard !isUIDemo else { return }
        apply(.accessory)
    }

    private func apply(_ policy: NSApplication.ActivationPolicy) {
        guard setPolicy(policy) else {
            NSLog("SpotiBind could not apply activation policy %@", String(describing: policy))
            return
        }
        currentPolicy = policy
    }
}
