import SwiftUI

struct TreasurersReportView: View {
    @Environment(LedgerStore.self) private var store

    private struct Line {
        let label: String
        let value: String
        let size: CGFloat
        let color: Color
    }

    private var lines: [Line] {
        [
            Line(label: "Revenue received", value: Formatting.money(store.revenueReceived), size: 16, color: Theme.ink),
            Line(label: "Expenses paid", value: "-" + Formatting.money(store.totalSpent), size: 16, color: Theme.ink),
            Line(label: "Cash on hand", value: Formatting.money(store.balance), size: 22, color: Theme.ink),
            Line(label: "Committed but unpaid", value: "-" + Formatting.money(store.committed), size: 16, color: Theme.mutedStrong),
            Line(label: "Levies still to collect", value: Formatting.money(store.levyDue, cents: false), size: 16, color: Theme.mutedStrong),
            Line(label: "Budget remaining", value: Formatting.money(store.budgetRemaining), size: 16, color: Theme.mutedStrong),
            Line(label: "Projected season-end", value: Formatting.money(store.projectedSurplus), size: 22, color: store.projectedSurplus >= 0 ? Theme.accent700 : Theme.clubDarkRed),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Kicker(text: "Statement of position")
                .padding(.top, 14)

            VStack(spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline) {
                        Text(line.label).font(Theme.serif(line.size)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(line.value).font(Theme.serif(line.size)).monospacedDigit().foregroundStyle(line.color)
                    }
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
                }
            }

            Text("The report reads straight off the ledger, so it is current the moment a payment is recorded. Sending it emails a one-page statement and attaches the line-by-line workbook.")
                .font(Theme.serif(13))
                .foregroundStyle(Theme.mutedSoft)
                .lineSpacing(3)
                .padding(.top, 18)

            VStack(spacing: 10) {
                Button("Send to parents and staff") { store.sendReportToParents() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Export workbook (CSV)") { store.exportWorkbook() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.top, 24)
        }
    }
}
