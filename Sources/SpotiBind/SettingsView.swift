import AppKit
import SwiftUI
import SpotiBindCore

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var isProblemBannerDismissed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if state.statusAction != nil, !isProblemBannerDismissed {
                    ProblemBanner(state: state) {
                        isProblemBannerDismissed = true
                    }
                }

                SettingsSection(title: "Forward media keys to") {
                    SettingsRoutingSelectorView(state: state)
                }

                SettingsSection(title: "Player locations") {
                    VStack(spacing: 0) {
                        ForEach(Array(SupportedPlayer.allCases.enumerated()), id: \.element) { index, player in
                            PlayerPathRowView(state: state, player: player)
                            if index < SupportedPlayer.allCases.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                    }
                }

                SettingsSection(title: "System") {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Accessibility")
                            Spacer()
                            Button("Open Accessibility Settings", action: state.openAccessibilitySettings)
                                .buttonStyle(SettingsSecondaryButtonStyle())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)

                        Divider()

                        HStack {
                            Text("Launch at login")
                            Spacer()
                            Toggle("Launch at login", isOn: Binding(
                                get: { state.launchAtLogin },
                                set: { state.setLaunchAtLogin($0) }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                    }
                }
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .onChange(of: state.statusTitle) { _ in
            isProblemBannerDismissed = false
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.title3.weight(.semibold))
            content()
        }
    }
}

private struct SettingsRoutingSelectorView: View {
    @ObservedObject var state: AppState

    private let firstRow: [PlayerMode] = [.fastpotify, .sonora, .spotifly]
    private let secondRow: [PlayerMode] = [.automatic, .off]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            optionRow(firstRow)
            optionRow(secondRow)
        }
        .padding(.vertical, 6)
    }

    private func optionRow(_ modes: [PlayerMode]) -> some View {
        HStack(spacing: 20) {
            ForEach(modes, id: \.self) { mode in
                routingOption(for: mode)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func routingOption(for mode: PlayerMode) -> some View {
        let isSelected = state.playerMode == mode
        let isPlayer = mode.supportedPlayer != nil

        return Button {
            state.setPlayerMode(mode)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                PlayerMarkView(
                    player: mode.supportedPlayer,
                    fallbackSymbol: mode.symbolName,
                    size: isPlayer ? 34 : 28
                )

                Text(mode.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsRoutingOptionButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(mode.displayName)
        .help("Forward media keys to \(mode.displayName)")
    }
}

private struct SettingsRoutingOptionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SettingsSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .frame(minHeight: 28)
            .background(Color.primary.opacity(configuration.isPressed ? 0.10 : 0.04), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(.primary.opacity(configuration.isPressed ? 0.30 : 0.18), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ProblemBanner: View {
    @ObservedObject var state: AppState
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(state.statusTitle)
                    .font(.headline)
                Text(state.statusDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle = state.statusActionTitle {
                    Button(actionTitle, action: state.performStatusAction)
                        .buttonStyle(.link)
                        .font(.subheadline.weight(.semibold))
                }
            }
            Spacer(minLength: 8)
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss warning")
        }
        .padding(14)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.orange.opacity(0.24), lineWidth: 1)
        }
    }
}

private struct PlayerPathRowView: View {
    @ObservedObject var state: AppState
    let player: SupportedPlayer

    var body: some View {
        HStack(spacing: 12) {
            PlayerMarkView(
                player: player,
                size: 28
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(player.displayName)
                    .font(.headline)
                Text(state.pathDisplay(for: player))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let problem = state.pathProblems[player] {
                    Text(problem)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            Button("Choose…") {
                state.choosePath(for: player)
            }
            .buttonStyle(SettingsSecondaryButtonStyle())

            Button("Reset") {
                state.resetPath(for: player)
            }
            .buttonStyle(SettingsSecondaryButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
