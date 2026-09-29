import SwiftUI
import AppKit

@main
struct UsagebarApp: App {
    @StateObject private var viewModel = UsageViewModel()

    init() {
        Self.terminateIfAlreadyRunning()
    }

    /// A duplicate launch (e.g. re-opening the .app while an older instance
    /// is still around from a previous run) would double up the polling
    /// against Anthropic's usage API and make rate limiting worse. Bail out
    /// immediately if another instance already holds this bundle ID.
    private static func terminateIfAlreadyRunning() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if !others.isEmpty {
            // NSApplication.terminate(_:) relies on the run loop, which
            // hasn't started yet this early in App.init() — exit directly
            // so the duplicate never gets far enough to poll anything.
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            UsagePanelView(viewModel: viewModel)
        } label: {
            MenuBarLabelView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
