import Foundation
import CArchive

/// Streaming reader built on the libarchive that ships with macOS.
/// One instance is single-use for iteration; open a fresh reader for each pass.
public final class ArchiveReader {
    private var handle: OpaquePointer?
    /// Internal access for the extractor (same module only).
    var rawHandle: OpaquePointer? { handle }
    private let url: URL
    public let password: String?
    public let encoding: FilenameEncoding
    public private(set) var format: ArchiveFormat
    public private(set) var formatDescription: String = ""
    public private(set) var warnings: [String] = []
    public private(set) var hasEncryptedEntries: Bool = false

    private let eof: Int32 = 1 // ARCHIVE_EOF
    private let warn: Int32 = -20 // ARCHIVE_WARN

    public init(url: URL, password: String? = nil, encoding: FilenameEncoding = .automatic) throws {
        guard Self.fileSize(url) > 0 else {
            throw ArchiveError.notAnArchive
        }
        self.url = url
        self.password = password
        self.encoding = encoding
        self.format = ArchiveFormat.detect(url: url)

        guard let archive = archive_read_new() else {
            throw ArchiveError.openFailed(reason: "无法创建读取器")
        }
        self.handle = archive

        archive_read_support_filter_all(archive)
        archive_read_support_format_all(archive)
        archive_read_support_format_raw(archive)
        archive_read_support_format_empty(archive)

        if let password, !password.isEmpty {
            archive_read_add_passphrase(archive, password)
        }

        let openResult: Int32 = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return -1 }
            return archive_read_open_filename(archive, path, 256 * 1024)
        }
        guard openResult == 0 else {
            let message = Self.errorString(archive)
            if let handle { archive_read_free(handle) }
            self.handle = nil
            throw Self.mapError(message, hasPassword: password?.isEmpty == false)
        }
    }

    deinit {
        if let handle {
            archive_read_close(handle)
            archive_read_free(handle)
        }
    }

    /// Reads the complete entry list and returns a summary.
    public func listEntries(progress: ((Int) -> Void)? = nil) throws -> ArchiveSummary {
        guard let archive = handle else { throw ArchiveError.openFailed(reason: "读取器已关闭") }
        var entries: [ArchiveEntryInfo] = []
        entries.reserveCapacity(512)
        var index = 0

        while true {
            var entryPointer: OpaquePointer?
            let result = archive_read_next_header(archive, &entryPointer)
            if result == eof { break }
            if result == warn {
                warnings.append(Self.errorString(archive))
                if entryPointer == nil { continue }
            } else if result < 0 {
                throw Self.mapError(Self.errorString(archive), hasPassword: password?.isEmpty == false)
            }
            guard let entry = entryPointer else { continue }

            let fileType = archive_entry_filetype(entry)
            let isDirectory = fileType == 0o040000 || Self.isDirectoryPath(Self.path(of: entry))
            let isSymlink = fileType == 0o120000
            let size = max(0, archive_entry_size(entry))
            var modified: Date?
            if archive_entry_mtime_is_set(entry) != 0 {
                modified = Date(timeIntervalSince1970: TimeInterval(archive_entry_mtime(entry)))
            }
            var permissions = UInt16(archive_entry_perm(entry)) & 0o7777
            if permissions & 0o777 == 0 {
                permissions = isDirectory ? 0o755 : 0o644
            }
            let link = Self.string(archive_entry_symlink_utf8(entry)) ?? Self.string(archive_entry_symlink(entry))
            let hardlink = Self.string(archive_entry_hardlink_utf8(entry)) ?? Self.string(archive_entry_hardlink(entry))

            entries.append(
                ArchiveEntryInfo(
                    index: index,
                    path: Self.path(of: entry),
                    isDirectory: isDirectory,
                    isSymlink: isSymlink,
                    size: size,
                    compressedSize: 0,
                    modified: modified,
                    permissions: permissions,
                    linkTarget: link,
                    hardlinkTarget: hardlink
                )
            )
            index += 1
            if index % 200 == 0 { progress?(index) }
            archive_read_data_skip(archive)
        }

        // Format metadata is only reliable after headers have been read.
        let formatName = Self.errorStringSafe(archive_format_name(archive))
        let filterName = Self.errorStringSafe(archive_filter_name(archive, 0))
        let filterCount = Int(archive_filter_count(archive))
        if !formatName.isEmpty {
            format = ArchiveFormat.from(libarchiveName: formatName, url: url)
            formatDescription = Self.describe(format: formatName, filter: filterName)
        }
        if archive_read_has_encrypted_entries(archive) == 1 {
            hasEncryptedEntries = true
        }
        progress?(entries.count)

        // libarchive's "raw" reader happily accepts any byte stream. Only keep
        // it when there is a real compression filter (gz/bz2/xz/zst); otherwise
        // dragging a .txt or a corrupt zip would produce a bogus one-file archive.
        if formatName.lowercased() == "raw", filterCount <= 1 {
            throw ArchiveError.notAnArchive
        }
        guard !entries.isEmpty || !formatName.isEmpty else {
            throw ArchiveError.notAnArchive
        }

        var repaired = entries
        repairNames(&repaired)
        if format == .zip {
            mergeZipSizesAndNames(&repaired)
        }
        applyRawNameHint(&repaired)
        applyFilenameRepair(&repaired)

        return ArchiveSummary(
            url: url,
            format: format,
            formatDescription: formatDescription,
            entries: repaired,
            archiveSize: Self.fileSize(url),
            hasEncryptedEntries: hasEncryptedEntries
        )
    }

    // MARK: - Name handling

    private func repairNames(_ entries: inout [ArchiveEntryInfo]) {
        // libarchive hands us NUL-terminated strings; make sure no embedded
        // control characters survive into file paths.
        for i in entries.indices {
            entries[i].path = Self.cleanPath(entries[i].path)
        }
    }

    private func mergeZipSizesAndNames(_ entries: inout [ArchiveEntryInfo]) {
        guard let rawEntries = ZipCentralDirectory.read(url: url), rawEntries.count == entries.count else {
            return
        }
        for i in entries.indices {
            let raw = rawEntries[i]
            if let decoded = ZipCentralDirectory.decodeName(raw, encoding: encoding), !decoded.isEmpty {
                entries[i].path = Self.cleanPath(decoded)
                entries[i].isDirectory = entries[i].isDirectory || decoded.hasSuffix("/")
            }
            entries[i].compressedSize = Int64(clamping: raw.compressedSize)
            if entries[i].size == 0, raw.uncompressedSize > 0 {
                entries[i].size = Int64(clamping: raw.uncompressedSize)
            }
        }
    }

    private func applyRawNameHint(_ entries: inout [ArchiveEntryInfo]) {
        guard format.isRawStream, entries.count == 1, entries[0].path == "data" else { return }
        var name = url.lastPathComponent
        for suffix in [".gz", ".gzip", ".bz2", ".bzip2", ".xz", ".lzma", ".zst", ".zstd"] {
            if name.lowercased().hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count))
                break
            }
        }
        if name.isEmpty { name = "解压结果" }
        entries[0].path = name
        entries[0].isDirectory = false
    }

    private func applyFilenameRepair(_ entries: inout [ArchiveEntryInfo]) {
        guard format != .zip else { return } // ZIP names come from the central directory
        for i in entries.indices {
            if let repaired = FilenameRepair.autoRepair(entries[i].path, encoding: encoding) {
                entries[i].path = Self.cleanPath(repaired)
            }
        }
    }

    // MARK: - Diagnostics

    public static func debugZipEntryNames(url: URL, encoding: FilenameEncoding = .automatic) -> [String] {
        guard let raw = ZipCentralDirectory.read(url: url) else { return ["<central directory parse failed>"] }
        return raw.map { ZipCentralDirectory.decodeName($0, encoding: encoding) ?? "<decode failed>" }
    }

    // MARK: - Helpers

    static func path(of entry: OpaquePointer) -> String {
        string(archive_entry_pathname_utf8(entry))
            ?? string(archive_entry_pathname(entry))
            ?? ""
    }

    static func string(_ pointer: UnsafePointer<CChar>?) -> String? {
        guard let pointer else { return nil }
        return String(validatingUTF8: pointer)
    }

    static func errorString(_ archive: OpaquePointer) -> String {
        if let cString = archive_error_string(archive) {
            let message = String(cString: cString)
            if !message.isEmpty { return message }
        }
        return "未知错误 (errno \(archive_errno(archive)))"
    }

    static func errorStringSafe(_ pointer: UnsafePointer<CChar>?) -> String {
        guard let pointer else { return "" }
        return String(cString: pointer)
    }

    static func describe(format: String, filter: String) -> String {
        var parts = [format]
        if !filter.isEmpty, filter.lowercased() != "none" {
            parts.append(filter)
        }
        return parts.joined(separator: " · ")
    }

    static func cleanPath(_ path: String) -> String {
        var cleaned = path
        while cleaned.hasPrefix("./") { cleaned.removeFirst(2) }
        cleaned = cleaned.replacingOccurrences(of: "\\", with: "/")
        return cleaned
    }

    static func isDirectoryPath(_ path: String) -> Bool {
        path.hasSuffix("/")
    }

    static func fileSize(_ url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    static func mapError(_ message: String, hasPassword: Bool) -> ArchiveError {
        let lower = message.lowercased()
        if lower.contains("passphrase") || lower.contains("password") || lower.contains("encrypted") {
            return hasPassword ? .wrongPassword : .passwordRequired
        }
        if lower.contains("zstd") {
            return .unsupportedFormat("ZSTD（系统未内置解码器）")
        }
        if lower.contains("unrecognized archive format") || lower.contains("not an archive") {
            return .notAnArchive
        }
        if lower.contains("truncated") || lower.contains("corrupt") || lower.contains("invalid") {
            return .readFailed(reason: message)
        }
        return .openFailed(reason: message)
    }
}
