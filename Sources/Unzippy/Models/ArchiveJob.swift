import Foundation
import UnzippyCore

enum JobState: String, Sendable {
    case waiting
    case inspecting
    case ready
    case extracting
    case done
    case failed
    case cancelled

    var label: String {
        switch self {
        case .waiting: return "待解压"
        case .inspecting: return "正在读取"
        case .ready: return "就绪"
        case .extracting: return "解压中"
        case .done: return "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }

    var isActive: Bool {
        self == .extracting || self == .inspecting
    }
}

struct ArchiveJob: Identifiable, Sendable {
    let id = UUID()
    var url: URL
    var format: ArchiveFormat
    var size: Int64
    var state: JobState = .waiting
    var fraction: Double = 0
    var bytesDone: Int64 = 0
    var bytesTotal: Int64 = 0
    var filesDone: Int = 0
    var filesTotal: Int = 0
    var speed: Double = 0
    var eta: TimeInterval?
    var destination: URL?
    var errorMessage: String?
    var entryCount: Int?
    var totalUncompressed: Int64?
    var isEncrypted: Bool = false
    var password: String?
    var encoding: FilenameEncoding = Prefs.encoding
    var startedAt: Date?
    var finishedAt: Date?
    var skippedCount: Int = 0

    var name: String { url.lastPathComponent }
    var folder: String { url.deletingLastPathComponent().path }
    var hasSummary: Bool { entryCount != nil }
    var isFinished: Bool { state == .done || state == .cancelled || state == .failed }
}
