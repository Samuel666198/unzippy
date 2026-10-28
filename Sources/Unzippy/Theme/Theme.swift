import SwiftUI
import UnzippyCore

enum Theme {
    static let accent = Color(red: 0.10, green: 0.64, blue: 0.53)
    static let accentBright = Color(red: 0.30, green: 0.84, blue: 0.67)
    static let accentDeep = Color(red: 0.03, green: 0.32, blue: 0.29)
    static let amber = Color(red: 0.95, green: 0.62, blue: 0.27)
    static let rose = Color(red: 0.90, green: 0.36, blue: 0.48)
    static let indigo = Color(red: 0.42, green: 0.48, blue: 0.94)
    static let slate = Color(red: 0.36, green: 0.44, blue: 0.52)

    static let hairline = Color.primary.opacity(0.07)
    static let subtleFill = Color.primary.opacity(0.035)
    static let cardFill = Color(nsColor: .controlBackgroundColor)
}

extension ArchiveFormat {
    var tint: Color {
        switch self {
        case .zip: return Theme.amber
        case .sevenZip: return Theme.indigo
        case .rar: return Theme.rose
        case .tar, .tarGz, .tarBz2, .tarXz, .tarZst: return Theme.accent
        case .gzip, .bzip2, .xz, .zstd: return Color(red: 0.30, green: 0.66, blue: 0.44)
        case .iso: return Color(red: 0.36, green: 0.55, blue: 0.78)
        case .cab: return Theme.slate
        case .cpio, .xar, .lha: return Theme.slate
        case .other: return Theme.slate
        }
    }
}

extension CompressionFormat {
    var tint: Color {
        switch self {
        case .zip: return Theme.amber
        case .sevenZip: return Theme.indigo
        case .tarGz: return Theme.accent
        }
    }
}

extension JobState {
    var tint: Color {
        switch self {
        case .waiting: return .secondary
        case .inspecting: return Theme.indigo
        case .ready: return Theme.accent
        case .extracting: return Theme.accent
        case .done: return Color(red: 0.25, green: 0.68, blue: 0.42)
        case .failed: return Theme.rose
        case .cancelled: return .secondary
        }
    }
}

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
