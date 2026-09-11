import AppKit
import SwiftUI
import SpotiBindCore

@main
struct SpotiBindApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var applicationDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView(state: applicationDelegate.state)
        } label: {
            StatusBarIconView()
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuPanelView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 18) {
            TransportControlsView(state: state)

            StatusSummaryView(state: state)

            VStack(alignment: .leading, spacing: 10) {
                Text("Forward media keys to")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                RoutingChoiceGrid(state: state, density: .menu)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            MenuFooterView(state: state)
        }
        .padding(18)
        .frame(width: 372)
    }
}

private struct TransportControlsView: View {
    @ObservedObject var state: AppState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var controlsUnavailable: Bool {
        state.isDispatching || (state.accessibilityTrusted && !state.readiness.isReady)
    }

    var body: some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            nativeTransportBar
        } else {
            fallbackTransportBar
        }
    }

    @available(macOS 26.0, *)
    private var nativeTransportBar: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return HStack(spacing: 0) {
            nativeMediaButton(
                "backward.end.fill",
                label: "Previous",
                key: .previous
            )

            transportDivider

            nativeMediaButton(
                "playpause.fill",
                label: "Play or Pause",
                key: .playPause
            )

            transportDivider

            nativeMediaButton(
                "forward.end.fill",
                label: "Next",
                key: .next
            )
        }
        .frame(height: 54)
        .clipShape(shape)
        .glassEffect(.regular, in: shape)
    }

    private var fallbackTransportBar: some View {
        HStack(alignment: .center, spacing: 10) {
            fallbackMediaButton(
                "backward.end.fill",
                label: "Previous",
                key: .previous
            )
            fallbackMediaButton(
                "playpause.fill",
                label: "Play or Pause",
                key: .playPause
            )
            fallbackMediaButton(
                "forward.end.fill",
                label: "Next",
                key: .next
            )
        }
    }

    @available(macOS 26.0, *)
    private func nativeMediaButton(
        _ systemName: String,
        label: String,
        key: MediaKey
    ) -> some View {
        NativeTransportSegment(
            systemName: systemName,
            label: label,
            isDisabled: controlsUnavailable
        ) {
            state.dispatchFromMenu(key)
        }
    }

    private var transportDivider: some View {
        Rectangle()
            .fill(.primary.opacity(0.14))
            .frame(width: 1)
            .padding(.vertical, 9)
    }

    private func fallbackMediaButton(
        _ systemName: String,
        label: String,
        key: MediaKey
    ) -> some View {
        Button {
            state.dispatchFromMenu(key)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 23, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
        }
        .disabled(controlsUnavailable)
        .accessibilityLabel(label)
        .help(label)
        .buttonStyle(FallbackTransportButtonStyle())
    }
}

@available(macOS 26.0, *)
private struct NativeTransportSegment: View {
    let systemName: String
    let label: String
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 23, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(label)
        .help(label)
        .background {
            if isHovered && !isDisabled {
                Color.primary.opacity(0.08)
            }
        }
        .onHover { isHovered = $0 }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.12),
            value: isHovered
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct StatusSummaryView: View {
    @ObservedObject var state: AppState

    var body: some View {
        if state.statusAction != nil {
            actionableStatus
        } else {
            informationalStatus
        }
    }

    private var informationalStatus: some View {
        HStack(spacing: 8) {
            statusMark
            Text(displayTitle)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionableStatus: some View {
        HStack(alignment: .center, spacing: 10) {
            statusMark
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(state.statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle = state.statusActionTitle {
                Button(compactActionTitle, action: state.performStatusAction)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel(actionTitle)
                    .accessibilityHint("Opens the setting needed to resolve the current issue.")
                    .help(actionTitle)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private var compactActionTitle: String {
        switch state.statusAction {
        case .accessibility: "Open"
        case .settings: "Review"
        case nil: ""
        }
    }

    private var statusMark: some View {
        Group {
            if state.playerMode == .off {
                Image(systemName: "power")
                    .foregroundStyle(.primary)
            } else if state.statusAction != nil {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else {
                HStack(spacing: 2) {
                    Image(systemName: "waveform")
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.primary)
            }
        }
        .font(.system(size: 16, weight: .semibold))
    }

    private var displayTitle: String {
        guard state.statusAction == nil,
              state.statusTitle.hasPrefix("Forwarding to ") else {
            return state.statusTitle
        }
        return "Media keys routed to \(state.statusTitle.dropFirst("Forwarding to ".count))"
    }
}

private struct MenuFooterView: View {
    @ObservedObject var state: AppState

    var body: some View {
        HStack(spacing: 12) {
            Button {
                state.openAdvancedSettings()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                    Text("Advanced Settings")
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 12)

            Button("About") {
                NSApplication.shared.orderFrontStandardAboutPanel(nil)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 18)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .font(.subheadline.weight(.medium))
        .frame(minHeight: 28)
    }
}

private struct FallbackTransportButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        configuration.label
            .background(
                Color.primary.opacity(0.06),
                in: shape
            )
            .foregroundStyle(.primary)
            .overlay {
                shape.strokeBorder(.primary.opacity(0.12), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

struct PlayerMarkView: View {
    let player: SupportedPlayer?
    let fallbackSymbol: String?
    let size: CGFloat

    init(
        player: SupportedPlayer?,
        fallbackSymbol: String? = nil,
        size: CGFloat = 28
    ) {
        self.player = player
        self.fallbackSymbol = fallbackSymbol
        self.size = size
    }

    var body: some View {
        Image(systemName: fallbackSymbol ?? defaultSymbol)
            .font(.system(size: size, weight: .medium))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
    }

    private var defaultSymbol: String {
        switch player {
        case .fastpotify: "play.circle.fill"
        case .sonora: "waveform"
        case .spotifly: "paperplane"
        case nil: "circle"
        }
    }
}

extension PlayerMode {
    var supportedPlayer: SupportedPlayer? {
        switch self {
        case .fastpotify: .fastpotify
        case .sonora: .sonora
        case .spotifly: .spotifly
        case .automatic, .off: nil
        }
    }

    var symbolName: String {
        switch self {
        case .fastpotify: "play.circle.fill"
        case .sonora: "waveform"
        case .spotifly: "paperplane"
        case .automatic: "wand.and.stars"
        case .off: "nosign"
        }
    }
}
