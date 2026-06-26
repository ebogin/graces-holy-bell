import Foundation

/// A candidate `install_id` plus the metadata the tie-break needs to choose a
/// single winner across devices.
///
/// On a normal launch only the iPhone ever holds one. A candidate exists on the
/// Watch only transiently, during a Watch-first cold start, and is never
/// transmitted before ``IdentityTieBreak`` resolves the canonical id.
struct InstallIDCandidate: Equatable {
    /// The opaque, random, PII-free id (UUID string).
    let id: String
    /// The device that minted this candidate.
    let origin: DeviceSource
    /// When this candidate was minted — used to break same-origin ties.
    let mintedAt: Date
}

/// Centralized minting of a fresh anonymous `install_id`.
///
/// A plain random UUID: no device fingerprint, no PII. Persisted in
/// UserDefaults (not Keychain) so delete-and-reinstall yields a new id.
enum InstallID {
    nonisolated static func mint() -> String { UUID().uuidString }
}
