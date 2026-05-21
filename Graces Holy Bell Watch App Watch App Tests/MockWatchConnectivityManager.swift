import Foundation
@testable import Graces_Holy_Bell_Watch_App_Watch_App

final class MockWatchConnectivityManager: WatchConnectivityInterface {
    var latestState: SyncedSessionState? = nil
    private(set) var sentActions: [String] = []
    private(set) var clearLogCallCount = 0

    func sendAction(_ action: String) {
        sentActions.append(action)
    }

    func sendClearLog() {
        clearLogCallCount += 1
    }
}
