import Foundation
import Darwin
import CArchive

public enum CompressionFormat: String, CaseIterable, Codable, Sendable, Identifiable {
    case zip
    case sevenZip
    case tarGz

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .zip: return "ZIP"
        case .sevenZip: return "7-Zip"
        case .tarGz: return "TAR.GZ"
        }
    }

    public var detail: String {
        switch self {
        case .zip: return "兼容性最好，macOS / Windows 都能直接打开"
        case .sevenZip: return "压缩率最高，适合大文件"
        case .tarGz: return "保留 Unix 权限和符号链接"
        }
    }

    public var fileExtension: String {
        switch self {
        case .zip: return "zip"
        case .sevenZip: return "7z"
        case .tarGz: return "tar.gz"
        }
    }

    public var symbolName: String {
        switch self {
        case .zip: return "doc.zipper"
        case .sevenZip: return "archivebox.fill"
        case .tarGz: return "shippingbox.fill"
        }
    }
}

public struct CompressionOptions: Sendable {
    public var format: CompressionFormat
    /// 0 = store only, 1...9 = increasing compression.
    public var level: Int
    public var includeHiddenFiles: Bool
    public var skipDSStore: Bool
    /// AES-256 password protection (ZIP only; libarchive supports it natively).
    public var password: String?

    public init(
        format: CompressionFormat = .zip,
        level: Int = 6,
        includeHiddenFiles: Bool = true,
        skipDSStore: Bool = true,
        password: String? = nil
    ) {
        self.format = format
        self.level = min(9, max(0, level))
        self.includeHiddenFiles = includeHiddenFiles
        self.skipDSStore = skipDSStore
        self.password = password
    }
}

public struct CompressionResult: Sendable {
    public let destination: URL
    public let filesAdded: Int
    public let inputBytes: Int64
    public let outputBytes: Int64
    public let duration: TimeInterval
}

public enum ArchiveWriter {
    private struct Item {
        var url: URL
        var path: String
        var isDirectory: Bool
        var isSymlink: Bool
        var size: Int64
        var mode: UInt16
        var modified: Date?
    }

    public static func create(
        items: [URL],
        destination: URL,
        options: CompressionOptions,
        progress: ExtractionProgress
    ) throws -> CompressionResult {
        let started = Date()
        let fileManager = FileManager.default
        let resolvedItems = try collectItems(items, destination: destination, options: options)

        let totalBytes = resolvedItems.reduce(Int64(0)) { $0 + $1.size }
        let totalFiles = resolvedItems.filter { !$0.isDirectory }.count
        progress.begin(totalBytes: totalBytes, totalFiles: totalFiles)

        // Never leave a half-written archive behind on failure.
        try? fileManager.removeItem(at: destination)
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var completed = false
        defer {
            if !completed { try? fileManager.removeItem(at: destination) }
        }

        guard let archive = archive_write_new() else {
            throw ArchiveError.writeFailed(reason: "无法创建写入器")
        }
        defer {
            archive_write_close(archive)
            archive_write_free(archive)
        }

        var rc: Int32 = 0
        switch options.format {
        case .zip:
            rc = archive_write_set_format_zip(archive)
            _ = archive_write_add_filter_none(archive)
            if rc == 0 {
                // libarchive does not set ZIP's language-encoding flag on its own,
                // which makes Windows tools display UTF-8 Chinese names as CP437.
                _ = archive_write_set_options(archive, "zip:hdrcharset=UTF-8")
                if options.level == 0 {
                    _ = archive_write_set_options(archive, "zip:compression=store")
                } else {
                    _ = archive_write_set_options(archive, "zip:compression=deflate")
                    _ = archive_write_set_options(archive, "zip:compression-level=\(options.level)")
                }
            }
        case .sevenZip:
            rc = archive_write_set_format_7zip(archive)
            _ = archive_write_add_filter_none(archive)
            if rc == 0 {
                _ = archive_write_set_options(archive, "7zip:compression=lzma2")
                _ = archive_write_set_options(archive, "7zip:compression-level=\(max(1, options.level))")
            }
        case .tarGz:
            rc = archive_write_set_format_pax_restricted(archive)
            _ = archive_write_add_filter_gzip(archive)
            if rc == 0 {
                _ = archive_write_set_options(archive, "gzip:compression-level=\(max(1, options.level))")
            }
        }
        guard rc == 0 else {
            throw ArchiveError.writeFailed(reason: writeError(archive))
        }

        if let password = options.password, !password.isEmpty, options.format == .zip {
            archive_write_set_passphrase(archive, password)
            _ = archive_write_set_options(archive, "zip:encryption=aes256")
        }

        let openResult: Int32 = destination.path.withCString { path in
            archive_write_open_filename(archive, path)
        }
        guard openResult == 0 else {
            throw ArchiveError.writeFailed(reason: writeError(archive))
        }

        var filesAdded = 0
        for item in resolvedItems {
            if progress.isCancelled {
                throw ArchiveError.cancelled
            }
            progress.setCurrent(item.path)

            guard let entry = archive_entry_new() else {
                throw ArchiveError.writeFailed(reason: "无法创建条目")
            }
            defer { archive_entry_free(entry) }

            archive_entry_set_pathname_utf8(entry, item.path)
            archive_entry_set_perm(entry, mode_t(item.mode & 0o777))
            if let modified = item.modified {
                archive_entry_set_mtime(entry, time_t(modified.timeIntervalSince1970), 0)
            }

            if item.isSymlink {
                let target = try? fileManager.destinationOfSymbolicLink(atPath: item.url.path)
                archive_entry_set_filetype(entry, 0o120000)
                archive_entry_set_size(entry, 0)
                if let target { archive_entry_set_symlink_utf8(entry, target) }
                let headerResult = archive_write_header(archive, entry)
                if headerResult < 0 {
                    throw ArchiveError.writeFailed(reason: writeError(archive))
                }
                filesAdded += 1
                progress.fileFinished()
                continue
            }

            if item.isDirectory {
                archive_entry_set_filetype(entry, 0o040000)
                archive_entry_set_size(entry, 0)
                let headerResult = archive_write_header(archive, entry)
                if headerResult < 0 {
                    throw ArchiveError.writeFailed(reason: writeError(archive))
                }
                filesAdded += 1
                progress.fileFinished()
                continue
            }

            archive_entry_set_filetype(entry, 0o100000)
            archive_entry_set_size(entry, item.size)
            let headerResult = archive_write_header(archive, entry)
            if headerResult < 0 {
                throw ArchiveError.writeFailed(reason: writeError(archive))
            }

            let handle = try FileHandle(forReadingFrom: item.url)
            defer { try? handle.close() }
            var copied: Int64 = 0
            while true {
                if progress.isCancelled { throw ArchiveError.cancelled }
                let chunk = try handle.read(upToCount: 256 * 1024) ?? Data()
                if chunk.isEmpty { break }
                var sent = 0
                while sent < chunk.count {
                    let written = chunk.withUnsafeBytes { raw -> Int in
                        guard let base = raw.baseAddress else { return 0 }
                        return archive_write_data(archive, base.advanced(by: sent), raw.count - sent)
                    }
                    if written <= 0 {
                        throw ArchiveError.writeFailed(reason: writeError(archive))
                    }
                    sent += written
                }
                copied += Int64(sent)
                progress.addBytes(sent)
            }
            if copied != item.size {
                // File changed while compressing; the archive is still valid but
                // the header size may be wrong. Report instead of silently corrupting.
                throw ArchiveError.writeFailed(reason: "文件在压缩过程中被修改：\(item.path)")
            }
            filesAdded += 1
            progress.fileFinished()
        }

        let closeResult = archive_write_close(archive)
        guard closeResult == 0 else {
            throw ArchiveError.writeFailed(reason: writeError(archive))
        }
        let attributes = try? fileManager.attributesOfItem(atPath: destination.path)
        let outputSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0

        completed = true
        return CompressionResult(
            destination: destination,
            filesAdded: filesAdded,
            inputBytes: totalBytes,
            outputBytes: outputSize,
            duration: Date().timeIntervalSince(started)
        )
    }

