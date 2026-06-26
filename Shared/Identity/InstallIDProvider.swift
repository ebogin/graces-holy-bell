import Foundation

/// iPhone-side canonical `install_id` provider.
///
/// The iPhone is the canonical generator. `resolve()` returns the stored id, or
/// mints one (and persists it) on first ever call. Idempotent thereafter for
/// the life of the install.
final class InstallIDProvider {
    private let store: InstallIDStore
    private let mint: () -> String

    init(store: InstallIDStore, mint: @escaping () -> String = InstallID.mint) {
        self.store = store
        self.mint = mint
    }

    /// Returns the existing id, or mints, persists, and returns a new one.
    func resolve() -> String {
        if let existing = store.load() {
            return existing
        }
        let new = mint()
        store.save(new)
        return new
    }
}
