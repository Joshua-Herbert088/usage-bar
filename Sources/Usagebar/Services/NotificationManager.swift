import Foundation
import UserNotifications

/// Lets banners show even though the app is a background menu bar utility
/// with no foreground windows (LSUIElement) — without a delegate, macOS
/// suppresses local notifications from an "active" app.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

/// Fires a notification the first time usage crosses each of 50/75/90% for
/// a given window (5-hour or weekly), then stays quiet until that window
/// resets (tracked by its `resetsAt` timestamp) so it never repeats on
/// every 60s poll.
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let delegate = NotificationDelegate()
    private let tiers = [50, 75, 90]
    private var lastNotifiedTier: [String: Int] = [:]

    private init() {
        center.delegate = delegate
    }

    func requestAuthorizationIfNeeded() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(windowID: String, title: String, percent: Double?, resetsAt: Date?) {
        guard let percent, let resetsAt else { return }

        let currentKey = "\(windowID)|\(Int(resetsAt.timeIntervalSince1970))"
        for key in lastNotifiedTier.keys where key.hasPrefix("\(windowID)|") && key != currentKey {
            lastNotifiedTier.removeValue(forKey: key)
        }

        let alreadyNotified = lastNotifiedTier[currentKey] ?? 0
        guard let tier = tiers.last(where: { Double($0) <= percent }), tier > alreadyNotified else {
            return
        }
        lastNotifiedTier[currentKey] = tier

        send(title: title, percent: percent, tier: tier)
    }

    private func send(title: String, percent: Double, tier: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(title): \(tier)% reached"
        content.body = "You're at \(Int(percent.rounded()))% of your \(title.lowercased()) limit."
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request, withCompletionHandler: nil)
    }
}