    // MARK: - Walking

    private static func collectItems(
        _ urls: [URL],
        destination: URL,
        options: CompressionOptions
    ) throws -> [Item] {
        let fileManager = FileManager.default
        var items: [Item] = []
        let destinationPath = destination.standardizedFileURL.path

        func makeItem(url: URL, path: String) throws -> Item? {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let attributes = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
            let isSymlink = values.isSymbolicLink ?? false
            let isDirectory = (values.isDirectory ?? false) && !isSymlink
            let size = isDirectory || isSymlink ? 0 : ((attributes[.size] as? NSNumber)?.int64Value ?? 0)
            let mode = UInt16(((attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? (isDirectory ? 0o755 : 0o644)) & 0o7777)
            return Item(
                url: url,
                path: path,
                isDirectory: isDirectory,
                isSymlink: isSymlink,
                size: size,
                mode: mode,
                modified: attributes[.modificationDate] as? Date
            )
        }

        for root in urls {
            let rootName = root.lastPathComponent
            guard !rootName.isEmpty else { continue }
            let rootValues = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let rootIsDirectory = (rootValues.isDirectory ?? false) && !(rootValues.isSymbolicLink ?? false)

            if rootIsDirectory {
                if let item = try makeItem(url: root, path: rootName) { items.append(item) }
                guard let enumerator = fileManager.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                    options: [],
                    errorHandler: { _, _ in true }
                ) else { continue }
                while let child = enumerator.nextObject() as? URL {
                    if child.standardizedFileURL.path == destinationPath { continue }
                    let relative = child.path.replacingOccurrences(of: root.path + "/", with: "")
                    if !options.includeHiddenFiles, relative.split(separator: "/").contains(where: { $0.hasPrefix(".") }) {
                        continue
                    }
                    if options.skipDSStore, child.lastPathComponent == ".DS_Store" { continue }
                    if let item = try makeItem(url: child, path: rootName + "/" + relative) {
                        items.append(item)
                    }
                }
            } else {
                if root.standardizedFileURL.path == destinationPath { continue }
                if options.skipDSStore, root.lastPathComponent == ".DS_Store" { continue }
                if let item = try makeItem(url: root, path: rootName) { items.append(item) }
            }
        }

        // Sorted output makes archives reproducible and easier to browse.
        items.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        return items
    }

    private static func writeError(_ archive: OpaquePointer) -> String {
        if let pointer = archive_error_string(archive) {
            let message = String(cString: pointer)
            if !message.isEmpty { return message }
        }
        return "写入压缩包失败"
    }
}
