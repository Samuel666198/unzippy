import SwiftUI
import AppKit
import UnzippyCore

struct SettingsView: View {
    @State private var tab: SettingsTab

    init(initialTab: SettingsTab = .general) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 196)
            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)
            ScrollView {
                Group {
                    switch tab {
                    case .general: GeneralSettingsView()
                    case .advanced: AdvancedSettingsView()
                    case .about: AboutSettingsView()
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.never)
            .frame(width: 500)
        }
        .frame(width: 696, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
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
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text("轻解压")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text("设置")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 16)

            ForEach(SettingsTab.allCases) { item in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { tab = item }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 16)
                        Text(item.title)
                            .font(.system(size: 12.5, weight: tab == item ? .semibold : .regular))
                        Spacer()
                    }
                    .foregroundStyle(tab == item ? Theme.accent : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tab == item ? Theme.accent.opacity(0.11) : .clear)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 3) {
                Text("轻解压 1.0")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text("libarchive · SwiftUI")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(VisualEffectBackground(material: .sidebar))
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, advanced, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "通用"
        case .advanced: return "高级"
        case .about: return "关于"
        }
    }
    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .advanced: return "slider.horizontal.3"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Reusable rows

struct SettingsPageHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 16)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.35)
                .padding(.leading, 2)
            VStack(spacing: 0) { content }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.028))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        }
    }
}

struct SettingsRow<Control: View>: View {
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint.opacity(0.10)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
            .padding(.leading, 44)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @AppStorage(PrefKey.destinationMode) private var destinationModeRaw = DestinationMode.sameFolder.rawValue
    @AppStorage(PrefKey.customDestination) private var customDestination = ""
    @AppStorage(PrefKey.createSubfolder) private var createSubfolder = true
    @AppStorage(PrefKey.conflictPolicy) private var conflictPolicyRaw = ConflictPolicy.rename.rawValue
    @AppStorage(PrefKey.revealInFinder) private var revealInFinder = true
    @AppStorage(PrefKey.deleteArchive) private var deleteArchive = false
    @AppStorage(PrefKey.rememberPasswords) private var rememberPasswords = false

