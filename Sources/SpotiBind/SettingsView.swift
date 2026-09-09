import AppKit
import SwiftUI
import SpotiBindCore

struct SettingsView: View {
    @ObservedObject var state: AppState
    let onContentHeightChange: (CGFloat) -> Void
    let onProblemBannerVisibilityChange: (Bool) -> Void
    @State private var isProblemBannerDismissed = false

    private var isProblemBannerVisible: Bool {
        state.statusAction != nil && !isProblemBannerDismissed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if isProblemBannerVisible {
                    ProblemBanner(state: state) {
                        isProblemBannerDismissed = true
                        onProblemBannerVisibilityChange(false)
                    }
                }

                SettingsSection(title: "Forward media keys to") {
                    RoutingChoiceGrid(state: state, density: .settings)
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
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.primary.opacity(0.16), lineWidth: 1)
                    }
                }

                SettingsSection(title: "System") {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Accessibility")
                            Spacer()
                            Button("Open Accessibility Settings", action: state.openAccessibilitySettings)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
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
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.primary.opacity(0.16), lineWidth: 1)
                    }
                }
            }
            .padding(32)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SettingsContentHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onPreferenceChange(SettingsContentHeightPreferenceKey.self) {
            onContentHeightChange($0)
        }
        .onChange(of: state.statusTitle) { _ in
            isProblemBannerDismissed = false
            onProblemBannerVisibilityChange(state.statusAction != nil)
        }
        .onChange(of: state.statusAction) { _ in
            isProblemBannerDismissed = false
            onProblemBannerVisibilityChange(state.statusAction != nil)
        }
    }
}

private struct SettingsContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.orange.opacity(0.55), lineWidth: 1)
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
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Reset") {
                state.resetPath(for: player)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
