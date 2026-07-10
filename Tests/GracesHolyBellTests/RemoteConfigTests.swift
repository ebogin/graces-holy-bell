import XCTest
@testable import Graces_Holy_Bell

/// Remotely-configurable welcome message — the decoder is the safety net for
/// content authored by a human curl-ing JSON at the Worker, so its tolerance
/// rules (unknown types/fields/enum values degrade gracefully) are the most
/// important thing under test here.
final class RemoteConfigDecodingTests: XCTestCase {

    func test_fullHappyPath_decodesAllBlockTypesAndDetail() throws {
        let json = """
        {
          "version": 1,
          "messages": [
            {
              "id": "watch-install-2026-07",
              "audience": "watch_not_installed",
              "blocks": [
                { "type": "text", "value": "GET GRACE ON YOUR WRIST", "align": "center", "size": "large" },
                { "type": "text", "value": "Prayers sync from your Apple Watch automatically.", "align": "leading" },
                { "type": "link", "label": "HOW TO INSTALL", "destination": "detail" }
              ],
              "detail": {
                "title": "INSTALL ON APPLE WATCH",
                "blocks": [
                  { "type": "image", "url": "https://boginfactory.com/img/watch-install.png", "caption": "Watch app -> Available Apps -> Install" },
                  { "type": "text", "value": "1. Open the Watch app on your iPhone." }
                ]
              }
            },
            {
              "id": "default-2026-07",
              "audience": "all",
              "blocks": [
                { "type": "text", "value": "Welcome to your favorite app to time prayer duration." }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WelcomeConfig.self, from: json)
        XCTAssertEqual(config.version, 1)
        XCTAssertEqual(config.messages.count, 2)

        let first = config.messages[0]
        XCTAssertEqual(first.id, "watch-install-2026-07")
        XCTAssertEqual(first.audience, "watch_not_installed")
        XCTAssertEqual(first.blocks.count, 3)

        guard case .text(let value, let align, let size, let color) = first.blocks[0] else {
            return XCTFail("expected text block")
        }
        XCTAssertEqual(value, "GET GRACE ON YOUR WRIST")
        XCTAssertEqual(align, .center)
        XCTAssertEqual(size, .large)
        XCTAssertEqual(color, .dark) // default, not specified in JSON

        guard case .text(_, let align2, let size2, _) = first.blocks[1] else {
            return XCTFail("expected text block")
        }
        XCTAssertEqual(align2, .leading)
        XCTAssertEqual(size2, .body) // default

        guard case .link(let label, let destination) = first.blocks[2] else {
            return XCTFail("expected link block")
        }
        XCTAssertEqual(label, "HOW TO INSTALL")
        guard case .detail = destination else {
            return XCTFail("expected .detail destination")
        }

        let detail = try XCTUnwrap(first.detail)
        XCTAssertEqual(detail.title, "INSTALL ON APPLE WATCH")
        XCTAssertEqual(detail.blocks.count, 2)
        guard case .image(let url, let caption) = detail.blocks[0] else {
            return XCTFail("expected image block")
        }
        XCTAssertEqual(url.absoluteString, "https://boginfactory.com/img/watch-install.png")
        XCTAssertEqual(caption, "Watch app -> Available Apps -> Install")

        XCTAssertEqual(config.messages[1].audience, "all")
    }

    func test_unknownBlockType_isSkippedButRestOfConfigIntact() throws {
        let json = """
        { "version": 1, "messages": [ { "audience": "all", "blocks": [
            { "type": "carousel", "value": "unsupported future type" },
            { "type": "text", "value": "still here" }
        ] } ] }
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(WelcomeConfig.self, from: json)
        let blocks = config.messages[0].blocks
        XCTAssertEqual(blocks.count, 2)
        guard case .unknown = blocks[0] else { return XCTFail("expected unknown block") }
        guard case .text(let value, _, _, _) = blocks[1] else { return XCTFail("expected text block") }
        XCTAssertEqual(value, "still here")
    }

    func test_textBlockMissingValue_isSkipped() throws {
        let json = """
        { "version": 1, "messages": [ { "audience": "all", "blocks": [ { "type": "text" } ] } ] }
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(WelcomeConfig.self, from: json)
        guard case .unknown = config.messages[0].blocks[0] else {
            return XCTFail("expected unknown block for a text block missing its value")
        }
    }

    func test_nonHttpsImageURL_isSkipped() throws {
        let json = """
        { "version": 1, "messages": [ { "audience": "all", "blocks": [
            { "type": "image", "url": "http://insecure.example.com/x.png" }
        ] } ] }
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(WelcomeConfig.self, from: json)
        guard case .unknown = config.messages[0].blocks[0] else {
            return XCTFail("expected unknown block for a non-https image URL")
        }
    }

