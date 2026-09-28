import SwiftUI

/// Small increasing-height bars, echoing the usage icon that lives in the
/// real macOS menu bar (see the app's own status item).
struct BarsIcon: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Capsule().frame(width: 2.5, height: 6)
            Capsule().frame(width: 2.5, height: 9)
            Capsule().frame(width: 2.5, height: 12)
        }
    }
}

struct MenuBarLabelView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        HStack(spacing: 4) {
            BarsIcon()
            if let percent = viewModel.fiveHourPercent {
                Text("\(Int(percent.rounded()))%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            } else if viewModel.errorMessage != nil {
                Text("—")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    }
}
