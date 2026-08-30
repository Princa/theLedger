import SwiftUI

struct MoreView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(Navigator.self) private var nav

    private struct Row {
        let label: String
        let meta: String
        let right: String
        let route: SubRoute
    }

    private var rows: [Row] {
        let pendingCount = store.reimbursements.filter { $0.status != .paid }.count
        return [
            Row(label: "Money in", meta: "Levies, sponsorship, fundraising", right: Formatting.money(store.revenueReceived, cents: false), route: .moneyIn),
            Row(label: "Reimbursements", meta: "\(pendingCount) awaiting action", right: Formatting.money(store.pendingReimbursementTotal), route: .reimbursements),
            Row(label: "Bank ledger", meta: "\(store.ledger.count) transactions · import a statement", right: Formatting.money(store.balance), route: .ledger),
            Row(label: "Treasurer's report", meta: "Statement, export, send to parents", right: Formatting.shortDate(store.asOfDate), route: .report),
            Row(label: "Refunds", meta: "Projected per-player position", right: Formatting.money(store.perPlayerRefund), route: .refunds),
            Row(label: "Team & settings", meta: "Roster, bench staff, signing authority", right: "\(store.roster.count) + \(store.staff.count)", route: .teamSettings),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows, id: \.label) { row in
                Button(action: { nav.push(row.route) }) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.label).font(Theme.serif(17)).foregroundStyle(Theme.ink)
                            Text(row.meta).font(Theme.serif(13)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Text(row.right).font(Theme.serif(15)).monospacedDigit().foregroundStyle(Theme.accent)
                    }
                    .padding(.vertical, 16)
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
            }
        }
        .padding(.top, 10)
    }
}
