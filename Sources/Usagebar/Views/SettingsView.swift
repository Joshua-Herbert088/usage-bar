import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)
            }

            Section {
                Toggle("Usage Notifications", isOn: $viewModel.notificationsEnabled)
                Text("Alerts once at 50%, 75%, and 90% usage for the 5-hour and weekly windows, then stays quiet until each one resets.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                LabeledContent("Version", value: appVersion)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 260)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
