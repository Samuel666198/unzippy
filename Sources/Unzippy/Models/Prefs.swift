import Foundation
import UnzippyCore

enum DestinationMode: String, CaseIterable, Identifiable {
    case sameFolder
    case downloads
    case ask
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sameFolder: return "与压缩包相同的位置"
        case .downloads: return "下载文件夹"
        case .ask: return "每次询问"
        case .custom: return "自定义文件夹"
        }
    }

    var symbolName: String {
        switch self {
        case .sameFolder: return "doc.on.doc"
        case .downloads: return "arrow.down.circle"
        case .ask: return "questionmark.folder"
        case .custom: return "folder"
        }
    }
}

enum PrefKey {
    static let destinationMode = "destinationMode"
    static let customDestination = "customDestination"
    static let createSubfolder = "createSubfolder"
    static let conflictPolicy = "conflictPolicy"
    static let revealInFinder = "revealInFinder"
    static let deleteArchive = "deleteArchiveAfterExtraction"
    static let encoding = "filenameEncoding"
    static let preservePermissions = "preservePermissions"
    static let extractSymlinks = "extractSymlinks"
    static let skipMacOSX = "skipMacOSXMetadata"
    static let removeQuarantine = "removeQuarantine"
    static let rememberPasswords = "rememberPasswords"
    static let compressionFormat = "compressionFormat"
    static let compressionLevel = "compressionLevel"
    static let skipDSStore = "skipDSStore"
    static let hasLaunchedBefore = "hasLaunchedBefore"
}

enum Prefs {
    static func registerDefaults() {
        let values: [String: Any] = [
            PrefKey.destinationMode: DestinationMode.sameFolder.rawValue,
            PrefKey.createSubfolder: true,
            PrefKey.conflictPolicy: ConflictPolicy.rename.rawValue,
            PrefKey.revealInFinder: true,
            PrefKey.deleteArchive: false,
            PrefKey.encoding: FilenameEncoding.automatic.rawValue,
            PrefKey.preservePermissions: true,
            PrefKey.extractSymlinks: true,
            PrefKey.skipMacOSX: true,
            PrefKey.removeQuarantine: true,
            PrefKey.rememberPasswords: false,
            PrefKey.compressionFormat: CompressionFormat.zip.rawValue,
            PrefKey.compressionLevel: 6,
            PrefKey.skipDSStore: true,
        ]
        // SwiftUI's @AppStorage can initialise before applicationDidFinishLaunching,
        // so materialise the defaults (rather than only registering them) once.
        for (key, value) in values where UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(value, forKey: key)
        }
        UserDefaults.standard.register(defaults: values)
    }

    static var destinationMode: DestinationMode {
        DestinationMode(rawValue: UserDefaults.standard.string(forKey: PrefKey.destinationMode) ?? "") ?? .sameFolder
    }

    static var customDestination: URL? {
        guard let path = UserDefaults.standard.string(forKey: PrefKey.customDestination), !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static var createSubfolder: Bool { UserDefaults.standard.bool(forKey: PrefKey.createSubfolder) }
    static var revealInFinder: Bool { UserDefaults.standard.bool(forKey: PrefKey.revealInFinder) }
    static var deleteArchive: Bool { UserDefaults.standard.bool(forKey: PrefKey.deleteArchive) }
    static var preservePermissions: Bool { UserDefaults.standard.bool(forKey: PrefKey.preservePermissions) }
    static var extractSymlinks: Bool { UserDefaults.standard.bool(forKey: PrefKey.extractSymlinks) }
    static var skipMacOSX: Bool { UserDefaults.standard.bool(forKey: PrefKey.skipMacOSX) }
    static var removeQuarantine: Bool { UserDefaults.standard.bool(forKey: PrefKey.removeQuarantine) }
    static var rememberPasswords: Bool { UserDefaults.standard.bool(forKey: PrefKey.rememberPasswords) }
    static var skipDSStore: Bool { UserDefaults.standard.bool(forKey: PrefKey.skipDSStore) }

    static var conflictPolicy: ConflictPolicy {
        ConflictPolicy(rawValue: UserDefaults.standard.string(forKey: PrefKey.conflictPolicy) ?? "") ?? .rename
    }

    static var encoding: FilenameEncoding {
        FilenameEncoding(rawValue: UserDefaults.standard.string(forKey: PrefKey.encoding) ?? "") ?? .automatic
    }

    static var compressionFormat: CompressionFormat {
        CompressionFormat(rawValue: UserDefaults.standard.string(forKey: PrefKey.compressionFormat) ?? "") ?? .zip
    }

    static var compressionLevel: Int {
        max(0, min(9, UserDefaults.standard.integer(forKey: PrefKey.compressionLevel)))
    }

    static func downloadsFolder() -> URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    /// Resolves the base folder for a specific archive, ignoring "ask".
    static func baseDestination(for archiveURL: URL) -> URL {
        switch destinationMode {
        case .sameFolder:
            return archiveURL.deletingLastPathComponent()
        case .downloads:
            return downloadsFolder()
        case .custom:
            return customDestination ?? archiveURL.deletingLastPathComponent()
        case .ask:
            return archiveURL.deletingLastPathComponent()
        }
    }

    static func extractionOptions(password: String?, encoding: FilenameEncoding, selection: Set<Int>?) -> ExtractionOptions {
        ExtractionOptions(
            password: password,
            encoding: encoding,
            conflictPolicy: conflictPolicy,
            preservePermissions: preservePermissions,
            extractSymlinks: extractSymlinks,
            skipMacOSXMetadata: skipMacOSX,
            removeQuarantine: removeQuarantine,
            selectedIndices: selection
        )
    }
}
