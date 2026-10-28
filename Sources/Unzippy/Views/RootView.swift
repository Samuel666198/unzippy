import SwiftUI
import AppKit
import UnzippyCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack(alignment: .top) {
            appBackground
            VStack(spacing: 0) {
                AppHeaderView()
                Hairline()
                HStack(spacing: 0) {
                    SidebarView()
                        .frame(width: 296)
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(width: 1)
                    MainPanelView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Hairline()
                StatusBarView()
            }
            if let banner = model.banner {
                BannerView(message: banner)
                    .padding(.top, 58)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .background(WindowConfigurator())
        .dropDestination(for: URL.self) { urls, _ in
            model.add(urls: urls)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.16)) { model.isDropTargeted = targeted }
        }
        .sheet(item: $model.passwordPrompt) { prompt in
            PasswordSheet(prompt: prompt)
                .environmentObject(model)
        }
        .sheet(item: $model.compressionDraft) { draft in
            CompressionSheet(draft: draft)
                .environmentObject(model)
        }
        .frame(minWidth: 940, minHeight: 600)
    }

    private var appBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(
                colors: [Theme.accent.opacity(0.055), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 720
            )
            RadialGradient(
                colors: [Theme.amber.opacity(0.035), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 600
            )
        }
        .ignoresSafeArea()
    }
}

struct AppHeaderView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.accentBright, Theme.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "doc.zipper")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 27, height: 27)
                .shadow(color: Theme.accent.opacity(0.3), radius: 4, y: 1)

                Text("轻解压")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("UNZIPPY")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 1)
            }

            Spacer(minLength: 12)

            if !model.jobs.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 9))
                    Text("\(model.jobs.count) 个压缩包")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.primary.opacity(0.05)))
            }

            Button(action: model.chooseArchives) {
                Label("添加", systemImage: "plus")
            }
            .buttonStyle(SecondaryButtonStyle())
            .help("添加压缩包 (⌘O)")

            Button(action: model.chooseCompressionItems) {
                Label("压缩", systemImage: "archivebox")
            }
            .buttonStyle(SecondaryButtonStyle())
            .help("新建压缩包 (⌘N)")

            Button(action: { openSettings() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.045)))
            }
            .buttonStyle(.plain)
            .help("设置 (⌘,)")
        }
        .padding(.leading, 84)
        .padding(.trailing, 14)
        .frame(height: 52)
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor).opacity(0.94)
                LinearGradient(
                    colors: [Theme.accent.opacity(0.035), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

struct BannerView: View {
    let message: BannerMessage
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(message.title)
                    .font(.system(size: 12.5, weight: .semibold))
                if let detail = message.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Button {
                withAnimation(.easeOut(duration: 0.2)) { model.banner = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.14), radius: 18, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        )
        .frame(maxWidth: 460)
    }

    private var tint: Color {
        switch message.style {
        case .success: return Theme.accent
        case .error: return Theme.rose
        case .info: return Theme.indigo
        }
    }

    private var iconName: String {
        switch message.style {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}
