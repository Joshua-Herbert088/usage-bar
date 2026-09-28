import Foundation

/// Partial model of the response from Anthropic's `/api/oauth/usage` endpoint.
/// The real payload has many more fields (spend, per-model breakdowns, etc.);
/// we only decode what the core menu bar loop needs. JSONDecoder ignores
/// unknown keys, so this stays forward-compatible.
struct UsageWindow: Decodable {
    let utilization: Double?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

struct UsageResponse: Decodable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}
