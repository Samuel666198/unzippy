import Foundation
import Darwin
import CArchive

public enum ArchiveExtractor {
    private static let eof: Int32 = 1
    private static let warn: Int32 = -20

    public static func extract(_ request: ExtractionRequest, progress: ExtractionProgress) throws -> ExtractionResult {
        let started = Date()
        let fileManager = FileManager.default
        let destination = request.destination.standardizedFileURL
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let rootReal = destination.resolvingSymlinksInPath().standardizedFileURL.path

        let options = request.options
        let selected = options.selectedIndices
        let isSelected: (Int) -> Bool = { index in selected?.contains(index) ?? true }

        let selectedEntries = request.entries.enumerated().filter { isSelected($0.offset) }.map { $0.element }
        let totalFiles = selectedEntries.filter { !$0.isDirectory }.count
        let totalBytes = selectedEntries.reduce(Int64(0)) { $0 + ($1.isDirectory ? 0 : max(0, $1.size)) }
        progress.begin(totalBytes: totalBytes, totalFiles: totalFiles)

        let reader = try ArchiveReader(
            url: request.archiveURL,
            password: options.password,
            encoding: options.encoding
        )
        guard let archive = reader.rawHandle else {
            throw ArchiveError.openFailed(reason: "读取器已关闭")
        }

        var filesWritten = 0
        var directoriesCreated = 0
        var bytesWritten: Int64 = 0
        var skipped = 0
        var warnings: [String] = []
        var directoryAttributes: [(url: URL, mode: UInt16, date: Date?)] = []
        var headerIndex = 0

        func note(_ message: String) {
            if warnings.count < 200 { warnings.append(message) }
        }

        while true {
            if progress.isCancelled { throw ArchiveError.cancelled }
            var entryPointer: OpaquePointer?
            let result = archive_read_next_header(archive, &entryPointer)
            if result == eof { break }
            if result == warn {
                if entryPointer == nil { continue }
            } else if result < 0 {
                throw ArchiveReader.mapError(
                    ArchiveReader.errorString(archive),
                    hasPassword: options.password?.isEmpty == false
                )
            }
            guard let entry = entryPointer else { continue }

            let index = headerIndex
            headerIndex += 1
            let info = index < request.entries.count ? request.entries[index] : nil
            let rawPath = info?.path ?? ArchiveReader.path(of: entry)

            defer { archive_read_data_skip(archive) }

            guard isSelected(index) else { continue }
            // ISO images carry a "." root entry; it is not a real filesystem item.
            if rawPath == "." || rawPath == "./" { continue }
            guard let components = SafePath.components(for: rawPath) else {
                skipped += 1
                note("已跳过不安全路径：\(rawPath)")
                continue
            }
            if options.skipMacOSXMetadata, components.first == "__MACOSX" {
                skipped += 1
                continue
            }

            let relativePath = components.joined(separator: "/")
            var targetURL = destination
            for component in components {
                targetURL.appendPathComponent(component, isDirectory: false)
            }

            let fileType = archive_entry_filetype(entry)
            let isDirectory = fileType == 0o040000 || (info?.isDirectory ?? false) || rawPath.hasSuffix("/")
            let isSymlink = fileType == 0o120000 || (info?.isSymlink ?? false)

            progress.setCurrent(relativePath)

            if isDirectory {
                do {
                    try ensureParentDirectory(of: targetURL, rootReal: rootReal)
                    var isDirectoryOnDisk: ObjCBool = false
                    if fileManager.fileExists(atPath: targetURL.path, isDirectory: &isDirectoryOnDisk) {
                        if !isDirectoryOnDisk.boolValue {
                            if options.conflictPolicy == .skip { skipped += 1; continue }
                            try fileManager.removeItem(at: targetURL)
                            try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
                            directoriesCreated += 1
                        }
                    } else {
                        try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
                        directoriesCreated += 1
                    }
                    directoryAttributes.append((targetURL, info?.permissions ?? 0o755, info?.modified))
                } catch {
                    note("无法创建目录 \(relativePath)：\(error.localizedDescription)")
                    skipped += 1
                }
                continue
            }

            if isSymlink {
                let linkTarget = info?.linkTarget
                    ?? ArchiveReader.string(archive_entry_symlink_utf8(entry))
                    ?? ArchiveReader.string(archive_entry_symlink(entry))
                guard options.extractSymlinks, let linkTarget,
                      SafePath.isSafeSymlinkTarget(linkTarget, relativePath: relativePath) else {
                    skipped += 1
                    continue
                }
                do {
                    try ensureParentDirectory(of: targetURL, rootReal: rootReal)
                    removeExistingIfNeeded(at: targetURL, policy: options.conflictPolicy)
                    try fileManager.createSymbolicLink(atPath: targetURL.path, withDestinationPath: linkTarget)
                    filesWritten += 1
                    progress.fileFinished()
                } catch {
                    skipped += 1
                    note("无法创建符号链接 \(relativePath)：\(error.localizedDescription)")
                }
                continue
            }

            if let hardlinkTarget = info?.hardlinkTarget
                ?? ArchiveReader.string(archive_entry_hardlink_utf8(entry))
                ?? ArchiveReader.string(archive_entry_hardlink(entry)) {
                guard let targetComponents = SafePath.components(for: hardlinkTarget) else {
                    skipped += 1
                    continue
                }
                var sourceURL = destination
                for component in targetComponents { sourceURL.appendPathComponent(component) }
                let sourceReal = sourceURL.resolvingSymlinksInPath().standardizedFileURL.path
                guard sourceReal.hasPrefix(rootReal + "/"), fileManager.fileExists(atPath: sourceReal) else {
                    skipped += 1
                    note("硬链接目标不存在：\(hardlinkTarget)")
                    continue
                }
                do {
                    try ensureParentDirectory(of: targetURL, rootReal: rootReal)
                    removeExistingIfNeeded(at: targetURL, policy: options.conflictPolicy)
                    try fileManager.linkItem(atPath: sourceReal, toPath: targetURL.path)
                    filesWritten += 1
                    progress.fileFinished()
                } catch {
                    skipped += 1
                    note("无法创建硬链接 \(relativePath)：\(error.localizedDescription)")
                }
                continue
            }

            guard fileType == 0o100000 || fileType == 0 else {
                skipped += 1
                continue
            }

            // Resolve conflicts before opening the file so UI decisions stay predictable.
            do {
                try ensureParentDirectory(of: targetURL, rootReal: rootReal)
                guard let finalURL = try resolveConflict(at: targetURL, policy: options.conflictPolicy, isDirectory: false) else {
                    skipped += 1
                    continue
                }
                targetURL = finalURL

                let fd = open(targetURL.path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0o600)
                guard fd >= 0 else {
                    throw ArchiveError.writeFailed(reason: "\(targetURL.lastPathComponent)：\(String(cString: strerror(errno)))")
                }
                var writeError: Error?
                var localBytes: Int64 = 0
                while true {
                    if progress.isCancelled {
                        close(fd)
                        throw ArchiveError.cancelled
                    }
                    var buffer: UnsafeRawPointer?
                    var size: Int = 0
                    var offset: Int64 = 0
                    let readResult = archive_read_data_block(archive, &buffer, &size, &offset)
                    if readResult == eof { break }
                    if readResult < 0 {
                        writeError = ArchiveReader.mapError(
                            ArchiveReader.errorString(archive),
                            hasPassword: options.password?.isEmpty == false
                        )
                        break
                    }
                    guard let buffer, size > 0 else { continue }
                    var written = 0
                    while written < size {
                        let count = write(fd, buffer + written, size - written)
                        if count < 0 {
                            if errno == EINTR { continue }
                            writeError = errno == ENOSPC
                                ? ArchiveError.noSpace
                                : ArchiveError.writeFailed(reason: String(cString: strerror(errno)))
                            break
                        }
                        written += count
                    }
                    if writeError != nil { break }
                    progress.addBytes(size)
                    localBytes += Int64(size)
                }
                close(fd)
                if let writeError {
                    try? fileManager.removeItem(at: targetURL)
                    throw writeError
                }

                applyAttributes(
                    to: targetURL,
                    mode: info?.permissions ?? 0o644,
                    date: info?.modified,
                    preservePermissions: options.preservePermissions
                )
                if options.removeQuarantine {
                    targetURL.path.withCString { path in
                        _ = removexattr(path, "com.apple.quarantine", 0)
                    }
                }
                filesWritten += 1
                bytesWritten += localBytes
                progress.fileFinished()
            } catch let error as ArchiveError {
                switch error {
                case .cancelled, .passwordRequired, .wrongPassword, .noSpace:
                    throw error
                default:
                    break
                }
                skipped += 1
                note(error.localizedDescription)
            } catch {
                skipped += 1
                note("写入 \(relativePath) 失败：\(error.localizedDescription)")
            }
        }

        // Apply directory metadata last (deepest first) so restrictive modes do
        // not block files that still need to be written inside.
        for item in directoryAttributes.sorted(by: { $0.url.path.count > $1.url.path.count }) {
            applyAttributes(
                to: item.url,
                mode: item.mode,
                date: item.date,
                preservePermissions: options.preservePermissions
            )
        }

        return ExtractionResult(
            destination: destination,
            filesWritten: filesWritten,
            directoriesCreated: directoriesCreated,
            bytesWritten: bytesWritten,
            skipped: skipped,
            warnings: warnings,
            duration: Date().timeIntervalSince(started)
        )
    }

