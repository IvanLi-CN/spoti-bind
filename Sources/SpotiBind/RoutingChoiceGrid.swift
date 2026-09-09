import SwiftUI
import SpotiBindCore

enum RoutingChoiceGridDensity {
    case menu
    case settings

    var playerHeight: CGFloat {
        switch self {
        case .menu: 86
        case .settings: 108
        }
    }

    var utilityHeight: CGFloat {
        switch self {
        case .menu: 72
        case .settings: 80
        }
    }

    var playerSymbolSize: CGFloat {
        switch self {
        case .menu: 38
        case .settings: 42
        }
    }

    var utilitySymbolSize: CGFloat {
        switch self {
        case .menu: 30
        case .settings: 34
        }
    }

    var labelFont: Font {
        switch self {
        case .menu: .subheadline.weight(.medium)
        case .settings: .body.weight(.medium)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .menu: 16
        case .settings: 18
        }
    }
}

struct RoutingChoiceGrid: View {
    @ObservedObject var state: AppState
    let density: RoutingChoiceGridDensity

    private let playerModes: [PlayerMode] = [.fastpotify, .sonora, .spotifly]
    private let utilityModes: [PlayerMode] = [.automatic, .off]

    @ViewBuilder
    var body: some View {
        switch density {
        case .menu:
            menuGrid
        case .settings:
            settingsGrid
        }
    }

    private var menuGrid: some View {
        VStack(spacing: 0) {
            menuRow(playerModes, height: density.playerHeight)
            separator
            menuRow(utilityModes, height: density.utilityHeight)
        }
        .clipShape(RoundedRectangle(cornerRadius: density.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: density.cornerRadius, style: .continuous)
                .strokeBorder(.primary.opacity(0.16), lineWidth: 1)
        }
    }

    private var settingsGrid: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 22) {
                ForEach(playerModes, id: \.self) { mode in
                    settingsOption(for: mode)
                }
            }

            HStack(spacing: 22) {
                ForEach(utilityModes, id: \.self) { mode in
                    settingsOption(for: mode)
                }
                Color.clear
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(.primary.opacity(0.16))
            .frame(height: 1)
    }

    private func menuRow(_ modes: [PlayerMode], height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(modes.enumerated()), id: \.element) { index, mode in
                menuRoutingButton(for: mode)

                if index < modes.count - 1 {
                    Rectangle()
                        .fill(.primary.opacity(0.16))
                        .frame(width: 1)
                }
            }
        }
        .frame(height: height)
    }

    private func menuRoutingButton(for mode: PlayerMode) -> some View {
        MenuRoutingCell(state: state, mode: mode, density: density)
    }

    private func settingsOption(for mode: PlayerMode) -> some View {
        let isSelected = state.playerMode == mode
        let isPlayer = mode.supportedPlayer != nil

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                state.setPlayerMode(mode)
            }
        } label: {
            HStack(spacing: 13) {
                selectionIndicator(isSelected: isSelected)

                PlayerMarkView(
                    player: mode.supportedPlayer,
                    fallbackSymbol: mode.symbolName,
                    size: isPlayer ? density.playerSymbolSize : density.utilitySymbolSize
                )
                .frame(width: density.playerSymbolSize, height: density.playerSymbolSize)

                Text(mode.displayName)
                    .font(density.labelFont)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(mode.displayName)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .help("Forward media keys to \(mode.displayName)")
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(.primary.opacity(0.42), lineWidth: 1.5)

            if isSelected {
                Circle()
                    .fill(.primary.opacity(0.30))

                Circle()
                    .fill(.primary)
                    .padding(9)
            }
        }
        .frame(width: 28, height: 28)
    }
}

private struct MenuRoutingCell: View {
    @ObservedObject var state: AppState
    let mode: PlayerMode
    let density: RoutingChoiceGridDensity

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isSelected: Bool {
        state.playerMode == mode
    }

    private var isPlayer: Bool {
        mode.supportedPlayer != nil
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    state.setPlayerMode(mode)
                }
            } label: {
                VStack(spacing: isPlayer ? 8 : 7) {
                    PlayerMarkView(
                        player: mode.supportedPlayer,
                        fallbackSymbol: mode.symbolName,
                        size: isPlayer ? density.playerSymbolSize : density.utilitySymbolSize
                    )

                    Text(mode.displayName)
                        .font(density.labelFont)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(
                MenuRoutingCellButtonStyle(
                    isSelected: isSelected,
                    isHovered: isHovered,
                    reduceMotion: reduceMotion
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityLabel(mode.displayName)
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .help("Forward media keys to \(mode.displayName)")

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(12)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHover { isHovered = $0 }
    }
}

private struct MenuRoutingCellButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isHovered: Bool
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        let backgroundOpacity: Double
        if isSelected {
            backgroundOpacity = configuration.isPressed ? 0.20 : 0.14
        } else if isHovered {
            backgroundOpacity = configuration.isPressed ? 0.12 : 0.08
        } else {
            backgroundOpacity = configuration.isPressed ? 0.06 : 0
        }

        return configuration.label
            .background(Color.primary.opacity(backgroundOpacity))
            .overlay {
                if isSelected {
                    Rectangle()
                        .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.14),
                value: isSelected
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: isHovered
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.10),
                value: configuration.isPressed
            )
    }
}
