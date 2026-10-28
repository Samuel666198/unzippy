import SwiftUI
import UnzippyCore

struct MainPanelView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if let id = model.selectedJobID, let job = model.job(id) {
                if let summary = model.detailSummary {
                    ArchiveDetailView(job: job, summary: summary)
                } else if let error = model.detailError {
                    DetailErrorView(job: job, message: error)
                } else {
                    DetailLoadingView(job: job)
                }
            } else {
                EmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DetailLoadingView: View {
    let job: ArchiveJob

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.08))
                    .frame(width: 58, height: 58)
                ProgressView()
                    .controlSize(.small)
            }
            Text("正在读取压缩包")
                .font(.system(size: 14, weight: .medium))
            Text(job.name)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text("大文件或高压缩率格式可能需要几秒钟")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DetailErrorView: View {
    let job: ArchiveJob
    let message: String
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.rose.opacity(0.09))
                    .frame(width: 66, height: 66)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 25, weight: .light))
                    .foregroundStyle(Theme.rose)
            }
            Text("无法读取这个压缩包")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text(job.name)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            HStack(spacing: 8) {
                Button("重试") {
                    model.loadDetail(jobID: job.id, force: true)
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("在 Finder 中显示") { model.revealArchive(jobID: job.id) }
                    .buttonStyle(SecondaryButtonStyle())
                Button("压缩此文件") { model.openCompressionSheet(items: [job.url]) }
                    .buttonStyle(SecondaryButtonStyle())
                Button("移除", role: .destructive) { model.remove(jobID: job.id) }
                    .buttonStyle(SecondaryButtonStyle(tint: Theme.rose))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct EmptyStateView: View {
    @EnvironmentObject private var model: AppModel
    @State private var floating = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 18)
                ZipperHero(floating: floating)
                    .frame(height: 220)
                    .padding(.bottom, 6)

                Text(model.isDropTargeted ? "松手即可添加" : "把压缩包拖进来")
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text("ZIP · 7Z · RAR · TAR · GZ · BZ2 · XZ · ISO · CAB …")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                Text("支持密码、中文文件名修复、批量解压与选择性解压")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 3)

                HStack(spacing: 9) {
                    Button {
                        model.chooseArchives()
                    } label: {
                        Label("选择文件", systemImage: "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        model.chooseCompressionItems()
                    } label: {
                        Label("压缩文件", systemImage: "archivebox")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 22)

                Text("也可以把文件拖到 Dock 图标，或在 Finder 里右键使用「轻解压」")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 14)
                Spacer(minLength: 20)
            }
            .padding(22)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    Theme.accent.opacity(model.isDropTargeted ? 0.85 : 0.18),
                    style: StrokeStyle(lineWidth: model.isDropTargeted ? 2 : 1.2, dash: model.isDropTargeted ? [] : [7, 6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Theme.accent.opacity(model.isDropTargeted ? 0.06 : 0.012))
                )
                .padding(22)
                .allowsHitTesting(false)
        }
        .scaleEffect(model.isDropTargeted ? 0.995 : 1)
        .animation(.easeOut(duration: 0.18), value: model.isDropTargeted)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }
}

/// A small hand-drawn "opening archive" illustration.
struct ZipperHero: View {
    var floating: Bool

    var body: some View {
        ZStack {
            // Back tiles
            FormatTile(format: .sevenZip, size: 50)
                .rotationEffect(.degrees(-14))
                .offset(x: -124, y: -46)
                .shadow(color: Theme.indigo.opacity(0.2), radius: 12, y: 6)
            FormatTile(format: .rar, size: 44)
                .rotationEffect(.degrees(11))
                .offset(x: 128, y: -58)
                .shadow(color: Theme.rose.opacity(0.18), radius: 10, y: 5)
            FormatTile(format: .tarGz, size: 38)
                .rotationEffect(.degrees(8))
                .offset(x: 134, y: 62)
                .shadow(color: Theme.accent.opacity(0.18), radius: 8, y: 4)

            // Main archive sheet
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.98), Color.white.opacity(0.86)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.16), radius: 26, y: 14)

                // Fake content lines
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 3).fill(Theme.accent.opacity(0.22)).frame(width: 58, height: 7)
                    RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.10)).frame(width: 92, height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.07)).frame(width: 76, height: 6)
                    Spacer()
                }
                .padding(.top, 26)
                .padding(.leading, 23)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Zipper
                VStack(spacing: 0) {
                    ZStack {
                        Capsule().fill(Theme.accentDeep.opacity(0.10)).frame(width: 3)
                        VStack(spacing: 7) {
                            ForEach(0..<7, id: \.self) { index in
                                HStack(spacing: 3) {
                                    RoundedRectangle(cornerRadius: 1.6)
                                        .fill(index % 2 == 0 ? Theme.accent : Theme.accent.opacity(0.55))
                                        .frame(width: 13, height: 6)
                                    RoundedRectangle(cornerRadius: 1.6)
                                        .fill(index % 2 == 0 ? Theme.accent.opacity(0.55) : Theme.accent)
                                        .frame(width: 13, height: 6)
                                }
                                .offset(x: index % 2 == 0 ? -3 : 3)
                            }
                        }
                    }
                    .frame(width: 40, height: 128)

                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.amber, Theme.amber.opacity(0.82)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 35, height: 46)
                            .shadow(color: Theme.amber.opacity(0.4), radius: 6, y: 3)
                        Circle()
                            .fill(.white.opacity(0.85))
                            .frame(width: 9, height: 9)
                            .offset(y: 8)
                    }
                    .offset(y: -3)
                }
                .offset(x: 48, y: 6)
            }
            .frame(width: 178, height: 200)
            .rotationEffect(.degrees(floating ? -2.4 : -5.2))
            .offset(y: floating ? -5 : 3)
        }
        .frame(maxWidth: .infinity)
    }
}