    // MARK: - Helpers

    private static func ensureParentDirectory(of url: URL, rootReal: String) throws {
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let real = parent.resolvingSymlinksInPath().standardizedFileURL.path
        guard real == rootReal || real.hasPrefix(rootReal + "/") else {
            throw ArchiveError.unsafeEntry(path: url.lastPathComponent, reason: "符号链接指向解压目录之外")
        }
    }

    private static func removeExistingIfNeeded(at url: URL, policy: ConflictPolicy) {
        var status = stat()
        guard lstat(url.path, &status) == 0 else { return }
        if policy == .skip { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Returns the final URL, or nil when the entry should be skipped.
    private static func resolveConflict(at url: URL, policy: ConflictPolicy, isDirectory: Bool) throws -> URL? {
        var status = stat()
        guard lstat(url.path, &status) == 0 else { return url }
        switch policy {
        case .skip:
            return nil
        case .replace:
            if (status.st_mode & S_IFMT) == S_IFDIR {
                // Never delete a user folder to make room for a file.
                throw ArchiveError.writeFailed(reason: "同名目录已存在：\(url.lastPathComponent)")
            }
            guard unlink(url.path) == 0 else {
                throw ArchiveError.writeFailed(reason: String(cString: strerror(errno)))
            }
            return url
        case .rename:
            let directory = url.deletingLastPathComponent()
            let name = url.lastPathComponent
            let ext = (name as NSString).pathExtension
            let base = (name as NSString).deletingPathExtension
            for counter in 2...9999 {
                let candidateName = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
                let candidate = directory.appendingPathComponent(candidateName)
                if lstat(candidate.path, &status) != 0 { return candidate }
            }
            throw ArchiveError.writeFailed(reason: "无法为 \(name) 生成可用文件名")
        }
    }

    private static func applyAttributes(to url: URL, mode: UInt16, date: Date?, preservePermissions: Bool) {
        var attributes: [FileAttributeKey: Any] = [:]
        if preservePermissions {
            let permission = mode & 0o777
            if permission != 0 {
                attributes[.posixPermissions] = NSNumber(value: permission)
            }
        }
        if let date { attributes[.modificationDate] = date }
        if !attributes.isEmpty {
            try? FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
        }
    }
}

public enum ExtractionPlanner {
    /// The folder name an archive suggests, e.g. "photos.tar.gz" -> "photos".
    public static func baseName(for archiveURL: URL) -> String {
        var name = archiveURL.lastPathComponent
        let lower = name.lowercased()
        let suffixes = [".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst", ".tgz", ".tbz2", ".tbz", ".txz", ".tzst",
                        ".zip", ".7z", ".rar", ".tar", ".gz", ".bz2", ".xz", ".zst", ".iso", ".cab", ".pkg", ".jar"]
        for suffix in suffixes where lower.hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
            break
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "解压文件" : trimmed
    }

    /// Picks a non-existing destination folder (or the base itself).
    public static func destinationFolder(base: URL, archiveURL: URL, createSubfolder: Bool) -> URL {
        guard createSubfolder else { return base }
        let folderName = baseName(for: archiveURL)
        var candidate = base.appendingPathComponent(folderName, isDirectory: true)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = base.appendingPathComponent("\(folderName) (\(counter))", isDirectory: true)
            counter += 1
        }
        return candidate
    }
}
