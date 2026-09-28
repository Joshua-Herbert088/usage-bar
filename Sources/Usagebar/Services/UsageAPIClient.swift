import Foundation

enum UsageAPIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected response from Anthropic's usage API."
        case .httpError(let code):
            return code == 401
                ? "Login expired. Run `claude` in your terminal to log in again."
                : "Usage API returned HTTP \(code)."
        case .decodingFailed(let error):
            return "Failed to parse usage response: \(error.localizedDescription)"
        }
    }
}

/// Calls the same undocumented endpoint Claude Code's own CLI uses to power
/// its usage displays: `GET https://api.anthropic.com/api/oauth/usage`,
/// authenticated with the OAuth access token from Keychain. This is not a
/// published/stable Anthropic API — it was found by inspecting strings in
/// the `claude` CLI binary and may change without notice.
enum UsageAPIClient {
    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetchUsage(accessToken: String) async throws -> UsageResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw UsageAPIError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw UsageAPIError.httpError(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(UsageResponse.self, from: data)
        } catch {
            throw UsageAPIError.decodingFailed(error)
        }
    }
}
