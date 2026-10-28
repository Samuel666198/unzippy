import Foundation

public struct ArchiveEntryInfo: Identifiable, Hashable, Sendable {
    public let index: Int
    public var path: String
    public var isDirectory: Bool
    public var isSymlink: Bool
    public var size: Int64
    public var compressedSize: Int64
    public var modified: Date?
    public var permissions: UInt16
    public var linkTarget: String?
    public var hardlinkTarget: String?

    public var id: Int { index }

    public init(
        index: Int,
        path: String,
        isDirectory: Bool,
        isSymlink: Bool = false,
        size: Int64 = 0,
        compressedSize: Int64 = 0,
        modified: Date? = nil,
        permissions: UInt16 = 0o644,
        linkTarget: String? = nil,
        hardlinkTarget: String? = nil
    ) {
        self.index = index
        self.path = path
        self.isDirectory = isDirectory
        self.isSymlink = isSymlink
        self.size = size
        self.compressedSize = compressedSize
        self.modified = modified
        self.permissions = permissions
        self.linkTarget = linkTarget
        self.hardlinkTarget = hardlinkTarget
    }

    /// Last path component, e.g. "报告.pdf".
    public var name: String {
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        if let slash = trimmed.lastIndex(of: "/") {
            return String(trimmed[trimmed.index(after: slash)...])
        }
        return trimmed
    }

    public var parentPath: String? {
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        guard let slash = trimmed.lastIndex(of: "/") else { return nil }
        return String(trimmed[..<slash])
    }

    public var depth: Int {
        path.filter { $0 == "/" }.count
    }

    public var fileExtension: String {
        isDirectory ? "" : (name as NSString).pathExtension.lowercased()
    }

    /// Kind used to pick an icon in the UI.
    public var kind: EntryKind {
        if isDirectory { return .folder }
        if isSymlink { return .symlink }
        switch fileExtension {
        case "txt", "md", "rtf", "log", "csv", "json", "xml", "yml", "yaml", "plist":
            return .text
        case "pdf":
            return .pdf
        case "png", "jpg", "jpeg", "gif", "heic", "webp", "tif", "tiff", "bmp", "svg", "ico":
            return .image
        case "mp4", "mov", "m4v", "avi", "mkv", "webm":
            return .video
        case "mp3", "m4a", "wav", "flac", "aac", "aiff", "ogg":
            return .audio
        case "swift", "py", "js", "ts", "tsx", "jsx", "c", "h", "cpp", "rs", "go", "java", "kt", "sh", "zsh", "rb", "php", "html", "css", "scss":
            return .code
        case "app", "exe", "dmg", "pkg", "dylib", "so":
            return .binary
        case "zip", "7z", "rar", "gz", "tar", "bz2", "xz", "zst":
            return .archive
        default:
            return .file
        }
    }

    public enum EntryKind: Sendable {
        case folder, file, text, image, video, audio, code, pdf, archive, binary, symlink

        public var symbolName: String {
            switch self {
            case .folder: return "folder.fill"
            case .file: return "doc"
            case .text: return "doc.text"
            case .image: return "photo"
            case .video: return "film"
            case .audio: return "waveform"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .pdf: return "doc.richtext"
            case .archive: return "doc.zipper"
            case .binary: return "gearshape.2"
            case .symlink: return "link"
            }
        }
    }
}

public struct ArchiveSummary: Sendable {
    public let url: URL
    public let format: ArchiveFormat
    public let formatDescription: String
    public let entryCount: Int
    public let fileCount: Int
    public let directoryCount: Int
    public let totalSize: Int64
    public let archiveSize: Int64
    public let hasEncryptedEntries: Bool
    public let entries: [ArchiveEntryInfo]

    public var compressionRatio: Double {
        guard totalSize > 0, archiveSize > 0 else { return 0 }
        return Double(archiveSize) / Double(totalSize)
    }

    public var savedPercent: Int {
        guard totalSize > 0 else { return 0 }
        let saved = 1.0 - Double(archiveSize) / Double(totalSize)
        return max(0, min(99, Int(saved * 100)))
    }

    public init(
        url: URL,
        format: ArchiveFormat,
        formatDescription: String,
        entries: [ArchiveEntryInfo],
        archiveSize: Int64,
        hasEncryptedEntries: Bool
    ) {
        self.url = url
        self.format = format
        self.formatDescription = formatDescription
        self.entries = entries
        self.entryCount = entries.count
        self.fileCount = entries.filter { !$0.isDirectory }.count
        self.directoryCount = entries.filter { $0.isDirectory }.count
        self.totalSize = entries.reduce(0) { $0 + ($1.isDirectory ? 0 : max(0, $1.size)) }
        self.archiveSize = archiveSize
        self.hasEncryptedEntries = hasEncryptedEntries
    }
}
