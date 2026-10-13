import Foundation

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var fiveHourPercent: Double?
    @Published var fiveHourResetsAt: Date?
    @Published var sevenDayPercent: Double?
    @Published var sevenDayResetsAt: Date?
    @Published var planLabel: String = ""
    @Published var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published var isRefreshing = false
    @Published var launchAtLogin: Bool = LaunchAtLoginManager.isEnabled {
        didSet {
            guard launchAtLogin != oldValue else { return }
            LaunchAtLoginManager.setEnabled(launchAtLogin)
        }
    }
    @Published var notificationsEnabled: Bool = (UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true) {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }

    private var timer: Timer?
    private var cooldownUntil: Date?
    /// Keychain reads are only repeated when this token expires or the API
    /// rejects it, not on every 90s poll.
    private var cachedCredentials: ClaudeCredentials.OAuth?

    private let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let plainFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    init() {
        NotificationManager.shared.requestAuthorizationIfNeeded()
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 90, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.refresh() }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() async {
        if let cooldownUntil, cooldownUntil > Date() {
            // Still backing off from a recent 429 — skip this poll rather
            // than making the rate limit worse.
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            var credentials = try await currentCredentials()
            let usage: UsageResponse
            do {
                usage = try await UsageAPIClient.fetchUsage(accessToken: credentials.accessToken)
            } catch UsageAPIError.httpError(401, _) {
                // The CLI may have refreshed the token before our cached
                // copy's expiry. Re-read once and retry only if it changed.
                let stale = credentials.accessToken
                cachedCredentials = nil
                credentials = try await currentCredentials()
                guard credentials.accessToken != stale else {
                    throw UsageAPIError.httpError(401, retryAfter: nil)
                }
                usage = try await UsageAPIClient.fetchUsage(accessToken: credentials.accessToken)
            }
            planLabel = (credentials.subscriptionType ?? "").capitalized

            fiveHourPercent = usage.fiveHour?.utilization
            fiveHourResetsAt = usage.fiveHour?.resetsAt.flatMap(parseDate)
            sevenDayPercent = usage.sevenDay?.utilization
            sevenDayResetsAt = usage.sevenDay?.resetsAt.flatMap(parseDate)
            lastUpdated = Date()
            errorMessage = nil
            cooldownUntil = nil

            if notificationsEnabled {
                NotificationManager.shared.evaluate(
                    windowID: "fiveHour",
                    title: "5-Hour Usage",
                    percent: fiveHourPercent,
                    resetsAt: fiveHourResetsAt
                )
                NotificationManager.shared.evaluate(
                    windowID: "sevenDay",
                    title: "Weekly Usage",
                    percent: sevenDayPercent,
                    resetsAt: sevenDayResetsAt
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            if case UsageAPIError.httpError(429, let retryAfter) = error {
                cooldownUntil = Date().addingTimeInterval(retryAfter ?? 120)
            }
        }
    }

    /// Returns the cached token while it's still valid; otherwise reads a
    /// fresh one from Keychain off the main thread (it spawns `security`).
    private func currentCredentials() async throws -> ClaudeCredentials.OAuth {
        if let cachedCredentials, !cachedCredentials.isExpired() {
            return cachedCredentials
        }
        let fresh = try await Task.detached {
            try KeychainCredentialsStore.fetchCredentials()
        }.value
        cachedCredentials = fresh
        return fresh
    }

    /// Anthropic returns timestamps like "2026-09-28T12:20:00.322843+00:00" —
    /// microsecond precision that ISO8601DateFormatter doesn't reliably
    /// parse. Truncate the fractional part to milliseconds before parsing.
    private func parseDate(_ string: String) -> Date? {
        let normalized = normalizeFractionalSeconds(string)
        return fractionalFormatter.date(from: normalized) ?? plainFormatter.date(from: normalized)
    }

    private func normalizeFractionalSeconds(_ string: String) -> String {
        guard let dotIndex = string.firstIndex(of: ".") else { return string }
        guard let offsetIndex = string[dotIndex...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) else {
            return string
        }
        let fractionalDigits = string[string.index(after: dotIndex)..<offsetIndex]
        let truncated = String(fractionalDigits.prefix(3))
        return string.replacingCharacters(in: dotIndex..<offsetIndex, with: "." + truncated)
    }
}
