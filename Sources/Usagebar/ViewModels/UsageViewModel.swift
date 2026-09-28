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

    private var timer: Timer?

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
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.refresh() }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let credentials = try KeychainCredentialsStore.fetchCredentials()
            planLabel = (credentials.subscriptionType ?? "").capitalized

            let usage = try await UsageAPIClient.fetchUsage(accessToken: credentials.accessToken)

            fiveHourPercent = usage.fiveHour?.utilization
            fiveHourResetsAt = usage.fiveHour?.resetsAt.flatMap(parseDate)
            sevenDayPercent = usage.sevenDay?.utilization
            sevenDayResetsAt = usage.sevenDay?.resetsAt.flatMap(parseDate)
            lastUpdated = Date()
            errorMessage = nil

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
        } catch {
            errorMessage = error.localizedDescription
        }
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
