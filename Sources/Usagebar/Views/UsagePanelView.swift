import SwiftUI

enum ResetStyle {
    case relative
    case absolute
}

struct ProgressBar: View {
    let percent: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.15))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(max(percent, 0), 100) / 100))
            }
        }
        .clipShape(Capsule())
    }
}

struct UsageRow: View {
    let icon: String
    let title: String
    let percent: Double?
    let resetsAt: Date?
    let resetsStyle: ResetStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.terracotta)
                Text(title)
                    .font(.system(size: 13))
                Spacer()
                Text(percentLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
            }

            ProgressBar(percent: percent ?? 0, color: barColor)
                .frame(height: 6)

            if let resetText {
                Text(resetText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var percentLabel: String {
        guard let percent else { return "--" }
        return "\(Int(percent.rounded()))%"
    }

    private var barColor: Color {
        guard let percent else { return .gray }
        switch percent {
        case ..<50: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }

    private var resetText: String? {
        guard let resetsAt else { return nil }
        switch resetsStyle {
        case .relative:
            let interval = resetsAt.timeIntervalSinceNow
            guard interval > 0 else { return "Resets shortly" }
            let hours = Int(interval) / 3600
            let minutes = (Int(interval) % 3600) / 60
            return "Resets in \(hours)h \(minutes)m"
        case .absolute:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE h:mm a"
            return "Resets \(formatter.string(from: resetsAt))"
        }
    }
}

struct UsagePanelView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Claude Usage")
                    .font(.headline)
                Spacer()
                if !viewModel.planLabel.isEmpty {
                    Text(viewModel.planLabel)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.terracotta.opacity(0.15))
                        .foregroundColor(.terracotta)
                        .clipShape(Capsule())
                }
            }

            Divider()

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                UsageRow(
                    icon: "clock",
                    title: "5-Hour Window",
                    percent: viewModel.fiveHourPercent,
                    resetsAt: viewModel.fiveHourResetsAt,
                    resetsStyle: .relative
                )

                UsageRow(
                    icon: "calendar",
                    title: "Weekly",
                    percent: viewModel.sevenDayPercent,
                    resetsAt: viewModel.sevenDayResetsAt,
                    resetsStyle: .absolute
                )
            }

            Divider()

            HStack {
                if let updated = viewModel.lastUpdated {
                    Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
            }

            Divider()

            Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.system(size: 12))

            Divider()

            Button("Quit Usagebar") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.system(size: 12))
        }
        .padding(16)
        .frame(width: 280)
    }
}
