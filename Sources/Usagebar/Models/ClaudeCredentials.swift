import Foundation

/// Mirrors the JSON blob Claude Code (the CLI) stores in the macOS Keychain
/// under the generic-password service "Claude Code-credentials".
struct ClaudeCredentials: Decodable {
    struct OAuth: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Double?
        let subscriptionType: String?
    }

    let claudeAiOauth: OAuth
}
