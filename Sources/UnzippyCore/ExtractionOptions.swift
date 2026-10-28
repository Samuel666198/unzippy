import Foundation

public enum ConflictPolicy: String, CaseIterable, Codable, Sendable, Identifiable {
    case rename
    case replace
    case skip

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .rename: return "保留两者（自动重命名）"
        case .replace: return "覆盖已有文件"
        case .skip: return "跳过已有文件"
        }
    }

    public var shortName: String {
        switch self {
        case .rename: return "重命名"
        case .replace: return "覆盖"
        case .skip: return "跳过"
        }
    }
}

public struct ExtractionOptions: Sendable {
    public var password: String?
    public var encoding: FilenameEncoding
    public var conflictPolicy: ConflictPolicy
    public var preservePermissions: Bool
    public var extractSymlinks: Bool
    public var skipMacOSXMetadata: Bool
    public var removeQuarantine: Bool
    /// `nil` means "everything".
    public var selectedIndices: Set<Int>?

    public init(
        password: String? = nil,
        encoding: FilenameEncoding = .automatic,
        conflictPolicy: ConflictPolicy = .rename,
        preservePermissions: Bool = true,
        extractSymlinks: Bool = true,
        skipMacOSXMetadata: Bool = true,
        removeQuarantine: Bool = true,
        selectedIndices: Set<Int>? = nil
    ) {
        self.password = password
        self.encoding = encoding
        self.conflictPolicy = conflictPolicy
        self.preservePermissions = preservePermissions
        self.extractSymlinks = extractSymlinks
        self.skipMacOSXMetadata = skipMacOSXMetadata
        self.removeQuarantine = removeQuarantine
        self.selectedIndices = selectedIndices
    }
}

public struct ExtractionRequest: Sendable {
    public var archiveURL: URL
    public var destination: URL
    public var entries: [ArchiveEntryInfo]
    public var options: ExtractionOptions

    public init(archiveURL: URL, destination: URL, entries: [ArchiveEntryInfo], options: ExtractionOptions) {
        self.archiveURL = archiveURL
        self.destination = destination
        self.entries = entries
        self.options = options
    }
}

public struct ExtractionResult: Sendable {
    public let destination: URL
    public let filesWritten: Int
    public let directoriesCreated: Int
    public let bytesWritten: Int64
    public let skipped: Int
    public let warnings: [String]
    public let duration: TimeInterval
}

/// Thread-safe progress channel polled by the UI at ~10 Hz.
public final class ExtractionProgress: @unchecked Sendable {
    public struct Snapshot: Sendable {
        public let totalBytes: Int64
        public let writtenBytes: Int64
        public let totalFiles: Int
        public let filesDone: Int
        public let currentPath: String
        public let speed: Double
        public let elapsed: TimeInterval
        public let cancelled: Bool

        public var fraction: Double {
            if totalBytes > 0 { return min(0.999, max(0, Double(writtenBytes) / Double(totalBytes))) }
            if totalFiles > 0 { return min(0.999, Double(filesDone) / Double(totalFiles)) }
            return 0
        }

        public var estimatedRemaining: TimeInterval? {
            guard totalBytes > 0, speed > 1 else { return nil }
            return max(0, Double(totalBytes - writtenBytes) / speed)
        }
    }

    private let lock = NSLock()
    private var totalBytes: Int64 = 0
    private var writtenBytes: Int64 = 0
    private var totalFiles: Int = 0
    private var filesDone: Int = 0
    private var currentPath: String = ""
    private var startedAt = Date()
    private var cancelled = false
    private var sampleTime = Date()
    private var sampleBytes: Int64 = 0
    private var speed: Double = 0

    public init() {}

    public func begin(totalBytes: Int64, totalFiles: Int) {
        lock.lock()
        self.totalBytes = max(0, totalBytes)
        self.writtenBytes = 0
        self.totalFiles = totalFiles
        self.filesDone = 0
        self.currentPath = ""
        self.startedAt = Date()
        self.sampleTime = Date()
        self.sampleBytes = 0
        self.speed = 0
        self.cancelled = false
        lock.unlock()
    }

    public func addBytes(_ count: Int) {
        lock.lock()
        writtenBytes += Int64(count)
        lock.unlock()
    }

    public func fileFinished() {
        lock.lock()
        filesDone += 1
        lock.unlock()
    }

    public func setCurrent(_ path: String) {
        lock.lock()
        currentPath = path
        lock.unlock()
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    public func snapshot() -> Snapshot {
        lock.lock()
        let now = Date()
        let interval = now.timeIntervalSince(sampleTime)
        if interval > 0.4 {
            let delta = writtenBytes - sampleBytes
            let instant = Double(delta) / interval
            speed = speed == 0 ? instant : speed * 0.6 + instant * 0.4
            sampleTime = now
            sampleBytes = writtenBytes
        }
        let snapshot = Snapshot(
            totalBytes: totalBytes,
            writtenBytes: writtenBytes,
            totalFiles: totalFiles,
            filesDone: filesDone,
            currentPath: currentPath,
            speed: speed,
            elapsed: now.timeIntervalSince(startedAt),
            cancelled: cancelled
        )
        lock.unlock()
        return snapshot
    }
}
