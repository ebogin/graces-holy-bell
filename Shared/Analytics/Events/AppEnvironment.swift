import Foundation

/// Read-only runtime facts that ride on every event as person/event properties.
///
/// Abstracted so events can be built and tested without touching `Bundle` or the
/// device. Foundation-only, so the live implementation compiles unchanged on
/// both iOS and watchOS.
protocol AppEnvironment {
    var appVersion: String { get }
    var osVersion: String { get }
    /// Coarse build channel so dev/sim runs are filterable in analytics
    /// (`debug` for Xcode/simulator builds, `release` for TestFlight + App Store).
    var buildChannel: String { get }
}

/// Live environment: app version from the bundle, OS version from ProcessInfo.
struct LiveAppEnvironment: AppEnvironment {

    var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
    }

    var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    /// `debug` for local Xcode/simulator runs, `release` otherwise (TestFlight +
    /// App Store both build Release). Lets dev testing be excluded in PostHog
    /// with a single `build_channel = release` filter — no per-install bookkeeping.
    var buildChannel: String {
        #if DEBUG
        return "debug"
        #else
        return "release"
        #endif
    }
}
