import XCTest
@testable import Graces_Holy_Bell

/// Tests for SyncSnapshot and the event/clear wire-message types.
/// (Replaces SyncedSessionStateTests after Stage 3 removes SyncedSessionState.)
final class SyncSnapshotTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_001_000)

    // MARK: - SyncSnapshot round-trip

    func test_toDictionary_fromDictionary_roundTrip() {
        let original = SyncSnapshot(
            events: [
                PrayerEvent(id: UUID(), timestamp: t0, origin: .phone),
                PrayerEvent(id: UUID(), timestamp: t1, origin: .watch)
            ],
            lastClearedAt: t0,
            amenAlarmFireAt: t1
        )
        let restored = SyncSnapshot.fromDictionary(original.toDictionary())
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.events.count, 2)
        XCTAssertEqual(restored?.lastClearedAt, t0)
        XCTAssertEqual(restored?.amenAlarmFireAt, t1)
    }

    func test_toDictionary_fromDictionary_nilOptionals() {
        let original = SyncSnapshot(events: [], lastClearedAt: nil, amenAlarmFireAt: nil)
        let restored = SyncSnapshot.fromDictionary(original.toDictionary())
        XCTAssertNotNil(restored)
        XCTAssertTrue(restored!.events.isEmpty)
        XCTAssertNil(restored?.lastClearedAt)
        XCTAssertNil(restored?.amenAlarmFireAt)
    }

    func test_toDictionary_isPropertyListCompatible() {
        let dict = SyncSnapshot(
            events: [PrayerEvent(id: UUID(), timestamp: t0, origin: .watch)],
            lastClearedAt: t1,
            amenAlarmFireAt: nil
        ).toDictionary()
        XCTAssertTrue(PropertyListSerialization.propertyList(dict, isValidFor: .binary))
    }

    func test_fromDictionary_emptyDictionary_returnsNil() {
        XCTAssertNil(SyncSnapshot.fromDictionary([:]))
    }

    func test_fromDictionary_wrongPayloadType_returnsNil() {
        XCTAssertNil(SyncSnapshot.fromDictionary(["snapshot": "not data"]))
    }

    func test_fromDictionary_garbageData_returnsNil() {
        let garbage = Data([0xDE, 0xAD, 0xBE, 0xEF])
        XCTAssertNil(SyncSnapshot.fromDictionary(["snapshot": garbage]))
    }

    func test_eventTimestampPreservedThroughDictionary() {
        let timestamp = Date(timeIntervalSince1970: 999_888.5)
        let snapshot = SyncSnapshot(
            events: [PrayerEvent(id: UUID(), timestamp: timestamp, origin: .phone)],
            lastClearedAt: nil,
            amenAlarmFireAt: nil
        )
        let restored = SyncSnapshot.fromDictionary(snapshot.toDictionary())
        XCTAssertEqual(restored?.events.first?.timestamp, timestamp)
    }

    func test_originPreservedThroughDictionary() {
        let watch = PrayerEvent(id: UUID(), timestamp: t0, origin: .watch)
        let phone = PrayerEvent(id: UUID(), timestamp: t1, origin: .phone)
        let snapshot = SyncSnapshot(events: [watch, phone], lastClearedAt: nil, amenAlarmFireAt: nil)
        let restored = SyncSnapshot.fromDictionary(snapshot.toDictionary())!
        let byID = Dictionary(uniqueKeysWithValues: restored.events.map { ($0.id, $0) })
        XCTAssertEqual(byID[watch.id]?.origin, .watch)
        XCTAssertEqual(byID[phone.id]?.origin, .phone)
    }

    // MARK: - EventMessage

    func test_eventMessage_roundTrip() {
        let event = PrayerEvent(id: UUID(), timestamp: t0, origin: .watch)
        let restored = EventMessage.fromUserInfo(EventMessage(event: event).toUserInfo())
        XCTAssertEqual(restored?.event.id, event.id)
        XCTAssertEqual(restored?.event.timestamp, event.timestamp)
        XCTAssertEqual(restored?.event.origin, event.origin)
    }

    func test_eventMessage_wrongMsg_returnsNil() {
        XCTAssertNil(EventMessage.fromUserInfo(["msg": "clear", "id": UUID().uuidString]))
    }

    func test_eventMessage_missingFields_returnsNil() {
        XCTAssertNil(EventMessage.fromUserInfo([:]))
    }

    // MARK: - ClearMessage

    func test_clearMessage_roundTrip() {
        let msg = ClearMessage(clearedAt: t0)
        let restored = ClearMessage.fromUserInfo(msg.toUserInfo())
        XCTAssertEqual(restored?.clearedAt, t0)
    }

    func test_clearMessage_wrongMsg_returnsNil() {
        XCTAssertNil(ClearMessage.fromUserInfo(["msg": "event"]))
    }
}
