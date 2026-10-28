import SwiftUI
import UnzippyCore

struct StatusBarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if let job = model.activeJob {
                ProgressTrack(progress: job.fraction, height: 2, animated: false)
                    .transition(.opacity)
            }
            HStack(spacing: 8) {
                Circle()
                    .fill(model.activeJob == nil ? Theme.accent : Theme.amber)
                    .frame(width: 6, height: 6)
                if let job = model.activeJob {
                    Text(model.batchRunning ? "批量解压中" : "正在解压")
                        .font(.system(size: 10.5, weight: .medium))
                    Text(job.name)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if job.filesTotal > 0 {
                        Text("\(job.filesDone)/\(job.filesTotal)")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    Spacer()
                    if job.speed > 1 {
                        Text(HumanFormat.speed(job.speed))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    if let eta = job.eta {
                        Text("剩余 \(HumanFormat.duration(eta))")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    Button("取消") { model.cancelActive() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.rose)
                } else {
                    Text("就绪")
                        .font(.system(size: 10.5, weight: .medium))
                    Text("· 原生 libarchive 引擎 · 支持 ZIP / 7Z / RAR / TAR / GZ / ISO")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text("v1.0")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 27)
        }
        .background(.regularMaterial.opacity(0.35))
    }
}
