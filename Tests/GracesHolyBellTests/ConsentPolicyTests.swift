import XCTest
@testable import Graces_Holy_Bell

/// Phase 3a — geo-gated default consent posture (on-device, no IP/location).
final class ConsentPolicyTests: XCTestCase {

    func test_nonEURegion_defaultsToGranted_optOut() {
        XCTAssertEqual(RegionConsentPolicy.defaultState(regionCode: "US"), .granted)
        XCTAssertEqual(RegionConsentPolicy.defaultState(regionCode: "JP"), .granted)
    }

    func test_euAndEEARegions_defaultToPending_optIn() {
        for code in ["DE", "FR", "IE", "NO", "IS", "LI"] {
            XCTAssertEqual(RegionConsentPolicy.defaultState(regionCode: code), .pending, "\(code) should be opt-in")
        }
    }

    func test_unitedKingdom_isOptIn() {
        XCTAssertEqual(RegionConsentPolicy.defaultState(regionCode: "GB"), .pending)
    }

    func test_caseInsensitive() {
        XCTAssertEqual(RegionConsentPolicy.defaultState(regionCode: "de"), .pending)
        XCTAssertEqual(RegionConsentPolicy.defaultState(regionCode: "us"), .granted)
    }

    func test_unknownRegion_isStrictPending() {
        XCTAssertEqual(RegionConsentPolicy.defaultState(regionCode: nil), .pending)
    }

    // MARK: - ensureInitialState

    func test_ensureInitialState_emptyStore_persistsRegionDefault() {
        let euStore = InMemoryConsentStore()
        RegionConsentPolicy.ensureInitialState(in: euStore, locale: Locale(identifier: "fr_FR"))
        XCTAssertEqual(euStore.consentState, .pending)

        let usStore = InMemoryConsentStore()
        RegionConsentPolicy.ensureInitialState(in: usStore, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(usStore.consentState, .granted)
    }

    func test_ensureInitialState_doesNotOverwriteExistingChoice() {
        let store = InMemoryConsentStore()
        store.consentState = .denied
        RegionConsentPolicy.ensureInitialState(in: store, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(store.consentState, .denied, "an explicit prior choice must be preserved")
    }
}

/// In-test fake.
final class InMemoryConsentStore: ConsentStore {
    var consentState: ConsentState?
}
