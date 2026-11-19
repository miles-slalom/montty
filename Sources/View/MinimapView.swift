// ABOUTME: Draws a tab's split minimap: a tinted rect per pane with focus and jump badges,
// ABOUTME: plus the animated indicator for Claude activity state.
import SwiftUI

struct MinimapView: View {
    let minimap: SplitMinimap
    let tabColor: Color
    var tabColorOverride: PaneTint?
    let isActiveTab: Bool
    var jumpLabels: [UUID: String] = [:]
    var surfaceDirectories: [UUID: String] = [:]
    var repoColorOverrides: [String: PaneTint] = [:]
    var surfaceColorOverrides: [UUID: PaneTint] = [:]
    var onPaneTap: ((UUID) -> Void)?

    private let gap: CGFloat = 4
    private let cornerRadius: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ForEach(minimap.panes, id: \.leafID) { pane in
                let frame = paneFrame(pane.rect, in: size)
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(paneFill(pane))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(paneBorder(pane), lineWidth: pane.isFocused ? 1.5 : 0.5)
                        )
                    if let label = jumpLabels[pane.leafID] {
                        JumpBadge(label: label, color: paneColor(pane), large: false)
                    } else if let activity = pane.activity {
                        ActivityIndicatorView(state: activity.state)
                    }
                }
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
                .onTapGesture {
                    onPaneTap?(pane.leafID)
                }
            }
        }
        .frame(height: 90)
    }

    private func paneFrame(_ rect: MinimapRect, in size: CGSize) -> CGRect {
        // Map normalized 0-1 rect to pixel coordinates, then inset by gap/2
        // so adjacent panes have a consistent gap between them.
        let rawFrame = CGRect(
            x: CGFloat(rect.originX) * size.width,
            y: CGFloat(rect.originY) * size.height,
            width: CGFloat(rect.width) * size.width,
            height: CGFloat(rect.height) * size.height
        )
        return rawFrame.insetBy(dx: gap / 2, dy: gap / 2)
    }

    private func paneTint(_ pane: MinimapPane) -> PaneTint? {
        TabColor.resolvedPaneTint(
            surfaceOverride: surfaceColorOverrides[pane.surfaceID],
            tabColorOverride: tabColorOverride,
            surfaceDirectory: surfaceDirectories[pane.surfaceID],
            repoColorOverrides: repoColorOverrides
        )
    }

    /// Single color for the jump badge (which can't render a gradient).
    private func paneColor(_ pane: MinimapPane) -> Color {
        paneTint(pane)?.primary.swiftUIColor ?? tabColor
    }

    private func paneFill(_ pane: MinimapPane) -> LinearGradient {
        let opacity: Double = pane.isFocused
            ? (isActiveTab ? 0.45 : 0.3)
            : (isActiveTab ? 0.2 : 0.12)
        if let tint = paneTint(pane) {
            return tint.gradient(opacity: opacity)
        }
        // No git info -- fall back to a solid grey gradient (both stops same).
        return LinearGradient(
            colors: [tabColor.opacity(opacity), tabColor.opacity(opacity)],
            startPoint: .leading, endPoint: .trailing
        )
    }

    private func paneBorder(_ pane: MinimapPane) -> LinearGradient {
        let opacity: Double = pane.isFocused
            ? (isActiveTab ? 0.9 : 0.5)
            : (isActiveTab ? 0.45 : 0.25)
        if let tint = paneTint(pane) {
            return tint.gradient(opacity: opacity)
        }
        return LinearGradient(
            colors: [tabColor.opacity(opacity), tabColor.opacity(opacity)],
            startPoint: .leading, endPoint: .trailing
        )
    }
}

/// Animated indicator for activity state on a minimap pane.
struct ActivityIndicatorView: View {
    let state: ActivityStatus.State
    /// The glyph size; every frame below scales with it.
    var fontSize: CGFloat = 24

    @State private var breathing = false

    /// Loudest to quietest: waiting is a static filled badge, idle a solid
    /// star, and working a dim star that slowly breathes, which asks nothing
    /// of the user.
    var body: some View {
        switch state {
        case .waiting:
            Text("?")
                .font(.system(size: fontSize * 0.8, weight: .heavy, design: .monospaced))
                .foregroundStyle(.black)
                .frame(width: fontSize, height: fontSize)
                .background(Circle().fill(Color.orange))
        case .idle:
            Text("*")
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundStyle(.orange)
                .frame(width: fontSize, height: fontSize)
        case .working:
            Text("*")
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: fontSize, height: fontSize)
                .opacity(breathing ? 0.55 : 0.25)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: breathing)
                .onAppear { breathing = true }
        }
    }
}
