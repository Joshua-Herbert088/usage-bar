import Foundation
import ServiceManagement

/// Wraps SMAppService's "register the main app as a login item" flow
/// (macOS 13+). Requires running from a real, signed .app bundle — the
/// bare `swift run` executable has no bundle identifier to register.
enum LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                guard SMAppService.mainApp.status != .enabled else { return }
                try SMAppService.mainApp.register()
            } else {
                guard SMAppService.mainApp.status == .enabled else { return }
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("LaunchAtLoginManager: failed to \(enabled ? "enable" : "disable"): \(error)")
        }
    }
}
