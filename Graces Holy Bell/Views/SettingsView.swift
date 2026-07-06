import SwiftUI
import UserNotifications

/// Settings panel — overlays the bottom content area of both IdleView and ActiveSessionView.
///
/// Contains the Amen Alarm section (duration picker, Phone toggle, Watch toggle),
/// a manual "Sync Up" force-reconcile row, Share, and the Privacy section. Alarm
/// changes persist automatically via AmenAlarmSettings (UserDefaults-backed).
///
/// Slides in from the left edge and exits to the left when dismissed.
struct SettingsView: View {

    @Bindable var settings: AmenAlarmSettings
    @Bindable var logExport: LogExportSettings
    let consent: AnalyticsConsent
    /// Whether a paired Watch with the app installed is present (grays the Sync Up row).
    var isWatchAvailable: Bool = false
    /// User tapped "Sync Up" — force a reconcile with the Watch.
    var onForceSync: () -> Void = {}
    @State private var showPrivacyPolicy = false
    @State private var showShareWithFriend = false

    /// 1px outline around the toggle switches, matching the duration dropdown.
    private let toggleBorder = Color(hex: "#4d6139")

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {

            // ── "SETTINGS" header label ──────────────────────────────────
            Text("SETTINGS")
                .font(.pixelFont(7))
                .foregroundStyle(Color.lcdMid)
                .frame(maxWidth: .infinity, alignment: .leading)

            // ── Settings container box (scrolls so the build row at the
            //    bottom is always reachable on shorter screens) ────────────
            ScrollView {
            VStack(spacing: 0) {

                // AMEN Alarm section heading
                settingsSectionHeader("AMEN Alarm")

                // Duration picker row
                durationRow()

                // Phone toggle row
                alarmToggleRow(
                    label: "  Phone",
                    isOn: $settings.phoneEnabled,
                    onChange: { enabled in
                        if enabled { requestNotificationPermission() }
                    }
                )

                // Watch toggle row
                alarmToggleRow(
                    label: "  Watch",
                    isOn: $settings.watchEnabled,
                    onChange: { enabled in
                        if enabled { requestNotificationPermission() }
                    }
                )

                divider()

                // PRAYER LOG section — save the session log to Notes on session end
                settingsSectionHeader("PRAYER LOG")
                alarmToggleRow(
                    label: "  Save Log to Notes",
                    isOn: $logExport.saveToNotesEnabled,
                    onChange: { _ in }
                )

                divider()

                // "Force Watch Sync" row — hidden from the UI for now (2026-06-30,
                // Eric's call: the reconcile is too slow to be a satisfying manual
                // action). The row, its wiring (isWatchAvailable/onForceSync below,
                // ContentView → PhoneConnectivityManager.forceSync()), and
                // syncUpRow() are all kept intact to revisit later — just not
                // rendered. Uncomment the two lines below to bring it back.
                // syncUpRow()
                // divider()

                // Share with a Friend — opens the personal QR / waitlist share sheet
                shareWithFriendRow()

                divider()

                // PRIVACY section — anonymous analytics opt-out + policy link
                settingsSectionHeader("PRIVACY")
                analyticsToggleRow()

                // Privacy Policy — opens the in-app policy sheet
                privacyPolicyRow()

                divider()

                // Build/version marker — last item; lets a tester confirm this
                // device's build matches the paired Watch (sync has no back-compat).
                buildVersionRow()
            }
            .background(Color.lcdLogInner)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.lcdLogBorder, lineWidth: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showShareWithFriend) {
            ShareWithFriendView()
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func settingsSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.pixelFont(9))
            .foregroundStyle(Color.lcdDark)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
    }

    @ViewBuilder
    private func durationRow() -> some View {
        HStack {
            Text("  Duration")
                .font(.pixelFont(9))
                .foregroundStyle(Color.lcdDark)

            Spacer()

            // Custom-styled Menu acting as a dropdown
            Menu {
                ForEach(AmenAlarmDuration.allCases) { option in
                    Button(option.label) {
                        settings.duration = option
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(settings.duration.label)
                        .font(.pixelFont(9))
                        .foregroundStyle(Color.lcdThumbText)
                    Text(">")
                        .font(.pixelFont(9))
                        .foregroundStyle(Color.lcdThumbText)
                        .rotationEffect(.degrees(90))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.lcdSlider)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.lcdDark, lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func alarmToggleRow(
        label: String,
        isOn: Binding<Bool>,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack {
            Text(label)
                .font(.pixelFont(9))
                .foregroundStyle(Color.lcdDark)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.lcdSlider)
                .overlay(
                    Capsule()
                        .stroke(toggleBorder, lineWidth: 1)
                )
                .onChange(of: isOn.wrappedValue) { _, newValue in onChange(newValue) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func analyticsToggleRow() -> some View {
        HStack {
            Text("  Anonymous Analytics")
                .font(.pixelFont(9))
                .foregroundStyle(Color.lcdDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { consent.enabled },
                set: { consent.enabled = $0 }
            ))
            .labelsHidden()
            .tint(Color.lcdSlider)
            .overlay(
                Capsule()
                    .stroke(toggleBorder, lineWidth: 1)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityIdentifier("analytics-consent-row")
    }

    @ViewBuilder
    private func syncUpRow() -> some View {
        HStack {
            Text("Force Watch Sync")
                .font(.pixelFont(9))
                .foregroundStyle(Color.lcdDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            // Green pill styled to match the Duration dropdown.
            Button {
                onForceSync()
            } label: {
                Text("Sync")
                    .font(.pixelFont(9))
                    .foregroundStyle(Color.lcdThumbText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.lcdSlider)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.lcdDark, lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .disabled(!isWatchAvailable)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .opacity(isWatchAvailable ? 1 : 0.4)
        .accessibilityIdentifier("sync-up-row")
    }

    @ViewBuilder
    private func shareWithFriendRow() -> some View {
        Button {
            showShareWithFriend = true
        } label: {
            HStack {
                Text("Share with a Friend")
                    .font(.pixelFont(9))
                    .foregroundStyle(Color.lcdDark)

                Spacer()

                Text(">")
                    .font(.pixelFont(9))
                    .foregroundStyle(Color.lcdMid)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            // Taller vertical padding so this text-only row matches the height of
            // the control rows (toggles / dropdown), which are taller than text.
            .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("share-with-friend-row")
    }

    @ViewBuilder
    private func privacyPolicyRow() -> some View {
        Button {
            showPrivacyPolicy = true
        } label: {
            HStack {
                Text("  Privacy Policy")
                    .font(.pixelFont(9))
                    .foregroundStyle(Color.lcdDark)

                Spacer()

                Text(">")
                    .font(.pixelFont(9))
                    .foregroundStyle(Color.lcdMid)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("privacy-policy-row")
    }

    @ViewBuilder
    private func buildVersionRow() -> some View {
        Text(AppVersion.label)
            .font(.pixelFont(7))
            .foregroundStyle(Color.lcdMid)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .accessibilityIdentifier("build-version-row")
    }

    @ViewBuilder
    private func divider() -> some View {
        Color.lcdLogBorder
            .frame(height: 1)
            .padding(.horizontal, 4)
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.lcdBackground.ignoresSafeArea()
        SettingsView(settings: AmenAlarmSettings(), logExport: LogExportSettings(), consent: AnalyticsConsent())
            .padding(16)
    }
}
