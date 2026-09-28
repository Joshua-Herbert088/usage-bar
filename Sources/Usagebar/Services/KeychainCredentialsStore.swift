import Foundation
import Security

enum KeychainError: LocalizedError {
    case itemNotFound
    case unexpectedFormat
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "No Claude Code login found. Install Claude Code and run `claude` in your terminal to log in once."
        case .unexpectedFormat:
            return "Claude Code credentials were found but couldn't be read."
        case .decodingFailed(let error):
            return "Failed to parse Claude Code credentials: \(error.localizedDescription)"
        }
    }
}

/// Reads the OAuth credentials Claude Code (the CLI) already stores in the
/// macOS login Keychain, under the generic-password service
/// "Claude Code-credentials". This is the same item the `claude` CLI creates
/// and refreshes when you log in and use it — we never write to it, and the
/// token never leaves this machine except to call Anthropic's usage API
/// directly. The first read triggers a standard macOS Keychain access
/// prompt; choose "Always Allow" to avoid repeated prompts.
enum KeychainCredentialsStore {
    private static let service = "Claude Code-credentials"

    static func fetchCredentials() throws -> ClaudeCredentials.OAuth {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            throw KeychainError.itemNotFound
        }
        guard let data = item as? Data else {
            throw KeychainError.unexpectedFormat
        }

        do {
            let decoded = try JSONDecoder().decode(ClaudeCredentials.self, from: data)
            return decoded.claudeAiOauth
        } catch {
            throw KeychainError.decodingFailed(error)
        }
    }
}
