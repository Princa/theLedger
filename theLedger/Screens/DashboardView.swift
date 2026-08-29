import SwiftUI

struct DashboardView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(Navigator.self) private var nav

    private var topCategories: [BudgetCategory] {
        store.categories.sorted { store.actualSpend(for: $0.code) > store.actualSpend(for: $1.code) }.prefix(5).map { $0 }
    }

    private var latestFour: [LedgerEntry] {
        Array(store.ledger.suffix(4).reversed())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cash on hand
            VStack(alignment: .leading, spacing: 8) {
                Kicker(text: "Cash on hand")
                Text(Formatting.money(store.balance))
                    .font(Theme.heroBalance)
                    .tracking(-1.2)
                    .monospacedDigit()
                StatTrio(items: [
                    .init(label: "Committed", value: Formatting.money(store.committed)),
                    .init(label: "Free to spend", value: Formatting.money(store.freeToSpend)),
                    .init(label: "Still to collect", value: Formatting.money(store.stillToCollect, cents: false)),
                ], valueSize: 14)
            }
            .padding(.top, 14)
            .padding(.bottom, 4)

            // Burn rate
            Kicker(text: "Burn rate")
                .padding(.top, 30)
                .padding(.bottom, 10)
            VStack(alignment: .leading, spacing: 14) {
                burnRow(label: "Season elapsed", pct: store.seasonElapsedPct, color: Theme.ink)
                burnRow(label: "Budget spent", pct: store.budgetSpentPct, color: Theme.accent)
                Text(store.burnNote)
                    .font(Theme.serif(13))
                    .foregroundStyle(Theme.mutedStrong)
                    .lineSpacing(3)
            }

            // Needs you
            Kicker(text: "Needs you")
                .padding(.top, 32)
                .padding(.bottom, 6)
            VStack(spacing: 0) {
                ForEach(inboxItems, id: \.title) { item in
                    ActionRow(title: item.title, meta: item.meta, amount: item.amount, amountColor: item.color, action: item.action)
                }
            }

            // Budget vs actual
            HStack(alignment: .firstTextBaseline) {
                Kicker(text: "Budget vs actual")
                Spacer()
                Button("All \(store.categories.count) lines") { nav.goTab(.spend) }
                    .font(Theme.serif(13))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.top, 32)
            .padding(.bottom, 6)
            VStack(spacing: 16) {
                ForEach(topCategories) { cat in
                    CategoryProgressRow(
                        name: cat.name,
                        actualLabel: Formatting.money(store.actualSpend(for: cat.code)),
                        trailingLabel: "\(Formatting.money(store.actualSpend(for: cat.code))) / \(Formatting.money(cat.budget, cents: false))",
                        pct: store.categoryPct(cat),
                        barColor: store.categoryIsOverBudget(cat) ? Theme.clubRed : Theme.accent,
                        note: nil,
                        action: { nav.push(.category(cat.code)) }
                    )
                }
            }

            // Latest transactions
            Kicker(text: "Latest transactions")
                .padding(.top, 32)
                .padding(.bottom, 6)
            VStack(spacing: 0) {
                ForEach(latestFour) { entry in
                    TransactionRow(
                        desc: entry.desc,
                        date: Formatting.shortDate(entry.date),
                        signed: signedAmount(entry),
                        color: signedColor(entry)
                    )
                }
                Button(action: { nav.push(.ledger) }) {
                    Text("Full bank ledger →")
                        .font(Theme.serif(14))
                        .foregroundStyle(Theme.accent)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
            }
        }
    }

    private func burnRow(label: String, pct: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(Theme.serif(14))
                Spacer()
                Text("\(pct)%").font(Theme.serif(14)).monospacedDigit()
            }
            ProgressBarView(pct: pct, color: color, height: 6)
        }
    }

    private func signedAmount(_ e: LedgerEntry) -> String {
        if let dep = e.deposit {
            return dep < 0 ? Formatting.money(dep) : "+" + Formatting.money(dep)
        }
        return "-" + Formatting.money(e.withdrawal ?? 0)
    }

    private func signedColor(_ e: LedgerEntry) -> Color {
        if let dep = e.deposit {
            return dep < 0 ? Theme.clubDarkRed : Theme.accent700
        }
        return Theme.ink
    }

    private struct InboxItem {
        let title: String
        let meta: String
        let amount: String
        let color: Color
        let action: () -> Void
    }

    private var inboxItems: [InboxItem] {
        let pendingCount = store.reimbursements.filter { $0.status != .paid }.count
        let unpaid3 = store.unpaidInstalment3Count
        let surplus = store.projectedSurplus
        return [
            InboxItem(
                title: "Reimbursements to approve",
                meta: "\(pendingCount) requests from parents and staff",
                amount: Formatting.money(store.pendingReimbursementTotal),
                color: Theme.clubDarkRed,
                action: { nav.push(.reimbursements) }
            ),
            InboxItem(
                title: "Instalment #3 unpaid",
                meta: "\(unpaid3) players outstanding since Oct 1",
                amount: Formatting.money(Double(unpaid3) * 1000, cents: false),
                color: Theme.clubDarkRed,
                action: { nav.goTab(.levies) }
            ),
            InboxItem(
                title: "Lake Placid deposit due",
                meta: store.scheduledPaymentNote,
                amount: Formatting.money(store.scheduledPaymentAmount, cents: false),
                color: Theme.ink,
                action: { nav.push(.category(store.scheduledPaymentCategoryCode)) }
            ),
            InboxItem(
                title: "Projected refund per player",
                meta: surplus >= 0
                    ? "Surplus of \(Formatting.money(surplus)) across \(store.roster.count) players"
                    : "Shortfall of \(Formatting.money(-surplus))",
                amount: Formatting.money(store.perPlayerRefund),
                color: surplus >= 0 ? Theme.accent700 : Theme.clubDarkRed,
                action: { nav.push(.refunds) }
            ),
        ]
    }
}
