import Foundation

/// Archive families we can open. `libarchive` does the heavy lifting, this is
/// only used for naming, icons, filtering and for choosing sensible defaults.
public enum ArchiveFormat: String, CaseIterable, Codable, Sendable {
    case zip
    case sevenZip
    case rar
    case tar
    case tarGz
    case tarBz2
    case tarXz
    case tarZst
    case gzip
    case bzip2
    case xz
    case zstd
    case iso
    case cab
    case cpio
    case xar
    case lha
    case other

    public var displayName: String {
        switch self {
        case .zip: return "ZIP"
        case .sevenZip: return "7-Zip"
        case .rar: return "RAR"
        case .tar: return "TAR"
        case .tarGz: return "TAR.GZ"
        case .tarBz2: return "TAR.BZ2"
        case .tarXz: return "TAR.XZ"
        case .tarZst: return "TAR.ZST"
        case .gzip: return "GZIP"
        case .bzip2: return "BZIP2"
        case .xz: return "XZ"
        case .zstd: return "ZSTD"
        case .iso: return "ISO"
        case .cab: return "CAB"
        case .cpio: return "CPIO"
        case .xar: return "XAR"
        case .lha: return "LHA"
        case .other: return "压缩包"
        }
    }

    public var badge: String {
        switch self {
        case .zip: return "ZIP"
        case .sevenZip: return "7Z"
        case .rar: return "RAR"
        case .tar, .tarGz, .tarBz2, .tarXz, .tarZst: return "TAR"
        case .gzip: return "GZ"
        case .bzip2: return "BZ2"
        case .xz: return "XZ"
        case .zstd: return "ZST"
        case .iso: return "ISO"
        case .cab: return "CAB"
        case .cpio: return "CPIO"
        case .xar: return "XAR"
        case .lha: return "LHA"
        case .other: return "ARC"
        }
    }

    public var symbolName: String {
        switch self {
        case .zip, .sevenZip: return "doc.zipper"
        case .rar: return "doc.zipper"
        case .tar, .tarGz, .tarBz2, .tarXz, .tarZst: return "shippingbox"
        case .iso: return "opticaldisc"
        case .cab: return "archivebox"
        default: return "archivebox"
        }
    }

    /// Whether this is a single stream to which libarchive's "raw" reader applies.
    public var isRawStream: Bool {
        switch self {
        case .gzip, .bzip2, .xz, .zstd: return true
        default: return false
        }
    }

    public var isKnown: Bool { self != .other }

    public var supportsCompression: Bool {
        switch self {
        case .zip, .sevenZip, .tarGz: return true
        default: return false
        }
    }

    private static let multiExtensions: [(String, ArchiveFormat)] = [
        (".tar.gz", .tarGz), (".tar.gzip", .tarGz),
        (".tar.bz2", .tarBz2), (".tar.bzip2", .tarBz2),
        (".tar.xz", .tarXz), (".tar.lzma", .tarXz),
        (".tar.zst", .tarZst), (".tar.zstd", .tarZst),
        (".tgz", .tarGz), (".tbz", .tarBz2), (".tbz2", .tarBz2),
        (".txz", .tarXz), (".tzst", .tarZst),
    ]

    private static let singleExtensions: [String: ArchiveFormat] = [
        ".zip": .zip, ".zipx": .zip, ".jar": .zip, ".apk": .zip, ".ipa": .zip,
        ".cbz": .zip, ".epub": .zip, ".whl": .zip, ".xpi": .zip,
        ".7z": .sevenZip,
        ".rar": .rar, ".cbr": .rar,
        ".tar": .tar, ".gtar": .tar,
        ".gz": .gzip, ".gzip": .gzip,
        ".bz2": .bzip2, ".bzip": .bzip2,
        ".xz": .xz, ".lzma": .xz,
        ".zst": .zstd, ".zstd": .zstd,
        ".iso": .iso, ".img": .iso,
        ".cab": .cab,
        ".cpio": .cpio,
        ".xar": .xar, ".pkg": .xar,
        ".lha": .lha, ".lzh": .lha,
    ]

    public static func detect(url: URL) -> ArchiveFormat {
        let name = url.lastPathComponent.lowercased()
        for (suffix, format) in multiExtensions where name.hasSuffix(suffix) {
            return format
        }
        let ext = "." + url.pathExtension.lowercased()
        if let format = singleExtensions[ext] {
            return format
        }
        return .other
    }

    public static func looksLikeArchive(url: URL) -> Bool {
        detect(url: url).isKnown
    }

    /// Maps libarchive's human readable format name onto our enum.
    public static func from(libarchiveName: String, url: URL) -> ArchiveFormat {
        let detected = detect(url: url)
        let name = libarchiveName.lowercased()
        if name.contains("7-zip") || name.contains("7zip") || name.contains("7z") { return .sevenZip }
        if name.contains("zip") { return .zip }
        if name.contains("rar") { return .rar }
        if name.contains("iso") { return .iso }
        if name.contains("cab") { return .cab }
        if name.contains("cpio") { return .cpio }
        if name.contains("xar") { return .xar }
        if name.contains("lha") || name.contains("lzh") { return .lha }
        if name.contains("tar") {
            // A tar with a compression filter keeps its compound identity.
            if detected == .tarGz || detected == .tarBz2 || detected == .tarXz || detected == .tarZst {
                return detected
            }
            return .tar
        }
        if detected != .other { return detected }
        return .other
    }
}
