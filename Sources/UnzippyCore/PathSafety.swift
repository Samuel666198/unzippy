import Foundation

/// Guards against ZIP-slip / tar-slip and symlink escapes.
enum SafePath {
    /// Returns the safe path components, or nil when the entry must be refused.
    static func components(for rawPath: String) -> [String]? {
        var path = rawPath.replacingOccurrences(of: "\\", with: "/")
        while path.hasPrefix("./") { path.removeFirst(2) }
        while path.hasPrefix("/") { path.removeFirst() }
        // Windows drive letter, e.g. "C:/Users/x"
        if path.count >= 2, path[path.index(path.startIndex, offsetBy: 1)] == ":" {
            let first = path.first!
            if first.isLetter { path.removeFirst(2) }
        }
        var components: [String] = []
        for component in path.split(separator: "/", omittingEmptySubsequences: true) {
            if component == "." { continue }
            if component == ".." { return nil }
            if component.utf8.count > 255 { return nil }
            components.append(String(component))
        }
        guard !components.isEmpty else { return nil }
        return components
    }

    static func relativePath(for rawPath: String) -> String? {
        guard let components = components(for: rawPath) else { return nil }
        return components.joined(separator: "/")
    }

    /// Symlink targets must stay inside the extraction root.
    static func isSafeSymlinkTarget(_ target: String, relativePath: String) -> Bool {
        if target.hasPrefix("/") { return false }
        let parent = (relativePath as NSString).deletingLastPathComponent
        let combined = parent.isEmpty ? target : parent + "/" + target
        var depth = 0
        for component in combined.split(separator: "/", omittingEmptySubsequences: true) {
            if component == "." { continue }
            if component == ".." {
                depth -= 1
                if depth < 0 { return false }
            } else {
                depth += 1
            }
        }
        return true
    }
}
