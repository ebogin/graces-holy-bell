import SwiftUI

/// Settings sheet for configuring the Suggested Prayer Time feature.
///
/// Allows the user to set:
/// - Prayer interval (how often they want to be reminded)
/// - Notification destination (iPhone or Apple Watch)
struct SettingsView: View {

    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Interval", selection: $settings.intervalSeconds) {
                        ForEach(AppSettings.intervalOptions) { option in
                            Text(option.label).tag(option.seconds)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 150)
                } header: {
                    Text("Suggested Prayer Interval")
                } footer: {
                    Text("You will be notified when this interval has passed since your last prayer.")
                }

                Section("Notify On") {
                    Picker("Notify On", selection: $settings.notifyOnWatch) {
                        Text("iPhone").tag(false)
                        Text("Apple Watch").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
