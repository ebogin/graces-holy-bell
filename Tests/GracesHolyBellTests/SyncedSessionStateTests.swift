import XCTest
@testable import Graces_Holy_Bell

final class SyncedSessionStateTests: XCTestCase {

    // MARK: - Round-trip

    func test_toDictionary_fromDictionary_roundTrip() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let t1 = Date(timeIntervalSince1970: 1_001_000)
        let alarmFireAt = Date(timeIntervalSince1970: 1_003_600)

        let original = SyncedSessionState(
            appState: "active",
            entries: [
                SyncedEntry(timestamp: t0, sequenceIndex: 0),
                SyncedEntry(timestamp: t1, sequenceIndex: 1)
            ],
            amenAlarmFireAt: alarmFireAt
        )

        let dict = original.toDictionary()
        let restored = SyncedSessionState.fromDictionary(dict)

        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.appState, "active")
        XCTAssertEqual(restored?.entries.count, 2)
        XCTAssertEqual(restored?.entries[0].sequenceIndex, 0)
        XCTAssertEqual(restored?.entries[1].sequenceIndex, 1)
        XCTAssertEqual(restored?.amenAlarmFireAt?.timeIntervalSince1970,
                       alarmFireAt.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_toDictionary_fromDictionary_nilOptionals() {
        let original = SyncedSessionState(
            appState: "idle",
            entries: [],
            amenAlarmFireAt: nil
        )

        let dict = original.toDictionary()
        let restored = SyncedSessionState.fromDictionary(dict)

        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.appState, "idle")
        XCTAssertTrue(restored?.entries.isEmpty == true)
        XCTAssertNil(restored?.amenAlarmFireAt)
    }

    // MARK: - Wire format

    func test_toDictionary_isPropertyListCompatible() {
        // updateApplicationContext only accepts property-list types.
        let dict = SyncedSessionState(
            appState: "active",
            entries: [SyncedEntry(timestamp: .now, sequenceIndex: 0)],
            amenAlarmFireAt: .now
        ).toDictionary()
        XCTAssertTrue(PropertyListSerialization.propertyList(
            dict, isValidFor: .binary
        ))
    }

    // MARK: - fromDictionary — malformed input

    func test_fromDictionary_emptyDictionary_returnsNil() {
        XCTAssertNil(SyncedSessionState.fromDictionary([:]))
    }

    func test_fromDictionary_wrongPayloadType_returnsNil() {
        XCTAssertNil(SyncedSessionState.fromDictionary(["state": "not data"]))
    }

    func test_fromDictionary_garbageData_returnsNil() {
        let garbage = Data([0xDE, 0xAD, 0xBE, 0xEF])
        XCTAssertNil(SyncedSessionState.fromDictionary(["state": garbage]))
    }

    // MARK: - Entry timestamp fidelity

    func test_entryTimestampPreservedThroughDictionary() {
        let timestamp = Date(timeIntervalSince1970: 1_718_000_000)
        let state = SyncedSessionState(
            appState: "active",
            entries: [SyncedEntry(timestamp: timestamp, sequenceIndex: 0)],
            amenAlarmFireAt: nil
        )
        let restored = SyncedSessionState.fromDictionary(state.toDictionary())
        XCTAssertEqual(
            restored?.entries.first?.timestamp.timeIntervalSince1970,
            timestamp.timeIntervalSince1970,
            accuracy: 0.001
        )
    }
}
