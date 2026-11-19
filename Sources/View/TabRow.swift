// ABOUTME: One tab in the sidebar: color bar, editable name, git and directory lines, and a minimap
// ABOUTME: or, when compact, a Claude status icon. Also maps TabColor cases to the ANSI palette.
import SwiftUI

struct TabRow: View {
    let tab: Tab
    let isActive: Bool
    var repoColorOverrides: [String: PaneTint] = [:]
    @Binding var editingTabID: UUID?
    var jumpLabels: [UUID: String] = [:]
    var onPaneTap: ((UUID) -> Void)?
    /// Drops the minimap for a single Claude status icon beside the name.
    var compact = false

    @State private var editName = ""
    @FocusState private var textFieldFocused: Bool

    private var isEditing: Bool {
        editingTabID == tab.id
    }

    private var info: TabInfo {
        tab.tabInfo
    }

    var body: some View {
        HStack(spacing: 0) {
            // Color indicator bar
            Rectangle()
                .fill(colorBarColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: compact ? 1 : 3) {
                HStack(spacing: 4) {
                    nameView
                    if compact {
                        Spacer(minLength: 4)
                        compactAccessory
                    }
                }
                detailLines

                if !compact {
                    MinimapView(
                        minimap: info.minimap,
                        tabColor: tabColor,
                        tabColorOverride: tab.colorOverride,
                        isActiveTab: isActive,
                        jumpLabels: jumpLabels,
                        surfaceDirectories: tab.effectiveSurfaceDirectories,
                        repoColorOverrides: repoColorOverrides,
                        surfaceColorOverrides: tab.surfaceColorOverrides,
                        onPaneTap: onPaneTap
                    )
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, compact ? 4 : 6)
            .padding(.bottom, compact ? 5 : 10)

            Spacer(minLength: 0)
        }
        .opacity(isActive ? 1.0 : 0.9)
        .background(
            isActive
                ? Rectangle().fill(activeBackgroundGradient).padding(.trailing, -24)
                : nil
        )
        .overlay {
            if isActive {
                // Extend borders past the row's right edge to meet the
                // window divider line, using negative trailing padding
                VStack {
                    Rectangle().fill(accentGradient).frame(height: 4)
                    Spacer()
                    Rectangle().fill(accentGradient).frame(height: 4)
                }
                .padding(.trailing, -24)
            }
        }
    }

    private var nameFontSize: CGFloat { compact ? 17 : 21 }
    private var detailFontSize: CGFloat { compact ? 13 : 16 }

    /// The tab name, editable on double-tap.
    @ViewBuilder
    private var nameView: some View {
        if isEditing {
            TextField("Tab name", text: $editName, onCommit: {
                tab.name = editName
                editingTabID = nil
            })
            .textFieldStyle(.plain)
            .font(.system(size: nameFontSize, weight: .bold))
            .focused($textFieldFocused)
            .onAppear {
                editName = tab.name
                // Delay focus slightly so the view is in the hierarchy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textFieldFocused = true
                }
            }
            .onExitCommand { editingTabID = nil }
        } else {
            Text(info.displayName)
                .font(.system(size: nameFontSize, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)
                .onTapGesture(count: 2) {
                    editingTabID = tab.id
                }
        }
    }

    /// The git line, or the directory when there is no git info.
    @ViewBuilder
    private var detailLines: some View {
        if let git = info.gitInfo {
            HStack(spacing: 4) {
                Text(git.repoName)
                    .foregroundStyle(.secondary)
                if let branch = git.branchName {
                    Text(branch)
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.system(size: detailFontSize))
            .lineLimit(1)
        } else if let dir = info.directoryName {
            Text(dir)
                .font(.system(size: detailFontSize))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    /// What a compact row shows where the minimap would be: the tab's Claude
    /// status, or -- while jump mode is labelling panes -- the labels of its
    /// panes, which would otherwise have nowhere to be tapped from.
    @ViewBuilder
    private var compactAccessory: some View {
        let labelled = info.minimap.panes.compactMap { pane in
            jumpLabels[pane.leafID].map { (leafID: pane.leafID, label: $0) }
        }
        if !labelled.isEmpty {
            HStack(spacing: 2) {
                ForEach(labelled, id: \.leafID) { entry in
                    JumpBadge(label: entry.label, color: tabColor, large: false)
                        .onTapGesture { onPaneTap?(entry.leafID) }
                }
            }
        } else if let activity = info.activity {
            ActivityIndicatorView(state: activity, fontSize: 16)
        }
    }

    private var paneTint: PaneTint {
        tab.effectivePaneTint(overrides: repoColorOverrides)
    }

    private var tabColor: Color {
        paneTint.primary.swiftUIColor
    }

    /// The leading edge color of the gradient. Used for the left-edge bar so it
    /// lines up visually with the leading stop of the row's gradient.
    private var leadingEdgeColor: Color {
        paneTint.leading.swiftUIColor
    }

    private var accentGradient: LinearGradient { paneTint.gradient() }

    private var colorBarColor: Color {
        isActive ? leadingEdgeColor : leadingEdgeColor.opacity(0.3)
    }

    private var activeBackgroundGradient: LinearGradient {
        paneTint.gradient(opacity: 0.15)
    }
}

extension TabColor {
    /// Tab palette order: maps each case to a position in the 14-color
    /// ANSI palette extracted from the Ghostty config.
    static let orderedCases: [TabColor] = [
        .blue, .red, .green, .yellow, .magenta, .cyan, .neutral,
        .brightBlue, .brightRed, .brightGreen, .brightYellow,
        .brightMagenta, .brightCyan, .neutralBright
    ]

    /// Color from the user's Ghostty theme palette, with Catppuccin fallback.
    var swiftUIColor: Color {
        if self == .gray { return .gray }
        if let idx = Self.orderedCases.firstIndex(of: self),
           let appDel = AppDelegate.shared(),
           idx < appDel.tabPalette.count {
            return Color(nsColor: appDel.tabPalette[idx])
        }
        return catppuccinFallback
    }

    /// Catppuccin Mocha fallback for when the Ghostty palette isn't available
    /// (tests, or before config loads).
    private var catppuccinFallback: Color {
        let hex = catppuccinHex
        return Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    // Catppuccin Mocha ANSI colors in palette order
    private var catppuccinHex: UInt {
        switch self {
        case .blue:           return 0x89B4FA  // ANSI 4
        case .red:            return 0xF38BA8  // ANSI 1
        case .green:          return 0xA6E3A1  // ANSI 2
        case .yellow:         return 0xF9E2AF  // ANSI 3
        case .magenta:        return 0xCBA6F7  // ANSI 5
        case .cyan:           return 0x94E2D5  // ANSI 6
        case .neutral:        return 0xBAC2DE  // ANSI 7 (white)
        case .brightBlue:     return 0x89DCEB  // ANSI 12
        case .brightRed:      return 0xEBA0AC  // ANSI 9
        case .brightGreen:    return 0xA6E3A1  // ANSI 10
        case .brightYellow:   return 0xF9E2AF  // ANSI 11
        case .brightMagenta:  return 0xF5C2E7  // ANSI 13
        case .brightCyan:     return 0x94E2D5  // ANSI 14
        case .neutralBright:  return 0xA6ADC8  // ANSI 15 (bright white)
        case .gray:           return 0x8E8E93
        }
    }
}

extension TintStop {
    /// A named stop resolves through the Ghostty theme palette. A hex stop is
    /// already literal and renders as given.
    var swiftUIColor: Color {
        switch self {
        case .named(let color): color.swiftUIColor
        case .hex(let rgb):
            Color(
                red: Double(rgb.r) / 255,
                green: Double(rgb.g) / 255,
                blue: Double(rgb.b) / 255
            )
        }
    }
}
