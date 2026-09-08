import AppKit
import SwiftUI
import SpotiBindCore

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var isProblemBannerDismissed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if state.statusAction != nil, !isProblemBannerDismissed {
                    ProblemBanner(state: state) {
                        isProblemBannerDismissed = true
                    }
                }

                SettingsSection(title: "Forward media keys to") {
                    RoutingSelectorView(state: state, style: .settings)
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
                            Label("Accessibility", systemImage: "accessibility")
                            Spacer()
                            Button("Open Accessibility Settings", action: state.openAccessibilitySettings)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)

                        Divider()

                        Toggle("Launch at login", isOn: Binding(
                            get: { state.launchAtLogin },
                            set: { state.setLaunchAtLogin($0) }
                        ))
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
            .padding(28)
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
            )
            .frame(width: 30, height: 30)

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

            Button {
                state.choosePath(for: player)
            } label: {
                Label("Choose...", systemImage: "folder")
            }

            Button {
                state.resetPath(for: player)
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
