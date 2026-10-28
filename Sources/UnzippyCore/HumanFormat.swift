import Foundation

public enum HumanFormat {
    public static func bytes(_ value: Int64) -> String {
        if value < 0 { return "—" }
        if value < 1000 { return "\(value) B" }
        let units = ["KB", "MB", "GB", "TB", "PB"]
        var amount = Double(value) / 1000
        var index = 0
        while amount >= 1000, index < units.count - 1 {
            amount /= 1000
            index += 1
        }
        if amount >= 100 {
            return String(format: "%.0f %@", amount, units[index])
        } else if amount >= 10 {
            return String(format: "%.1f %@", amount, units[index])
        } else {
            return String(format: "%.2f %@", amount, units[index])
        }
    }

    public static func speed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "—" }
        return bytes(Int64(bytesPerSecond)) + "/s"
    }

    public static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        if seconds < 1 { return "不到 1 秒" }
        if seconds < 60 { return "\(Int(seconds)) 秒" }
        let minutes = Int(seconds) / 60
        let remainder = Int(seconds) % 60
        if minutes < 60 { return remainder == 0 ? "\(minutes) 分钟" : "\(minutes) 分 \(remainder) 秒" }
        let hours = minutes / 60
        return "\(hours) 小时 \(minutes % 60) 分"
    }

    public static func date(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .numeric, time: .shortened)
    }

    public static func compactDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
