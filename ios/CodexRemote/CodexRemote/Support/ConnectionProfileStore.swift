import Foundation

struct ConnectionProfileStore {
    let userDefaults: UserDefaults

    static let standard = ConnectionProfileStore(userDefaults: .standard)

    static func shared(suiteName: String?) -> ConnectionProfileStore {
        guard
            let suiteName,
            !suiteName.isEmpty,
            let userDefaults = UserDefaults(suiteName: suiteName)
        else {
            return .standard
        }

        return ConnectionProfileStore(userDefaults: userDefaults)
    }

    func load() -> ConnectionProfile {
        let decoder = JSONDecoder()
        if
            let data = userDefaults.data(forKey: ConnectionProfile.storageKey),
            let profile = try? decoder.decode(ConnectionProfile.self, from: data)
        {
            return profile
        }

        return .default
    }

    func save(_ profile: ConnectionProfile) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(profile) else { return }
        userDefaults.set(data, forKey: ConnectionProfile.storageKey)
    }
}