    func test_unknownAlignSizeColor_fallBackToDefaults() throws {
        let json = """
        { "version": 1, "messages": [ { "audience": "all", "blocks": [
            { "type": "text", "value": "hi", "align": "diagonal", "size": "huge", "color": "purple" }
        ] } ] }
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(WelcomeConfig.self, from: json)
        guard case .text(_, let align, let size, let color) = config.messages[0].blocks[0] else {
            return XCTFail("expected text block")
        }
        XCTAssertEqual(align, .leading)
        XCTAssertEqual(size, .body)
        XCTAssertEqual(color, .dark)
    }

    func test_unknownLinkDestination_isSkipped() throws {
        let json = """
        { "version": 1, "messages": [ { "audience": "all", "blocks": [
            { "type": "link", "label": "OPEN APP", "destination": "myapp://deeplink" }
        ] } ] }
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(WelcomeConfig.self, from: json)
        guard case .unknown = config.messages[0].blocks[0] else {
            return XCTFail("expected unknown block for a non-https, non-detail destination")
        }
    }

    func test_unknownAudienceString_decodesFine() {
        let json = """
        { "version": 1, "messages": [ { "audience": "some_future_audience", "blocks": [] } ] }
        """.data(using: .utf8)!
        XCTAssertNoThrow(try JSONDecoder().decode(WelcomeConfig.self, from: json))
    }

    func test_corruptJSON_throwsDecodeError() {
        let json = "{not json".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(WelcomeConfig.self, from: json))
    }

    func test_missingMessagesKey_throwsDecodeError() {
        let json = "{ \"version\": 1 }".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(WelcomeConfig.self, from: json))
    }
}

// MARK: - Selection logic

@MainActor
final class RemoteConfigSelectionTests: XCTestCase {

