import Foundation
import CoreFoundation

/// How filenames inside an archive should be interpreted. ZIP files produced on
/// Chinese Windows usually store GBK bytes without the UTF-8 flag; libarchive
/// falls back to CP437 for those, which turns 中文 into ╓╨╬─. We repair that.
public enum FilenameEncoding: String, CaseIterable, Codable, Sendable, Identifiable {
    case automatic
    case utf8
    case gb18030
    case big5
    case shiftJIS
    case cp437

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .automatic: return "自动检测"
        case .utf8: return "UTF-8"
        case .gb18030: return "简体中文 (GBK/GB18030)"
        case .big5: return "繁体中文 (Big5)"
        case .shiftJIS: return "日文 (Shift-JIS)"
        case .cp437: return "西文 (CP437)"
        }
    }

    public var shortName: String {
        switch self {
        case .automatic: return "自动"
        case .utf8: return "UTF-8"
        case .gb18030: return "GBK"
        case .big5: return "Big5"
        case .shiftJIS: return "Shift-JIS"
        case .cp437: return "CP437"
        }
    }

    public var foundationEncoding: String.Encoding? {
        switch self {
        case .automatic, .cp437:
            return nil
        case .utf8:
            return .utf8
        case .gb18030:
            let cf = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
        case .big5:
            let cf = CFStringEncoding(CFStringEncodings.big5.rawValue)
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
        case .shiftJIS:
            return .shiftJIS
        }
    }
}

enum FilenameRepair {
    /// Unicode code points for CP437 bytes 0x80...0xFF, in order.
    private static let cp437High: [Unicode.Scalar] = [
        "Ç", "ü", "é", "â", "ä", "à", "å", "ç", "ê", "ë", "è", "ï", "î", "ì", "Ä", "Å",
        "É", "æ", "Æ", "ô", "ö", "ò", "û", "ù", "ÿ", "Ö", "Ü", "¢", "£", "¥", "₧", "ƒ",
        "á", "í", "ó", "ú", "ñ", "Ñ", "ª", "º", "¿", "⌐", "¬", "½", "¼", "¡", "«", "»",
        "░", "▒", "▓", "│", "┤", "╡", "╢", "╖", "╕", "╣", "║", "╗", "╝", "╜", "╛", "┐",
        "└", "┴", "┬", "├", "─", "┼", "╞", "╟", "╚", "╔", "╩", "╦", "╠", "═", "╬", "╧",
        "╨", "╤", "╥", "╙", "╘", "╒", "╓", "╫", "╪", "┘", "┌", "█", "▄", "▌", "▐", "▀",
        "α", "ß", "Γ", "π", "Σ", "σ", "µ", "τ", "Φ", "Θ", "Ω", "δ", "∞", "φ", "ε", "∩",
        "≡", "±", "≥", "≤", "⌠", "⌡", "÷", "≈", "°", "∙", "·", "√", "ⁿ", "²", "■", "\u{00A0}",
    ]

    private static let inverse: [Unicode.Scalar: UInt8] = {
        var map: [Unicode.Scalar: UInt8] = [:]
        for (offset, scalar) in cp437High.enumerated() {
            map[scalar] = UInt8(0x80 + offset)
        }
        return map
    }()

    /// Reverses libarchive's CP437 decoding and re-decodes the original bytes
    /// with the requested legacy encoding.
    static func repairCP437(_ string: String, to encoding: FilenameEncoding) -> String? {
        guard let target = encoding.foundationEncoding else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(string.utf8.count)
        for scalar in string.unicodeScalars {
            if scalar.value < 0x80 {
                bytes.append(UInt8(scalar.value))
            } else if let byte = inverse[scalar] {
                bytes.append(byte)
            } else {
                return nil
            }
        }
        guard !bytes.isEmpty else { return nil }
        guard let decoded = String(data: Data(bytes), encoding: target), decoded != string else {
            return nil
        }
        return decoded
    }

    /// Heuristic: libarchive decoded GBK bytes as CP437, which tends to produce
    /// box-drawing characters. Those are a strong signal that the name is broken.
    static func looksLikeMojibake(_ string: String) -> Bool {
        var suspicious = 0
        var boxDrawing = 0
        for scalar in string.unicodeScalars where scalar.value >= 0x80 {
            guard inverse[scalar] != nil else { continue }
            suspicious += 1
            if (0x2500...0x259F).contains(scalar.value) { boxDrawing += 1 }
        }
        if boxDrawing >= 1 && suspicious >= 2 { return true }
        return suspicious >= 4 && string.count <= suspicious + 2
    }

    static func containsCJK(_ string: String) -> Bool {
        for scalar in string.unicodeScalars {
            if (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value) {
                return true
            }
        }
        return false
    }

    /// Applies the user's encoding choice to a name that libarchive already
    /// handed us. Returns nil when no repair should be applied.
    static func autoRepair(_ string: String, encoding: FilenameEncoding) -> String? {
        switch encoding {
        case .automatic:
            guard looksLikeMojibake(string) else { return nil }
            for candidate in [FilenameEncoding.gb18030, .big5, .shiftJIS] {
                if let repaired = repairCP437(string, to: candidate), containsCJK(repaired) {
                    return repaired
                }
            }
            return nil
        case .utf8, .cp437:
            return nil
        case .gb18030, .big5, .shiftJIS:
            guard let repaired = repairCP437(string, to: encoding) else { return nil }
            return repaired
        }
    }
}
