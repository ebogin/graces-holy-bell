import Foundation

/// The device an analytics event *originated* on.
///
/// Set once at capture time and never overwritten in transit. The Phase 2
/// Watch→phone proxy must preserve `watch` — the phone is only the transport,
/// so it must not rewrite the source to `phone`.
enum DeviceSource: String, Codable, Equatable {
    case phone
    case watch
}

/// A single property value carried on an event.
///
/// Constrained to property-list-compatible scalars so events can be encoded for
/// WatchConnectivity transfer (Phase 2) and forwarded to PostHog without lossy
/// stringification of numeric buckets/counts. Anonymous, bucketed values only —
/// never PII, never raw second-level durations, never prayer content.
enum AnalyticsValue: Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
}

/// A single anonymous analytics event.
///
/// A plain value type with no dependency on any transport or SDK, so it can be
/// queued, re-tagged with the canonical `install_id`, and replayed unchanged.
/// `captureTimestamp` records the *true* time the event happened so backdated
/// and late-delivered events (Phase 2) land at their real chronological point
/// via the PostHog `timestamp` override.
struct AnalyticsEvent: Equatable {

    /// Event name from the taxonomy (e.g. `"session_started"`).
    let name: String

    /// Anonymous, bucketed properties.
    var properties: [String: AnalyticsValue]

    /// The device this event originated on.
    var deviceSource: DeviceSource

    /// True capture time, preserved through queuing and proxying.
    var captureTimestamp: Date

    init(
        name: String,
        properties: [String: AnalyticsValue] = [:],
        deviceSource: DeviceSource,
        captureTimestamp: Date = Date()
    ) {
        self.name = name
        self.properties = properties
        self.deviceSource = deviceSource
        self.captureTimestamp = captureTimestamp
    }
}
