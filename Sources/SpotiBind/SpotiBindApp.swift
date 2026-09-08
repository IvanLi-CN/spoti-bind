import AppKit
import SwiftUI
import SpotiBindCore

@main
struct SpotiBindApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var applicationDelegate

    var body: some Scene {
        MenuBarExtra("SpotiBind", systemImage: "waveform.and.arrow.forward") {
            MenuPanelView(state: applicationDelegate.state)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuPanelView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            TransportControlsView(state: state)

            Divider()
                .padding(.vertical, 14)

            StatusSummaryView(state: state)

            RoutingSelectorView(state: state, style: .menu)
                .padding(.top, 12)

            Divider()
                .padding(.vertical, 14)

            MenuFooterView(state: state)
        }
        .padding(16)
        .frame(width: 390)
        .background(.regularMaterial)
    }
}

private struct TransportControlsView: View {
    @ObservedObject var state: AppState

    private var controlsUnavailable: Bool {
        state.isDispatching || (state.accessibilityTrusted && !state.readiness.isReady)
    }

    var body: some View {
        HStack(spacing: 8) {
            mediaButton(
                "backward.end.fill",
                label: "Previous",
                key: .previous
            )
            mediaButton(
                "playpause.fill",
                label: "Play or Pause",
                key: .playPause,
                isPrimary: true
            )
            mediaButton(
                "forward.end.fill",
                label: "Next",
                key: .next
            )
        }
    }

    private func mediaButton(
        _ systemName: String,
        label: String,
        key: MediaKey,
        isPrimary: Bool = false
    ) -> some View {
        Button {
            state.dispatchFromMenu(key)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: isPrimary ? 24 : 20, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
        }
        .buttonStyle(PanelButtonStyle(isPrimary: isPrimary))
        .disabled(controlsUnavailable)
        .accessibilityLabel(label)
        .help(label)
    }
}

private struct StatusSummaryView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: statusSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(statusColor)
                Text(state.statusTitle)
                    .font(.headline)
                    .lineLimit(1)
            }

            Text(state.statusDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)

            if let actionTitle = state.statusActionTitle {
                Button(actionTitle, action: state.performStatusAction)
                    .buttonStyle(.link)
                    .font(.caption.weight(.semibold))
                    .accessibilityHint("Opens the setting needed to resolve the current issue.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusSymbol: String {
        if state.playerMode == .off { return "power" }
        if state.statusAction != nil { return "exclamationmark.triangle" }
        return "waveform.and.arrow.forward"
    }

    private var statusColor: Color {
        if state.statusAction != nil { return .orange }
        return .accentColor
    }
}

struct RoutingSelectorView: View {
    enum Style {
        case menu
        case settings
    }

    @ObservedObject var state: AppState
    let style: Style

    private let firstRow: [PlayerMode] = [.fastpotify, .sonora, .spotifly]
    private let secondRow: [PlayerMode] = [.automatic, .off]

    var body: some View {
        VStack(spacing: 0) {
            row(firstRow)
            Divider()
            row(secondRow)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
        }
    }

    private func row(_ modes: [PlayerMode]) -> some View {
        HStack(spacing: 0) {
            ForEach(modes, id: \.self) { mode in
                routingButton(for: mode)
                if mode != modes.last {
                    Divider()
                }
            }
        }
    }

    private func routingButton(for mode: PlayerMode) -> some View {
        Button {
            state.setPlayerMode(mode)
        } label: {
            VStack(spacing: style == .menu ? 7 : 5) {
                ZStack(alignment: .topTrailing) {
                    PlayerMarkView(
                        player: mode.supportedPlayer,
                        fallbackSymbol: mode.symbolName
                    )
                    .frame(width: style == .menu ? 28 : 24, height: style == .menu ? 28 : 24)

                    if state.playerMode == mode {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                            .background(.regularMaterial, in: Circle())
                            .offset(x: style == .menu ? 9 : 7, y: -6)
                    }
                }

                Text(mode.displayName)
                    .font(style == .menu ? .caption : .subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: style == .menu ? 88 : 70)
            .contentShape(Rectangle())
        }
        .buttonStyle(RoutingCellButtonStyle(isSelected: state.playerMode == mode))
        .accessibilityAddTraits(state.playerMode == mode ? .isSelected : [])
        .accessibilityLabel(mode.displayName)
        .help("Forward media keys to \(mode.displayName)")
    }
}

private struct MenuFooterView: View {
    @ObservedObject var state: AppState

    var body: some View {
        HStack(spacing: 12) {
            Button {
                state.openAdvancedSettings()
            } label: {
                Label("Advanced Settings", systemImage: "gearshape")
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
        .font(.caption.weight(.medium))
    }
}

private struct PanelButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                (isPrimary ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06)),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.primary.opacity(configuration.isPressed ? 0.3 : 0.12), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct RoutingCellButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                isSelected ? Color.primary.opacity(0.14) : Color.clear,
                in: Rectangle()
            )
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PlayerMarkView: View {
    let player: SupportedPlayer?
    let fallbackSymbol: String?

    init(
        player: SupportedPlayer?,
        fallbackSymbol: String? = nil
    ) {
        self.player = player
        self.fallbackSymbol = fallbackSymbol
    }

    var body: some View {
        Image(systemName: fallbackSymbol ?? defaultSymbol)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.primary)
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

private extension PlayerMode {
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
