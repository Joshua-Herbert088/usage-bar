import Foundation

enum UsageAPIError: LocalizedError {
    case invalidResponse
    case httpError(Int, retryAfter: TimeInterval?)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected response from Anthropic's usage API."
        case .httpError(let code, let retryAfter):
            switch code {
            case 401:
                return "Login expired. Run `claude` in your terminal to log in again."
            case 429:
                if let retryAfter, retryAfter >= 1 {
                    return "Rate limited by Anthropic's usage API — retrying in \(Int(retryAfter))s."
                }
                return "Rate limited by Anthropic's usage API — backing off."
            default:
                return "Usage API returned HTTP \(code)."
            }
        case .decodingFailed(let error):
            return "Failed to parse usage response: \(error.localizedDescription)"
        }
    }

    /// How long the caller should wait before retrying, when known.
    var retryAfter: TimeInterval? {
        if case .httpError(_, let retryAfter) = self { return retryAfter }
        return nil
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
            let retryAfter = (http.value(forHTTPHeaderField: "Retry-After")).flatMap(TimeInterval.init)
            throw UsageAPIError.httpError(http.statusCode, retryAfter: retryAfter)
        }

        do {
            return try JSONDecoder().decode(UsageResponse.self, from: data)
        } catch {
            throw UsageAPIError.decodingFailed(error)
        }
    }
}