    private func makeRemoteConfig(messagesJSON: String) async -> RemoteConfig {
        let suite = "test.remoteconfig.selection.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let responseData = """
        { "welcome": { "version": 1, "messages": [ \(messagesJSON) ] } }
        """.data(using: .utf8)!
        let response = HTTPURLResponse(url: RemoteConfig.configURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let remoteConfig = RemoteConfig(defaults: defaults, fetchData: { _ in (responseData, response) })
        await remoteConfig.refresh()
        return remoteConfig
    }

    func test_watchNotInstalledMessage_choosesWhenWatchUnavailableSkipsWhenAvailable() async {
        let remoteConfig = await makeRemoteConfig(messagesJSON: """
        { "id": "watch", "audience": "watch_not_installed", "blocks": [] },
        { "id": "fallback", "audience": "all", "blocks": [] }
        """)
        XCTAssertEqual(remoteConfig.currentMessage(isWatchAvailable: false).id, "watch")
        XCTAssertEqual(remoteConfig.currentMessage(isWatchAvailable: true).id, "fallback")
    }

    func test_watchInstalledMessage_choosesWhenWatchAvailable() async {
        let remoteConfig = await makeRemoteConfig(messagesJSON: """
        { "id": "watch", "audience": "watch_installed", "blocks": [] },
        { "id": "fallback", "audience": "all", "blocks": [] }
        """)
        XCTAssertEqual(remoteConfig.currentMessage(isWatchAvailable: true).id, "watch")
        XCTAssertEqual(remoteConfig.currentMessage(isWatchAvailable: false).id, "fallback")
    }

    func test_allAudience_alwaysMatches() async {
        let remoteConfig = await makeRemoteConfig(messagesJSON: """
        { "id": "only", "audience": "all", "blocks": [] }
        """)
        XCTAssertEqual(remoteConfig.currentMessage(isWatchAvailable: true).id, "only")
        XCTAssertEqual(remoteConfig.currentMessage(isWatchAvailable: false).id, "only")
    }

    func test_noMatchingAudience_fallsBackToBundledDefault() async {
        let remoteConfig = await makeRemoteConfig(messagesJSON: """
        { "id": "orphan", "audience": "some_future_audience", "blocks": [] }
        """)
        let expected = RemoteConfig.defaultWelcome.messages[0].id
        XCTAssertEqual(remoteConfig.currentMessage(isWatchAvailable: false).id, expected)
    }

    func test_emptyMessagesList_fallsBackToBundledDefault() async {
        let remoteConfig = await makeRemoteConfig(messagesJSON: "")
        let expected = RemoteConfig.defaultWelcome.messages[0].id
        XCTAssertEqual(remoteConfig.currentMessage(isWatchAvailable: false).id, expected)
    }

    func test_noConfigEverLoaded_usesBundledDefault() {
        let suite = "test.remoteconfig.selection.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let remoteConfig = RemoteConfig(defaults: defaults, fetchData: { _ in throw URLError(.notConnectedToInternet) })
        let expected = RemoteConfig.defaultWelcome.messages[0].id
        XCTAssertEqual(remoteConfig.currentMessage(isWatchAvailable: false).id, expected)
    }
}

// MARK: - Fetch behavior

@MainActor
final class RemoteConfigFetchTests: XCTestCase {

    private func makeSuite() -> (defaults: UserDefaults, name: String) {
        let suite = "test.remoteconfig.fetch.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    private func httpResponse(status: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: RemoteConfig.configURL, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    func test_successfulRefresh_persistsRawBytesAndPublishes() async throws {
        let (defaults, suite) = makeSuite()
        defer { defaults.removePersistentDomain(forName: suite) }

        let json = """
        { "welcome": { "version": 1, "messages": [ { "id": "fresh", "audience": "all", "blocks": [] } ] } }
        """.data(using: .utf8)!
        let remoteConfig = RemoteConfig(defaults: defaults, fetchData: { _ in (json, self.httpResponse()) })

        XCTAssertNil(remoteConfig.welcome, "no cache yet, nothing fetched")
        await remoteConfig.refresh()

        let welcome = try XCTUnwrap(remoteConfig.welcome)
        XCTAssertEqual(welcome.messages.first?.id, "fresh")

        // A fresh instance reading the same UserDefaults suite sees the persisted bytes.
        let reopened = RemoteConfig(defaults: defaults)
        XCTAssertEqual(reopened.welcome?.messages.first?.id, "fresh")
    }

    func test_networkFailure_leavesCurrentStateUntouched() async {
        let (defaults, suite) = makeSuite()
        defer { defaults.removePersistentDomain(forName: suite) }

        let remoteConfig = RemoteConfig(defaults: defaults, fetchData: { _ in
            throw URLError(.notConnectedToInternet)
        })
        await remoteConfig.refresh()
        XCTAssertNil(remoteConfig.welcome)
    }

    func test_non200Response_leavesCurrentStateUntouched() async {
        let (defaults, suite) = makeSuite()
        defer { defaults.removePersistentDomain(forName: suite) }

        let remoteConfig = RemoteConfig(
            defaults: defaults,
            fetchData: { _ in ("{}".data(using: .utf8)!, self.httpResponse(status: 500)) }
        )
        await remoteConfig.refresh()
        XCTAssertNil(remoteConfig.welcome)
    }

    func test_missingWelcomeKey_leavesCurrentStateUntouched() async {
        let (defaults, suite) = makeSuite()
        defer { defaults.removePersistentDomain(forName: suite) }

        let json = "{ \"someOtherKey\": {} }".data(using: .utf8)!
        let remoteConfig = RemoteConfig(defaults: defaults, fetchData: { _ in (json, self.httpResponse()) })
        await remoteConfig.refresh()
        XCTAssertNil(remoteConfig.welcome)
    }

    func test_malformedWelcomeShape_leavesCurrentStateUntouched() async {
        let (defaults, suite) = makeSuite()
        defer { defaults.removePersistentDomain(forName: suite) }

        // Valid JSON, but "messages" is missing entirely — wrong shape.
        let json = "{ \"welcome\": { \"version\": 1 } }".data(using: .utf8)!
        let remoteConfig = RemoteConfig(defaults: defaults, fetchData: { _ in (json, self.httpResponse()) })
        await remoteConfig.refresh()
        XCTAssertNil(remoteConfig.welcome)
    }

    func test_throttle_skipsSecondRefreshWithin15Minutes() async {
        let (defaults, suite) = makeSuite()
        defer { defaults.removePersistentDomain(forName: suite) }

        var callCount = 0
        let json = """
        { "welcome": { "version": 1, "messages": [ { "id": "v", "audience": "all", "blocks": [] } ] } }
        """.data(using: .utf8)!
        let remoteConfig = RemoteConfig(defaults: defaults, fetchData: { _ in
            callCount += 1
            return (json, self.httpResponse())
        })

        await remoteConfig.refresh()
        XCTAssertEqual(callCount, 1)

        await remoteConfig.refresh()
        XCTAssertEqual(callCount, 1, "a second refresh inside the throttle window must not hit the network")
    }

    func test_throttle_doesNotSuppressTheFirstFetchAfterAFailure() async {
        let (defaults, suite) = makeSuite()
        defer { defaults.removePersistentDomain(forName: suite) }

        var callCount = 0
        let remoteConfig = RemoteConfig(defaults: defaults, fetchData: { _ in
            callCount += 1
            throw URLError(.notConnectedToInternet)
        })

        await remoteConfig.refresh()
        await remoteConfig.refresh()
        XCTAssertEqual(callCount, 2, "throttle only tracks successful fetches, so failures keep retrying")
    }
}
