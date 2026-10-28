import Foundation

public enum ArchiveError: LocalizedError, Equatable {
    case notAnArchive
    case passwordRequired
    case wrongPassword
    case unsupportedFormat(String)
    case openFailed(reason: String)
    case readFailed(reason: String)
    case writeFailed(reason: String)
    case unsafeEntry(path: String, reason: String)
    case destinationUnavailable(path: String)
    case cancelled
    case noSpace

    public var errorDescription: String? {
        switch self {
        case .notAnArchive:
            return "不是可识别的压缩文件"
        case .passwordRequired:
            return "这个压缩包需要密码"
        case .wrongPassword:
            return "密码不正确"
        case .unsupportedFormat(let name):
            return "暂不支持 \(name)"
        case .openFailed(let reason):
            return "无法打开压缩包：\(reason)"
        case .readFailed(let reason):
            return "读取失败：\(reason)"
        case .writeFailed(let reason):
            return "写入失败：\(reason)"
        case .unsafeEntry(let path, let reason):
            return "跳过不安全的条目 \(path)：\(reason)"
        case .destinationUnavailable(let path):
            return "目标位置不可用：\(path)"
        case .cancelled:
            return "已取消"
        case .noSpace:
            return "磁盘空间不足"
        }
    }
}
