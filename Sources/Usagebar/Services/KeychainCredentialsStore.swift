import Foundation

enum KeychainError: LocalizedError {
    case itemNotFound
    case unexpectedFormat
    case commandFailed(Int32)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "No Claude Code login found. Install Claude Code and run `claude` in your terminal to log in once."
        case .unexpectedFormat:
            return "Claude Code credentials were found but couldn't be read."
        case .commandFailed(let status):
            return "Couldn't read Claude Code credentials from Keychain (security exited with status \(status))."
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
/// directly.
///
/// We read it through `/usr/bin/security` rather than `SecItemCopyMatching`.
/// Claude Code writes the item with that same tool, so `security` is already
/// on the item's access list, and that list is rebuilt every time the CLI
/// refreshes its token. Reading it directly from this app would trigger a
/// Keychain password prompt after every token refresh, even after
/// "Always Allow".
enum KeychainCredentialsStore {
    private static let service = "Claude Code-credentials"
    private static let securityTool = URL(fileURLWithPath: "/usr/bin/security")
    /// `security`'s exit status for errSecItemNotFound.
    private static let itemNotFoundStatus: Int32 = 44

    static func fetchCredentials() throws -> ClaudeCredentials.OAuth {
        let process = Process()
        process.executableURL = securityTool
        process.arguments = ["find-generic-password", "-s", service, "-w"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        try process.run()
        // Drain the pipe before waiting so a large item can't fill the
        // pipe buffer and deadlock.
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        switch process.terminationStatus {
        case 0:
            break
        case itemNotFoundStatus:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.commandFailed(process.terminationStatus)
        }

        guard let text = String(data: output, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let data = text.data(using: .utf8),
              !data.isEmpty else {
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
