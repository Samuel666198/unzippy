import SwiftUI
import UnzippyCore

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.jobs.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(model.jobs) { job in
                            JobCardView(job: job, selected: model.selectedJobID == job.id)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity.combined(with: .scale(scale: 0.96))
                                ))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
                .scrollIndicators(.never)
            }
            Spacer(minLength: 0)
            footer
        }
        .background(VisualEffectBackground(material: .sidebar))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("队列")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(model.jobs.count)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
            Spacer()
            if !model.jobs.isEmpty {
                Menu {
                    Button("清空已完成", action: model.clearFinished)
                        .disabled(model.jobs.allSatisfy { !$0.isFinished })
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 22)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.quaternary)
            Text("队列是空的")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
            Text("把压缩包拖进来即可开始")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Hairline()
            Button {
                model.extractAll()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 11, weight: .bold))
                    Text(model.batchRunning ? "正在批量解压…" : "解压全部")
                    if model.pendingCount > 0 {
                        Text("\(model.pendingCount)")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.white.opacity(0.22)))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.pendingCount == 0 || model.batchRunning)
            .opacity(model.pendingCount == 0 ? 0.45 : 1)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle().fill(Theme.accent).frame(width: 5, height: 5)
                    Text("完成 \(model.finishedCount)")
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                if model.activeJob != nil {
                    Text("进行中 1")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .padding(.top, 8)
    }
}

struct JobCardView: View {
    let job: ArchiveJob
    let selected: Bool
    @EnvironmentObject private var model: AppModel
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 9) {
                FormatTile(format: job.format, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.name)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .truncationMode(.middle)
                    HStack(spacing: 6) {
                        Text(job.format.displayName)
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundStyle(job.format.tint)
                        Text(HumanFormat.bytes(job.size))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                        if let count = job.entryCount {
                            Text("· \(count) 项")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                    }
                }
                Spacer(minLength: 0)
                StatusPill(state: job.state, compact: true)
            }

            if job.state == .extracting {
                VStack(spacing: 5) {
                    ProgressTrack(progress: job.fraction, height: 4)
                    HStack {
                        Text(job.filesTotal > 0 ? "\(job.filesDone)/\(job.filesTotal)" : "准备中")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                        Spacer()
                        if job.speed > 1 {
                            Text(HumanFormat.speed(job.speed))
                                .font(.system(size: 9.5))
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                        Text("\(Int(job.fraction * 100))%")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .monospacedDigit()
                    }
                }
                .transition(.opacity)
            } else if job.state == .failed, let error = job.errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.rose)
                    .lineLimit(2)
            } else if job.state == .done {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                    Text("已解压 \(job.filesDone) 个文件")
                    if job.skippedCount > 0 {
                        Text("· 跳过 \(job.skippedCount)")
                    }
                }
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.accent.opacity(0.85))
                .monospacedDigit()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? Theme.accent.opacity(0.10) : (hovering ? Color.primary.opacity(0.045) : Color.primary.opacity(0.018)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? Theme.accent.opacity(0.45) : Theme.hairline, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { model.select(job.id) }
        .onHover { hover in
            withAnimation(.easeOut(duration: 0.14)) { hovering = hover }
        }
        .contextMenu {
            if job.state != .extracting {
                Button("解压") { model.extract(jobID: job.id) }
            } else {
                Button("取消解压") { model.cancelActive() }
            }
            Button("在 Finder 中显示压缩包") { model.revealArchive(jobID: job.id) }
            if let destination = job.destination, job.state == .done {
                Button("在 Finder 中显示解压结果") {
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                }
            }
            Divider()
            Button("移除", role: .destructive) { model.remove(jobID: job.id) }
                .disabled(job.state.isActive)
        }
        .animation(.easeOut(duration: 0.15), value: selected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(job.name)，\(job.state.label)")
    }
}
