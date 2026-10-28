import SwiftUI
import AppKit
import UnzippyCore

// MARK: - AppKit bridges

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

/// Lets the user drag the window from our custom header.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DraggableView()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}

    private final class DraggableView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

// MARK: - Brand / format

struct FormatTile: View {
    let format: ArchiveFormat
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [format.tint.opacity(0.98), format.tint.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            Text(format.badge)
                .font(.system(size: size * 0.29, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
        }
        .frame(width: size, height: size)
        .shadow(color: format.tint.opacity(0.28), radius: size * 0.18, y: size * 0.08)
    }
}

struct StatusPill: View {
    let state: JobState
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(state.tint)
                .frame(width: 5.5, height: 5.5)
            Text(state.label)
                .font(.system(size: compact ? 10 : 11, weight: .medium))
                .foregroundStyle(state.tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(
            Capsule(style: .continuous)
                .fill(state.tint.opacity(0.11))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(state.tint.opacity(0.16), lineWidth: 0.5)
        )
    }
}

struct Chip: View {
    let icon: String?
    let text: String
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.08)))
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 0.6)
            )
            .shadow(color: tint.opacity(configuration.isPressed ? 0.1 : 0.22), radius: 6, y: 2)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.10 : 0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct IconButton: View {
    let systemName: String
    var help: String = ""
    var tint: Color = .secondary
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovering ? tint : .secondary)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(hovering ? Color.primary.opacity(0.07) : .clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

// MARK: - Progress

struct ProgressTrack: View {
    var progress: Double
    var tint: Color = Theme.accent
    var height: CGFloat = 5
    var animated = true

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.07))
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.75), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
                    .animation(animated ? .easeOut(duration: 0.22) : nil, value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Layout helpers

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }
}

struct EmptyHint: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ShortcutRecorder: View {
    let keys: String
    var body: some View {
        Text(keys)
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.05)))
    }
}
