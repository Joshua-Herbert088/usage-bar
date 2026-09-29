import AppKit

/// Programmatically invokes the SwiftUI `Settings` scene's window. There's
/// no app menu to click "Settings…" from in an LSUIElement (menu bar only)
/// app, so the dropdown's Settings button triggers this directly.
enum SettingsOpener {
    static func open() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
