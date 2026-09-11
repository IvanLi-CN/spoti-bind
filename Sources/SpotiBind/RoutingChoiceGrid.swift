import AppKit
import SwiftUI
import SpotiBindCore

private let routingSeparatorColor = Color(nsColor: .separatorColor)

enum RoutingChoiceGridDensity {
    case menu
    case settings

    var playerHeight: CGFloat {
        switch self {
        case .menu: 86
        case .settings: 108
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

    private let gridRows: [[PlayerMode]] = [
        [.automatic, .spotify, .sonora],
        [.off, .fastpotify, .spotifly]
    ]

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
            ForEach(Array(gridRows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    separator
                }
                menuRow(row, height: density.playerHeight)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: density.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: density.cornerRadius, style: .continuous)
                .strokeBorder(routingSeparatorColor, lineWidth: 1)
        }
    }

    private var settingsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 22),
                    count: 3
                ),
                spacing: 16
            ) {
                ForEach(gridRows.flatMap { $0 }, id: \.self) { mode in
                    settingsOption(for: mode)
                }
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(routingSeparatorColor)
            .frame(height: 1)
    }

    private func menuRow(_ modes: [PlayerMode], height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(modes.enumerated()), id: \.element) { index, mode in
                menuRoutingButton(for: mode)

                if index < modes.count - 1 {
                    Rectangle()
                        .fill(routingSeparatorColor)
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
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.primary.opacity(0.055))
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                }
            }
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
                .strokeBorder(
                    Color.primary.opacity(isSelected ? 0.65 : 0.50),
                    lineWidth: 1.5
                )

            if isSelected {
                Circle()
                    .fill(.primary.opacity(0.10))

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
    @Environment(\.colorScheme) private var colorScheme

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
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(
                MenuRoutingCellButtonStyle(
                    isSelected: isSelected,
                    isHovered: isHovered,
                    reduceMotion: reduceMotion,
                    colorScheme: colorScheme
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityLabel(mode.displayName)
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .help("Forward media keys to \(mode.displayName)")

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                    .frame(width: 20, height: 20)
                    .background(.primary, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(.background.opacity(0.45), lineWidth: 1)
                    }
                    .padding(10)
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
    let colorScheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        return configuration.label
            .background {
                if isSelected {
                    Rectangle()
                        .fill(Color.white.opacity(
                            colorScheme == .dark
                                ? (configuration.isPressed ? 0.08 : 0.14)
                                : (configuration.isPressed ? 0.28 : 0.36)
                        ))
                } else if isHovered {
                    Rectangle()
                        .fill(.primary.opacity(
                            configuration.isPressed ? 0.07 : 0.035
                        ))
                } else if configuration.isPressed {
                    Rectangle()
                        .fill(.primary.opacity(0.045))
                }
            }
            .overlay {
                if isSelected {
                    Rectangle()
                        .strokeBorder(routingSeparatorColor, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.94 : 1)
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
