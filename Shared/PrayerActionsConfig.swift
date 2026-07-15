import Foundation

// MARK: - Prayer action manifest (remote-configurable)
//
// The ordered sequence of "actions" the praying figure performs after each
// PRAY swipe of a session (see ANIMATIONS.md). Decoded from the "animations"
// key of GET /app-config (grace-waitlist Worker), the same endpoint that
// serves the welcome message.
//
// This file is SHARED by the iPhone and Watch targets so both interpret the
// manifest identically. Decoding is deliberately tolerant everywhere —
// unknown fields are ignored, missing values fall back to defaults, and a
// missing/malformed `actions` list degrades to "no actions" (the figure just
// keeps praying) rather than failing the whole config. This is what lets new
// action fields be authored for newer app versions without breaking older
// ones still in the wild, per Apple's guideline against downloading code:
// the payload is declarative content, the app is the interpreter.
//
// SCAFFOLDING NOTE: the app currently renders a placeholder (a large "#N" plus
// a small animated icon) for each action — see PrayerActionView /
// WatchPrayerActionView. The real per-action artwork is keyed off `id` and is
// built separately; see HANDOFF-prayer-animations.md.

/// The whole manifest: an ordered list of actions plus a default duration.
struct PrayerActionsConfig: Decodable, Equatable {

    /// Schema version, for future migrations. Informational only today.
    var version: Int?

    /// Duration (seconds) used for any action that doesn't specify its own.
    var defaultDurationSeconds: Double?

    /// Ordered list of actions. The Nth PRAY of a session plays `actions[N-1]`;
    /// once the sequence is exhausted the figure simply keeps praying.
    var actions: [PrayerAction]

    /// Last-resort duration when neither the action nor the config specify one.
    static let fallbackDuration: Double = 5

    /// The action to play for a given 1-based prayer index, or nil when the
    /// index is past the end of the sequence (figure keeps praying).
    ///
    /// Selection is intentionally "clamp to sequence length, then stop" so the
    /// manifest reads as a finite story (kneel → walk → leave …). To loop or
    /// hold on the last action instead, change only this method.
    func action(forPrayerIndex index: Int) -> ResolvedPrayerAction? {
        guard index >= 1, index <= actions.count else { return nil }
        let action = actions[index - 1]
        let duration = action.durationSeconds ?? defaultDurationSeconds ?? Self.fallbackDuration
        return ResolvedPrayerAction(
            prayerIndex: index,
            actionID: action.id ?? "action-\(index)",
            durationSeconds: max(0.1, duration),
            label: action.label ?? "#\(index)"
        )
    }

    /// Bundled fallback so the feature works with no network / on first launch,
    /// and so both platforms behave identically before any remote fetch lands.
    ///
    /// SCAFFOLDING: five generic placeholder actions, 5 s each, labelled
    /// #1…#5. Swap the remote `animations` config (ANIMATIONS.md) — or this
    /// default — for the real action sequence; no app build required for the
    /// remote path.
    static let bundledDefault = PrayerActionsConfig(
        version: 1,
        defaultDurationSeconds: fallbackDuration,
        actions: (1...5).map { PrayerAction(id: "action-\($0)", durationSeconds: nil, label: nil) }
    )
}

/// One entry in the manifest. Every field is optional so a partial or
/// forward-dated action still decodes; the view resolves defaults.
struct PrayerAction: Decodable, Equatable {

    /// Stable identifier the real animation implementation keys its artwork on
    /// (e.g. "kneel", "walk-to-door"). Defaults to "action-<index>" when absent.
    var id: String?

    /// How long the action plays before the figure returns to praying. Falls
    /// back to the config's `defaultDurationSeconds`, then to `fallbackDuration`.
    var durationSeconds: Double?

    /// Placeholder caption shown by the current scaffolding. Defaults to the
    /// prayer index ("#1", "#2", …). The real animation ignores this.
    var label: String?
}

/// A concrete action resolved for a specific prayer index — exactly what the
/// placeholder view renders. Identity is the prayer index so replaying the
/// sequence after a session reset (index back to 1) re-triggers cleanly.
struct ResolvedPrayerAction: Equatable, Identifiable {
    /// 1-based position in the session — drives the "#N" placeholder label.
    let prayerIndex: Int
    /// The manifest action's stable id (real art hook).
    let actionID: String
    /// Seconds to display before reverting to the praying figure.
    let durationSeconds: Double
    /// Text the scaffolding shows large (defaults to "#<prayerIndex>").
    let label: String

    var id: Int { prayerIndex }
}

// MARK: - Tolerant decoding

extension PrayerActionsConfig {
    private enum CodingKeys: String, CodingKey {
        case version, defaultDurationSeconds, actions
    }

    /// Custom decoder so a missing/malformed `actions` list degrades to an
    /// empty sequence instead of throwing the whole config away. Kept in an
    /// extension so the memberwise initializer stays available for
    /// `bundledDefault`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try? container.decodeIfPresent(Int.self, forKey: .version)
        self.defaultDurationSeconds = try? container.decodeIfPresent(Double.self, forKey: .defaultDurationSeconds)
        self.actions = (try? container.decode([PrayerAction].self, forKey: .actions)) ?? []
    }
}
