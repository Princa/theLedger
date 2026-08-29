import SwiftUI

/// "Needs you" action row: title + meta on the left, a colored amount on the right.
struct ActionRow: View {
    let title: String
    let meta: String
    let amount: String
    let amountColor: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.serif(16))
                    Text(meta).font(Theme.serif(13)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Text(amount)
                    .font(Theme.serif(16))
                    .monospacedDigit()
                    .foregroundStyle(amountColor)
            }
            .padding(.vertical, 14)
            .frame(minHeight: Theme.rowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
    }
}

/// Budget-line row: name + "actual / budget", progress bar underneath.
struct CategoryProgressRow: View {
    let name: String
    let actualLabel: String
    let trailingLabel: String
    let pct: Int
    let barColor: Color
    let note: String?
    var barHeight: CGFloat = 5
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(name).font(Theme.serif(15))
                    Spacer()
                    Text(trailingLabel)
                        .font(Theme.serif(14))
                        .monospacedDigit()
                        .foregroundStyle(Theme.mutedStrong)
                }
                ProgressBarView(pct: pct, color: barColor, height: barHeight)
                if let note {
                    Text(note)
                        .font(Theme.serif(12))
                        .foregroundStyle(Theme.muted)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Plain (non-swipeable) transaction row: desc + date, signed amount.
struct TransactionRow: View {
    let desc: String
    let date: String
    let signed: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(desc).font(Theme.serif(15))
                Text(date).font(Theme.serif(12)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(signed)
                .font(Theme.serif(15))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
    }
}

/// Three-up figure row (Committed / Free to spend / Still to collect, Actual / Budget / Left, …).
struct StatTrio: View {
    struct Item {
        let label: String
        let value: String
        var color: Color = Theme.ink
    }
    let items: [Item]
    var valueSize: CGFloat = 14
    var spacing: CGFloat = 26

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label).font(Theme.serif(12)).foregroundStyle(Theme.muted)
                    Text(item.value)
                        .font(Theme.serif(valueSize))
                        .monospacedDigit()
                        .foregroundStyle(item.color)
                }
            }
        }
    }
}
