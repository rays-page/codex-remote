import Foundation
import Security

struct CapabilityTokenStore {
    let service: String
    let account: String
    let accessGroup: String?

    static let shared = CapabilityTokenStore(
        service: AppSettings.keychainService,
        account: AppSettings.keychainAccount,
        accessGroup: AppSettings.keychainAccessGroup
    )

    func loadToken() -> String? {
        loadToken(accessGroup: accessGroup) ?? loadToken(accessGroup: nil)
    }

    func saveToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            deleteToken()
            return
        }

        if saveToken(trimmed, accessGroup: accessGroup) {
            return
        }

        _ = saveToken(trimmed, accessGroup: nil)
    }

    func deleteToken() {
        _ = deleteToken(accessGroup: accessGroup)
        _ = deleteToken(accessGroup: nil)
    }

    private func loadToken(accessGroup: String?) -> String? {
        var query = baseQuery(accessGroup: accessGroup)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveToken(_ token: String, accessGroup: String?) -> Bool {
        let data = Data(token.utf8)
        var addQuery = baseQuery(accessGroup: accessGroup)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess {
            return true
        }

        guard status == errSecDuplicateItem else { return false }

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(
            baseQuery(accessGroup: accessGroup) as CFDictionary,
            attributesToUpdate as CFDictionary
        )
        return updateStatus == errSecSuccess
    }

    private func deleteToken(accessGroup: String?) -> Bool {
        let status = SecItemDelete(baseQuery(accessGroup: accessGroup) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func baseQuery(accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let accessGroup, !accessGroup.isEmpty {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}

struct ConnectionProfileStore {
    let userDefaults: UserDefaults
    let legacyUserDefaults: UserDefaults?
    let tokenStore: CapabilityTokenStore

    static let standard = ConnectionProfileStore(
        userDefaults: .standard,
        legacyUserDefaults: nil,
        tokenStore: .shared
    )

    static func shared(suiteName: String? = AppSettings.appGroupIdentifier) -> ConnectionProfileStore {
        guard
            let suiteName,
            !suiteName.isEmpty,
            let userDefaults = UserDefaults(suiteName: suiteName)
        else {
            return .standard
        }

        return ConnectionProfileStore(
            userDefaults: userDefaults,
            legacyUserDefaults: .standard,
            tokenStore: .shared
        )
    }

    func load() -> ConnectionProfile {
        var profile = loadProfile(from: userDefaults)
            ?? legacyUserDefaults.flatMap(loadProfile(from:))
            ?? .default

        let storedToken = tokenStore.loadToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let legacyToken = profile.token.trimmingCharacters(in: .whitespacesAndNewlines)

        if storedToken.isEmpty, !legacyToken.isEmpty {
            tokenStore.saveToken(legacyToken)
            profile.token = legacyToken
        } else {
            profile.token = storedToken
        }

        save(profile)
        return profile
    }

    func save(_ profile: ConnectionProfile) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(profile.nonSecretCopy) else { return }
        userDefaults.set(data, forKey: ConnectionProfile.storageKey)

        if profile.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tokenStore.deleteToken()
        } else {
            tokenStore.saveToken(profile.token)
        }

        legacyUserDefaults?.removeObject(forKey: ConnectionProfile.storageKey)
    }

    private func loadProfile(from userDefaults: UserDefaults) -> ConnectionProfile? {
        let decoder = JSONDecoder()
        guard let data = userDefaults.data(forKey: ConnectionProfile.storageKey) else {
            return nil
        }

        return try? decoder.decode(ConnectionProfile.self, from: data)
    }
}
