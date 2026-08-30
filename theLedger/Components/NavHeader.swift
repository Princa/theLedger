import SwiftUI

/// Custom per-screen header replacing the system large-title bar: back chevron
/// (sub-screens) or team crest + short name (root tabs), a date badge top-right,
/// then the serif title and muted one-line subtitle.
struct ScreenHeader: View {
    let title: String
    let subtitle: String
    var isRoot: Bool = false
    var onBack: (() -> Void)? = nil
    let asOf: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                if isRoot {
                    HStack(spacing: 8) {
                        Image("RangersCrest")
                            .resizable()
                            .frame(width: 22, height: 22)
                        Text("ORHC · U12 AA")
                            .font(Theme.serif(11))
                            .tracking(1.2)
                            .foregroundStyle(Theme.ink)
                    }
                } else if let onBack {
                    Button(action: onBack) {
                        Text("‹ Back")
                            .font(Theme.serif(14))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(height: 24)
                }

                Spacer()

                Text(Formatting.badgeDate(asOf))
                    .font(Theme.serif(11))
                    .tracking(1.0)
                    .foregroundStyle(Theme.accent700)
            }
            .frame(minHeight: 24)

            Text(title)
                .font(Theme.navTitle)
                .tracking(-0.3)
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)

            Text(subtitle)
                .font(Theme.serif(13))
                .foregroundStyle(Theme.muted)
                .padding(.top, 4)
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}
