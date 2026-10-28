import SwiftUI
import AppKit
import UnzippyCore

struct CompressionSheet: View {
    let draft: CompressionDraft
    @EnvironmentObject private var model: AppModel

    @State private var fileName: String
    @State private var format: CompressionFormat
    @State private var level: Int
    @State private var destination: URL
    @State private var items: [URL]
    @State private var localError: String?
    @State private var protectWithPassword: Bool
    @State private var password: String
    @FocusState private var nameFocused: Bool

    init(draft: CompressionDraft) {
        self.draft = draft
        _fileName = State(initialValue: draft.fileName)
        _format = State(initialValue: draft.format)
        _level = State(initialValue: draft.level)
        _destination = State(initialValue: draft.destination)
        _items = State(initialValue: draft.items)
        _protectWithPassword = State(initialValue: !draft.password.isEmpty)
        _password = State(initialValue: draft.password)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    nameSection
                    itemsSection
                    formatSection
                    levelSection
                    if format == .zip {
                        passwordSection
                    }
                    destinationSection
                    if let error = localError ?? model.compressionError {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text(error)
                                .lineLimit(2)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.rose)
                    }
                }
                .padding(20)
            }
            Hairline()
            footer
        }
        .frame(width: 540, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { nameFocused = true }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "archivebox")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("新建压缩包")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("\(items.count) 个项目")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("名称")
            HStack(spacing: 0) {
                TextField("压缩包名称", text: $fileName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .focused($nameFocused)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                Text(".\(format.fileExtension)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(nameFocused ? Theme.accent.opacity(0.45) : Theme.hairline, lineWidth: 1)
            )
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                label("内容")
                Spacer()
                Button {
                    addMoreItems()
                } label: {
                    Label("添加", systemImage: "plus")
                        .font(.system(size: 10.5))
                }
                .buttonStyle(.link)
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, url in
                        HStack(spacing: 8) {
                            Image(systemName: icon(for: url))
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.accent.opacity(0.85))
                                .frame(width: 15)
                            Text(url.lastPathComponent)
                                .font(.system(size: 11.5))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(sizeLabel(for: url))
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                            Button {
                                items.remove(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        if index < items.count - 1 {
                            Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 33)
                        }
                    }
                }
            }
            .frame(maxHeight: 132)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.025))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            )
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            label("格式")
            HStack(spacing: 8) {
                ForEach(CompressionFormat.allCases) { option in
                    FormatOptionCard(
                        format: option,
                        selected: format == option,
                        disabled: model.isCompressing
                    ) {
                        format = option
                    }
                }
            }
        }
    }

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                label("压缩级别")
                Spacer()
                Text(levelDescription)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 6) {
                ForEach(Array(zip([0, 3, 6, 9], ["仅存储", "快速", "标准", "极致"])), id: \.0) { pair in
                    let (value, title) = pair
                    Button {
                        level = value
                    } label: {
                        Text(title)
                            .font(.system(size: 11, weight: level == value ? .semibold : .regular))
                            .foregroundStyle(level == value ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(level == value ? Theme.accent : Color.primary.opacity(0.045))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isCompressing)
                }
            }
        }
    }

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                label("加密")
                Spacer()
                Toggle("使用密码保护", isOn: $protectWithPassword)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .disabled(model.isCompressing)
            }
            if protectWithPassword {
                SecureField("设置密码", text: $password)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.045))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
                    .disabled(model.isCompressing)
                Text("AES-256 加密。Windows 资源管理器或旧版 macOS 可能需要第三方工具（7-Zip、Keka）打开。")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: format) { _, newValue in
            if newValue != .zip { protectWithPassword = false }
        }
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("保存到")
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.accent)
                Text(destination.path)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("更改…") { chooseDestination() }
                    .buttonStyle(.link)
                    .font(.system(size: 10.5))
                    .disabled(model.isCompressing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.025))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            )
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if model.isCompressing {
                VStack(spacing: 5) {
                    ProgressTrack(progress: model.compressionFraction, height: 4)
                    HStack {
                        Text(model.compressionStatus.isEmpty ? "正在压缩…" : model.compressionStatus)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text("\(Int(model.compressionFraction * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .monospacedDigit()
                    }
                }
            }
            HStack(spacing: 8) {
                Button("取消") {
                    if model.isCompressing {
                        model.cancelCompression()
                    } else {
                        model.dismissCompression()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)

                Spacer()

                if !model.isCompressing {
                    Button {
                        create()
                    } label: {
                        Label("创建压缩包", systemImage: "archivebox")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(fileName.trimmingCharacters(in: .whitespaces).isEmpty || items.isEmpty)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var levelDescription: String {
        switch level {
        case 0: return "不压缩，速度最快"
        case 1...3: return "速度快，体积略大"
        case 4...6: return "平衡速度与体积"
        default: return "体积最小，速度较慢"
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.4)
    }

    private func icon(for url: URL) -> String {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue ? "folder.fill" : "doc"
    }

    private func sizeLabel(for url: URL) -> String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        return size > 0 ? HumanFormat.bytes(size) : ""
    }

    private func addMoreItems() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "添加"
        if panel.runModal() == .OK {
            for url in panel.urls where !items.contains(url) {
                items.append(url)
            }
        }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "选择"
        if panel.runModal() == .OK, let url = panel.url {
            destination = url
        }
    }

    private func create() {
        localError = nil
        guard !items.isEmpty else {
            localError = "请至少添加一个文件或文件夹"
            return
        }
        if format == .zip, protectWithPassword, password.isEmpty {
            localError = "请输入压缩包密码"
            return
        }
        var updated = draft
        updated.items = items
        updated.fileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.format = format
        updated.level = level
        updated.destination = destination
        updated.password = (format == .zip && protectWithPassword) ? password : ""
        model.compressionDraft = updated
        model.startCompression()
    }
}

struct FormatOptionCard: View {
    let format: CompressionFormat
    let selected: Bool
    let disabled: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: format.symbolName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(selected ? format.tint : .secondary)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(format.tint)
                    }
                }
                Text(format.displayName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(format.detail)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? format.tint.opacity(0.10) : (hovering ? Color.primary.opacity(0.045) : Color.primary.opacity(0.018)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(selected ? format.tint.opacity(0.55) : Theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovering = $0 }
    }
}
