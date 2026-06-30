import Foundation

/// Persistence port for the canonical `install_id`.
///
/// Abstracted so the identity engine can be tested hermetically (in-memory
/// fake) and so the storage mechanism stays a single, swappable detail.
protocol InstallIDStore: AnyObject {
    func load() -> String?
    func save(_ id: String)
}

/// UserDefaults-backed store.
///
/// UserDefaults (not Keychain) is deliberate: it is cleared on
/// delete-and-reinstall, giving the honest "new install = new user" anonymity
/// the plan calls for. The suite is injectable so tests never touch
/// `.standard`.
final class UserDefaultsInstallIDStore: InstallIDStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "analytics.install_id") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> String? { defaults.string(forKey: key) }
    func save(_ id: String) { defaults.set(id, forKey: key) }
}
