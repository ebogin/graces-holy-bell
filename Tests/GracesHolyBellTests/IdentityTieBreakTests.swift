import XCTest
@testable import Graces_Holy_Bell

/// Phase 1b — the deterministic tie-break.
///
/// This pure resolver is the heart of the "no phantom users" invariant: when a
/// Watch-first cold start means two candidate ids could exist, exactly one must
/// win, deterministically, so both devices converge on a single canonical
/// `install_id`. Rule (from the plan): iPhone-minted wins; otherwise earliest
/// mint wins; ties broken lexicographically.
final class IdentityTieBreakTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_000_500)

    private func candidate(_ id: String, _ origin: DeviceSource, _ at: Date) -> InstallIDCandidate {
        InstallIDCandidate(id: id, origin: origin, mintedAt: at)
    }

    func test_phoneMintedBeatsWatchMinted_regardlessOfTimestamp() {
        // Watch minted *earlier*, but phone still wins.
        let phone = candidate("phone-id", .phone, t1)
        let watch = candidate("watch-id", .watch, t0)
        XCTAssertEqual(IdentityTieBreak.resolve(phone, watch)?.id, "phone-id")
        XCTAssertEqual(IdentityTieBreak.resolve(watch, phone)?.id, "phone-id")
    }

    func test_singleCandidatePresent_wins() {
        let only = candidate("only", .watch, t0)
        XCTAssertEqual(IdentityTieBreak.resolve(only, nil)?.id, "only")
        XCTAssertEqual(IdentityTieBreak.resolve(nil, only)?.id, "only")
    }

    func test_bothNil_resolvesNil() {
        XCTAssertNil(IdentityTieBreak.resolve(nil, nil))
    }

    func test_sameOrigin_earliestMintWins() {
        let early = candidate("zzz", .watch, t0)   // later id alphabetically, but earlier mint
        let late = candidate("aaa", .watch, t1)
        XCTAssertEqual(IdentityTieBreak.resolve(early, late)?.id, "zzz")
        XCTAssertEqual(IdentityTieBreak.resolve(late, early)?.id, "zzz")
    }

    func test_sameOriginSameMint_lexicographicallySmallerIDWins() {
        let a = candidate("aaa", .watch, t0)
        let b = candidate("bbb", .watch, t0)
        XCTAssertEqual(IdentityTieBreak.resolve(a, b)?.id, "aaa")
        XCTAssertEqual(IdentityTieBreak.resolve(b, a)?.id, "aaa")
    }

    func test_resolveIsCommutative() {
        let pairs: [(InstallIDCandidate?, InstallIDCandidate?)] = [
            (candidate("p", .phone, t0), candidate("w", .watch, t1)),
            (candidate("aaa", .watch, t0), candidate("bbb", .watch, t0)),
            (candidate("zzz", .watch, t0), candidate("aaa", .watch, t1)),
            (candidate("only", .phone, t0), nil)
        ]
        for (a, b) in pairs {
            XCTAssertEqual(IdentityTieBreak.resolve(a, b), IdentityTieBreak.resolve(b, a))
        }
    }
}
