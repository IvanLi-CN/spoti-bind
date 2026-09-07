import SwiftUI
import SpotiBindCore

@main
struct SpotiBindApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var applicationDelegate

    var body: some Scene {
        MenuBarExtra("SpotiBind", systemImage: "music.note") {
            SpotiBindMenu(state: applicationDelegate.state)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct SpotiBindMenu: View {
    @ObservedObject var state: AppState

    var body: some View {
        Text(state.statusTitle)
        Text(state.statusDetail)
            .font(.caption)
            .foregroundStyle(.secondary)

        Divider()

        Picker(
            "Forward media keys to",
            selection: Binding(
                get: { state.playerMode },
                set: { state.setPlayerMode($0) }
            )
        ) {
            ForEach(PlayerMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }

        Button("Open Accessibility Settings", action: state.openAccessibilitySettings)

        Toggle("Launch at login", isOn: $state.launchAtLogin)
            .onChange(of: state.launchAtLogin) { newValue in
                state.setLaunchAtLogin(newValue)
            }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
