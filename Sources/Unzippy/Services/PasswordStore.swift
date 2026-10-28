import Foundation
import Security

/// Optional "remember password" storage in the user's login keychain.
enum PasswordStore {
    private static let service = "com.samuel.unzippy.archive"

    private static func query(for url: URL) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: url.standardizedFileURL.path,
        ]
    }

    static func password(for url: URL) -> String? {
        var query = query(for: url)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ password: String, for url: URL) {
        let base = query(for: url)
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = Data(password.utf8)
        item[kSecAttrLabel as String] = "轻解压 · \(url.lastPathComponent)"
        SecItemAdd(item as CFDictionary, nil)
    }

    static func delete(for url: URL) {
        SecItemDelete(query(for: url) as CFDictionary)
    }
}
