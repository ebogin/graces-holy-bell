import Foundation

/// Abstraction over WatchConnectivityManager that lets unit tests inject a mock.
protocol WatchConnectivityInterface: AnyObject {
    var latestState: SyncedSessionState? { get }
    func sendAction(_ action: String)
    func sendClearLog()
}
