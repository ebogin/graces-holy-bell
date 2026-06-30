import XCTest
@testable import Graces_Holy_Bell

/// Phase 3b — the observable consent wrapper backing the toggle + banner.
final class AnalyticsConsentTests: XCTestCase {

    func test_init_appliesRegionDefault() {
        let eu = AnalyticsConsent(store: InMemoryConsentStore(), locale: Locale(identifier: "fr_FR"))
        XCTAssertEqual(eu.state, .pending)
        XCTAssertTrue(eu.needsConsentDecision)
        XCTAssertFalse(eu.isGranted)

        let us = AnalyticsConsent(store: InMemoryConsentStore(), locale: Locale(identifier: "en_US"))
        XCTAssertEqual(us.state, .granted)
        XCTAssertFalse(us.needsConsentDecision)
        XCTAssertTrue(us.isGranted)
    }

    func test_init_preservesExistingChoice() {
        let store = InMemoryConsentStore()
        store.consentState = .denied
        let consent = AnalyticsConsent(store: store, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(consent.state, .denied)
    }

    func test_enabled_mapsToGrantedDenied_andPersists() {
        let store = InMemoryConsentStore()
        let consent = AnalyticsConsent(store: store, locale: Locale(identifier: "en_US")) // granted
        XCTAssertTrue(consent.enabled)

        consent.enabled = false
        XCTAssertEqual(consent.state, .denied)
        XCTAssertEqual(store.consentState, .denied)

        consent.enabled = true
        XCTAssertEqual(consent.state, .granted)
        XCTAssertEqual(store.consentState, .granted)
    }

    func test_grantAndDeny_fromBanner() {
        let store = InMemoryConsentStore()
        let consent = AnalyticsConsent(store: store, locale: Locale(identifier: "de_DE")) // pending
        XCTAssertTrue(consent.needsConsentDecision)

        consent.grant()
        XCTAssertEqual(consent.state, .granted)
        XCTAssertFalse(consent.needsConsentDecision)
        XCTAssertEqual(store.consentState, .granted)

        consent.deny()
        XCTAssertEqual(consent.state, .denied)
        XCTAssertEqual(store.consentState, .denied)
    }
}