    private var mode: Binding<DestinationMode> {
        Binding(
            get: { DestinationMode(rawValue: destinationModeRaw) ?? .sameFolder },
            set: { destinationModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsPageHeader(title: "通用", subtitle: "决定文件解压到哪里，以及如何处理同名文件。")

            SettingsSection(title: "解压位置") {
                SettingsRow(icon: "arrow.down.to.line", tint: Theme.accent, title: "默认解压到", subtitle: nil) {
                    Picker("", selection: mode) {
                        ForEach(DestinationMode.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 195)
                }
                if mode.wrappedValue == .custom {
                    SettingsDivider()
                    HStack(spacing: 7) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text(customDestination.isEmpty ? "尚未选择文件夹" : customDestination)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("选择…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.canCreateDirectories = true
                            if panel.runModal() == .OK, let url = panel.url {
                                customDestination = url.path
                            }
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 10.5))
                    }
                    .padding(.horizontal, 46)
                    .padding(.vertical, 8)
                }
                SettingsDivider()
                SettingsRow(
                    icon: "folder.badge.plus",
                    tint: Theme.amber,
                    title: "自动创建文件夹",
                    subtitle: "解压「照片.zip」时先创建「照片」文件夹，避免文件散落"
                ) {
                    Toggle("", isOn: $createSubfolder)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }

            SettingsSection(title: "文件冲突") {
                SettingsRow(icon: "doc.on.doc", tint: Theme.indigo, title: "遇到同名文件", subtitle: nil) {
                    Picker("", selection: $conflictPolicyRaw) {
                        ForEach(ConflictPolicy.allCases) { policy in
                            Text(policy.displayName).tag(policy.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 215)
                }
            }

            SettingsSection(title: "完成后") {
                SettingsRow(icon: "finder", tint: Theme.accent, title: "在 Finder 中显示", subtitle: nil) {
                    Toggle("", isOn: $revealInFinder).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                SettingsDivider()
                SettingsRow(icon: "trash", tint: Theme.rose, title: "把压缩包移到废纸篓", subtitle: "仅在解压成功后执行") {
                    Toggle("", isOn: $deleteArchive).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                SettingsDivider()
                SettingsRow(icon: "key", tint: Theme.amber, title: "记住密码", subtitle: "保存到系统钥匙串，按压缩包路径区分") {
                    Toggle("", isOn: $rememberPasswords).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
            }
        }
    }
}

// MARK: - Advanced

struct AdvancedSettingsView: View {
    @AppStorage(PrefKey.encoding) private var encodingRaw = FilenameEncoding.automatic.rawValue
    @AppStorage(PrefKey.preservePermissions) private var preservePermissions = true
    @AppStorage(PrefKey.extractSymlinks) private var extractSymlinks = true
    @AppStorage(PrefKey.skipMacOSX) private var skipMacOSX = true
    @AppStorage(PrefKey.removeQuarantine) private var removeQuarantine = true
    @AppStorage(PrefKey.skipDSStore) private var skipDSStore = true

    private var encoding: Binding<FilenameEncoding> {
        Binding(
            get: { FilenameEncoding(rawValue: encodingRaw) ?? .automatic },
            set: { encodingRaw = $0.rawValue }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsPageHeader(title: "高级", subtitle: "文件名编码、权限和引擎行为。大多数情况下保持默认即可。")

            SettingsSection(title: "文件名") {
                SettingsRow(
                    icon: "character.cursor.ibeam",
                    tint: Theme.indigo,
                    title: "文件名编码",
                    subtitle: "Windows 生成的 ZIP 常用 GBK；乱码时可手动指定"
                ) {
                    Picker("", selection: encoding) {
                        ForEach(FilenameEncoding.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 190)
                }
            }

            SettingsSection(title: "文件属性") {
                SettingsRow(icon: "lock.doc", tint: Theme.accent, title: "保留权限与修改时间", subtitle: nil) {
                    Toggle("", isOn: $preservePermissions).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                SettingsDivider()
                SettingsRow(icon: "link", tint: Theme.amber, title: "解压符号链接", subtitle: "仅保留指向目标文件夹内部的链接") {
                    Toggle("", isOn: $extractSymlinks).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                SettingsDivider()
                SettingsRow(icon: "eye.slash", tint: Theme.slate, title: "忽略 __MACOSX", subtitle: nil) {
                    Toggle("", isOn: $skipMacOSX).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                SettingsDivider()
                SettingsRow(icon: "shield.lefthalf.filled", tint: Theme.rose, title: "清除隔离属性", subtitle: "解除下载文件的 quarantine 标记") {
                    Toggle("", isOn: $removeQuarantine).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                SettingsDivider()
                SettingsRow(icon: "doc.badge.gearshape", tint: Theme.indigo, title: "跳过 .DS_Store", subtitle: "创建压缩包时忽略 Finder 元数据") {
                    Toggle("", isOn: $skipDSStore).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.accent)
                    Text("解压采用流式读写，不会把文件载入内存；界面为原生 SwiftUI，无 Electron、无后台守护进程。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("恢复默认设置") {
                    let domain = Bundle.main.bundleIdentifier ?? "com.samuel.unzippy"
                    UserDefaults.standard.removePersistentDomain(forName: domain)
                    Prefs.registerDefaults()
                }
                .buttonStyle(.link)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.rose)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.accent.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.12), lineWidth: 1)
            )
        }
    }
}

// MARK: - About

struct AboutSettingsView: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 76, height: 76)
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("轻解压")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text("UNZIPPY · \(version)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("安静、快速的 macOS 解压工具")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }

            SettingsSection(title: "支持的格式") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach([ArchiveFormat.zip, .sevenZip, .rar, .tarGz, .gzip, .iso, .cab], id: \.rawValue) { format in
                            FormatTile(format: format, size: 34)
                        }
                    }
                    Text("ZIP · 7Z · RAR · TAR · TAR.GZ · TAR.BZ2 · TAR.XZ · GZ · BZ2 · XZ · ISO · CAB · CPIO · XAR · LHA · JAR · CBZ · CBR")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
            }

            SettingsSection(title: "引擎") {
                VStack(alignment: .leading, spacing: 6) {
                    infoLine("内部引擎", "macOS 内置 libarchive 3.7")
                    infoLine("界面", "SwiftUI（原生，无 Web 容器）")
                    infoLine("安全", "路径穿越与符号链接逃逸防护")
                    infoLine("隐私", "完全离线，不收集任何数据")
                }
                .padding(12)
            }

            HStack(spacing: 8) {
                Button {
                    if let path = Bundle.main.path(forResource: "README", ofType: "md") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    }
                } label: {
                    Label("使用说明", systemImage: "book")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                } label: {
                    Label("在 Finder 中显示", systemImage: "folder")
                }
                .buttonStyle(SecondaryButtonStyle())

                Spacer()
            }

            Text("© 2026 Samuel. 仅供个人使用。")
                .font(.system(size: 9.5))
                .foregroundStyle(.quaternary)
                .padding(.top, 2)
        }
    }

    private func infoLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 62, alignment: .leading)
            Text(value)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }
}
