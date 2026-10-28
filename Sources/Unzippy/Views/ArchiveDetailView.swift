import SwiftUI
import AppKit
import UnzippyCore

extension ArchiveEntryInfo {
    var modifiedSortKey: Date { modified ?? .distantPast }
}

struct ArchiveDetailView: View {
    let job: ArchiveJob
    let summary: ArchiveSummary
    @EnvironmentObject private var model: AppModel

    @State private var selection = Set<Int>()
    @State private var searchText = ""
    @State private var sortOrder: [KeyPathComparator<ArchiveEntryInfo>] = [
        KeyPathComparator(\.path, order: .forward)
    ]

    private var rows: [ArchiveEntryInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = query.isEmpty
            ? summary.entries
            : summary.entries.filter { $0.path.localizedCaseInsensitiveContains(query) }
        return filtered.sorted(using: sortOrder)
    }

    private var selectedBytes: Int64 {
        summary.entries.reduce(Int64(0)) { partial, entry in
            selection.contains(entry.index) && !entry.isDirectory ? partial + entry.size : partial
        }
    }

    private var destinationLabel: String {
        switch Prefs.destinationMode {
        case .ask: return "每次询问"
        case .sameFolder: return "压缩包所在文件夹"
        case .downloads: return "下载"
        case .custom: return Prefs.customDestination?.lastPathComponent ?? "自定义文件夹"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 17)
                .padding(.bottom, 13)
            Hairline()
            if job.state == .failed, let message = job.errorMessage {
                errorStrip(message)
            }
            toolbar
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
            table
        }
        .onChange(of: model.detailEncoding) { _, _ in selection.removeAll() }
        .onChange(of: summary.entryCount) { _, _ in
            selection = selection.filter { ids in summary.entries.contains { $0.index == ids } }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            FormatTile(format: job.format, size: 54)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(job.name)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(job.url.path)
                    StatusPill(state: job.state)
                    if summary.hasEncryptedEntries {
                        Chip(icon: "lock.fill", text: "已加密", tint: Theme.rose)
                    }
                }
                HStack(spacing: 6) {
                    Chip(icon: "doc.on.doc", text: "\(summary.fileCount) 个文件")
                    if summary.directoryCount > 0 {
                        Chip(icon: "folder", text: "\(summary.directoryCount) 个文件夹")
                    }
                    Chip(icon: "externaldrive", text: HumanFormat.bytes(summary.totalSize))
                    if summary.savedPercent > 0 {
                        Chip(icon: "arrow.down.right.and.arrow.up.left", text: "已省 \(summary.savedPercent)%", tint: Theme.accent)
                    }
                }
                HStack(spacing: 5) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.accent.opacity(0.8))
                    Text("解压到 \(destinationLabel)")
                        .font(.system(size: 10.5))
                    Button("更改…") { model.chooseExtractionFolder(for: job.id) }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.accent.opacity(0.06)))
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    model.extract(jobID: job.id)
                } label: {
                    Label("解压全部", systemImage: "arrow.down.to.line.compact")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(job.state == .extracting)

                Menu {
                    Button("解压到压缩包所在文件夹") {
                        model.extract(jobID: job.id, destination: job.url.deletingLastPathComponent())
                    }
                    Button("解压到下载文件夹") {
                        model.extract(jobID: job.id, destination: Prefs.downloadsFolder())
                    }
                    Button("选择位置并解压…") {
                        model.chooseExtractionFolder(for: job.id)
                    }
                    Divider()
                    Button("在 Finder 中显示压缩包") { model.revealArchive(jobID: job.id) }
                    if job.state == .done, let destination = job.destination {
                        Button("在 Finder 中显示解压结果") {
                            NSWorkspace.shared.activateFileViewerSelecting([destination])
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text("更多")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .font(.system(size: 10.5))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .foregroundStyle(.secondary)
            }
        }
    }

    private func errorStrip(_ message: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.rose)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(Theme.rose)
                .lineLimit(1)
            Spacer()
            Button("重试") { model.extract(jobID: job.id) }
                .buttonStyle(.link)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Theme.rose.opacity(0.06))
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            SearchField(text: $searchText, placeholder: "搜索 \(summary.entryCount) 个条目")
                .frame(width: 230)

            Menu {
                ForEach(FilenameEncoding.allCases) { encoding in
                    Button {
                        model.setEncoding(encoding, for: job.id)
                    } label: {
                        if encoding == model.detailEncoding {
                            Label(encoding.displayName, systemImage: "checkmark")
                        } else {
                            Text(encoding.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "character.cursor.ibeam")
                    Text("编码 \(model.detailEncoding.shortName)")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
                .font(.system(size: 10.5))
                .foregroundStyle(model.detailEncoding == .automatic ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.amber))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.primary.opacity(0.05)))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("中文文件名乱码时切换编码")

            Spacer()

            if !selection.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                    Text("已选 \(selection.count) 项")
                    Text("· \(HumanFormat.bytes(selectedBytes))")
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.accent)
                .monospacedDigit()

                Button {
                    model.extract(jobID: job.id, selection: selection)
                } label: {
                    Label("解压所选", systemImage: "arrow.down.doc")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(job.state == .extracting)
            } else {
                Text("\(summary.entryCount) 个条目 · \(HumanFormat.bytes(summary.archiveSize))")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }

    private var table: some View {
        ZStack {
            Table(rows, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("名称", value: \.path) { entry in
                    EntryNameCell(entry: entry)
                }
                .width(min: 220, ideal: 330)

                TableColumn("大小", value: \.size) { entry in
                    Text(entry.isDirectory ? "—" : HumanFormat.bytes(entry.size))
                        .font(.system(size: 11))
                        .foregroundStyle(entry.isDirectory ? .tertiary : .secondary)
                        .monospacedDigit()
                }
                .width(min: 66, ideal: 78, max: 96)

                TableColumn("压缩后", value: \.compressedSize) { entry in
                    Text(entry.compressedSize > 0 ? HumanFormat.bytes(entry.compressedSize) : "—")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .width(min: 66, ideal: 78, max: 96)

                TableColumn("修改时间", value: \.modifiedSortKey) { entry in
                    Text(HumanFormat.compactDate(entry.modified))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .width(min: 112, ideal: 132, max: 170)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .tint(Theme.accent)
            .contextMenu(forSelectionType: Int.self) { ids in
                if !ids.isEmpty {
                    Button("解压所选 \(ids.count) 项") { model.extract(jobID: job.id, selection: ids) }
                        .disabled(job.state == .extracting)
                }
            } primaryAction: { ids in
                if !ids.isEmpty { model.extract(jobID: job.id, selection: ids) }
            }

            if rows.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.quaternary)
                    Text(searchText.isEmpty ? "这个压缩包是空的" : "没有匹配「\(searchText)」的条目")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
            }
        }
    }
}

struct EntryNameCell: View {
    let entry: ArchiveEntryInfo

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: entry.kind.symbolName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(entry.isDirectory ? Theme.amber : iconTint)
                .frame(width: 15)
            Text(entry.path)
                .font(.system(size: 11.5))
                .foregroundStyle(entry.isDirectory ? Color.primary : Color.primary.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(entry.path)
            if entry.isSymlink, let target = entry.linkTarget {
                Text("→ \(target)")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 2)
    }

    private var iconTint: Color {
        switch entry.kind {
        case .folder: return Theme.amber
        case .image: return Color(red: 0.36, green: 0.62, blue: 0.90)
        case .video: return Theme.rose
        case .audio: return Color(red: 0.55, green: 0.45, blue: 0.85)
        case .pdf: return Color(red: 0.84, green: 0.30, blue: 0.28)
        case .code: return Theme.accent
        case .archive: return Theme.amber
        case .symlink: return Theme.indigo
        default: return .secondary
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    var placeholder: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .focused($focused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(focused ? 0.06 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(focused ? Theme.accent.opacity(0.45) : Theme.hairline, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.12), value: focused)
    }
}
