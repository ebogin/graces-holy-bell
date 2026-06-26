import Foundation

/// Deterministic resolver for the canonical `install_id` across devices.
///
/// Enforces the "no phantom users" invariant: if a Watch-first cold start means
/// both devices hold a candidate, exactly one must win — the same way, every
/// time, on both devices, with no PostHog merge/alias ever needed.
///
/// Rule (from the plan):
/// 1. An iPhone-minted candidate wins over a Watch-minted one.
/// 2. Otherwise (same origin) the earliest `mintedAt` wins.
/// 3. Exact ties break to the lexicographically smaller id.
/// A single present candidate wins by default; two absent resolve to nil.
enum IdentityTieBreak {

    static func resolve(_ a: InstallIDCandidate?, _ b: InstallIDCandidate?) -> InstallIDCandidate? {
        switch (a, b) {
        case (nil, nil):
            return nil
        case let (x?, nil):
            return x
        case let (nil, y?):
            return y
        case let (x?, y?):
            return winner(x, y)
        }
    }

    private static func winner(_ x: InstallIDCandidate, _ y: InstallIDCandidate) -> InstallIDCandidate {
        // 1. iPhone-minted wins outright.
        if x.origin != y.origin {
            return x.origin == .phone ? x : y
        }
        // 2. Same origin: earliest mint wins.
        if x.mintedAt != y.mintedAt {
            return x.mintedAt < y.mintedAt ? x : y
        }
        // 3. Exact tie: lexicographically smaller id wins.
        return x.id <= y.id ? x : y
    }
}
