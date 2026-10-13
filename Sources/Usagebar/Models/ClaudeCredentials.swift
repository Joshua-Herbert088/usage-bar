import Foundation

/// Mirrors the JSON blob Claude Code (the CLI) stores in the macOS Keychain
/// under the generic-password service "Claude Code-credentials".
struct ClaudeCredentials: Decodable {
    struct OAuth: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Double?
        let subscriptionType: String?

        /// Claude Code stores `expiresAt` as milliseconds since the epoch.
        var expiryDate: Date? {
            expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) }
        }

        /// True once the token is expired or within `margin` of expiring.
        /// Tokens with no known expiry are treated as still valid; a 401
        /// from the API will force a re-read instead.
        func isExpired(margin: TimeInterval = 60) -> Bool {
            guard let expiryDate else { return false }
            return expiryDate.timeIntervalSinceNow < margin
        }
    }

    let claudeAiOauth: OAuth
}
