import Foundation
import Security

struct KeychainStore {
    enum Item: String {
        case idToken = "com.wool.auth.idToken"
        case appleUserID = "com.wool.auth.appleUserID"
        case accessToken = "com.wool.auth.accessToken"
        case refreshToken = "com.wool.auth.refreshToken"
        case userDisplayName = "com.wool.auth.displayName"
        case userEmail = "com.wool.auth.email"
        case apnsToken = "com.wool.apns.token"
        case deviceId = "com.wool.app.deviceId"
        case actionQueue = "com.wool.app.actionQueue"
        case gmailAccessToken = "com.wool.gmail.accessToken"
        case gmailRefreshToken = "com.wool.gmail.refreshToken"
        case gmailTokenExpiry = "com.wool.gmail.tokenExpiry"
        case gmailGrantedScopes = "com.wool.gmail.grantedScopes"
    }

    private static let service = "com.wool.keychain"

    static func save(_ value: Data, for item: Item) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: item.rawValue
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = value
        #if os(iOS)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        #endif

        // Add shared access group for cross-platform token sharing
        #if os(iOS) || os(macOS)
        attributes[kSecAttrAccessGroup as String] = "425MSY8FLG.com.sparkage.wool"
        #endif

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func load(_ item: Item) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: item.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        // Add shared access group for cross-platform token sharing
        #if os(iOS) || os(macOS)
        query[kSecAttrAccessGroup as String] = "425MSY8FLG.com.sparkage.wool"
        #endif

        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        return out as? Data
    }

    static func clear(_ item: Item) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: item.rawValue
        ]

        // Add shared access group for cross-platform token sharing
        #if os(iOS) || os(macOS)
        query[kSecAttrAccessGroup as String] = "425MSY8FLG.com.sparkage.wool"
        #endif
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func saveString(_ string: String, for item: Item) throws {
        try save(Data(string.utf8), for: item)
    }

    static func loadString(_ item: Item) throws -> String? {
        guard let data = try load(item) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Protocol conformance methods

    func loadString(_ key: String) -> String? {
        // Try to match key with Item enum, otherwise use key directly
        if let item = Item(rawValue: key) {
            return try? Self.loadString(item)
        }
        // Fallback: use key as is
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func saveString(_ value: String, forKey key: String) -> Bool {
        do {
            // Try to match key with Item enum
            if let item = Item(rawValue: key) {
                try Self.saveString(value, for: item)
                return true
            }
            // Fallback: use key as is
            let data = Data(value.utf8)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.service,
                kSecAttrAccount as String: key
            ]
            SecItemDelete(query as CFDictionary)

            var attributes = query
            attributes[kSecValueData as String] = data
            #if os(iOS)
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            #endif

            return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
        } catch {
            return false
        }
    }

    func deleteString(_ key: String) -> Bool {
        do {
            // Try to match key with Item enum
            if let item = Item(rawValue: key) {
                try Self.clear(item)
                return true
            }
            // Fallback: use key as is
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.service,
                kSecAttrAccount as String: key
            ]
            let status = SecItemDelete(query as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        } catch {
            return false
        }
    }
}
