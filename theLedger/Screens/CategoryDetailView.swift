import SwiftUI

struct CategoryDetailView: View {
    let categoryCode: String
    @Environment(LedgerStore.self) private var store
    @Environment(Navigator.self) private var nav
    @State private var editingEntry: LedgerEntry?

    private var category: BudgetCategory? { store.category(for: categoryCode) }

    private var ledgerLines: [LedgerEntry] {
        store.ledger.filter { $0.categoryCode == categoryCode }
    }
    private var reimbLines: [Reimbursement] {
        store.reimbursements.filter { $0.categoryCode == categoryCode && $0.status != .paid }
    }

    var body: some View {
        let cat = category
        let actual = cat.map { store.actualSpend(for: $0.code) } ?? 0
        let budget = cat?.budget ?? 0
        let over = actual > budget
        let pct = cat.map { store.categoryPct($0) } ?? 0

        List {
            VStack(alignment: .leading, spacing: 0) {
                StatTrio(items: [
                    .init(label: "Actual", value: Formatting.money(actual)),
                    .init(label: "Budget", value: Formatting.money(budget, cents: false)),
                    .init(label: "Left", value: Formatting.money(budget - actual), color: over ? Theme.clubDarkRed : Theme.ink),
                ], valueSize: 26)
                .padding(.top, 12)
                .padding(.bottom, 18)

                ProgressBarView(pct: pct, color: over ? Theme.clubRed : Theme.accent, height: 5)

                Kicker(text: "Lines")
                    .padding(.top, 28)
                    .padding(.bottom, 6)
            }
            .bareListRow()

            ForEach(ledgerLines) { entry in
                FlatListRow {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.desc).font(Theme.serif(15)).foregroundStyle(Theme.ink)
                            Text("\(Formatting.shortDate(entry.date)) · paid from team account")
                                .font(Theme.serif(12)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Text(Formatting.money(entry.withdrawal ?? 0))
                            .font(Theme.serif(15))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { store.deleteLedgerEntry(entry.id) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .onTapGesture { editingEntry = entry }
            }

            ForEach(reimbLines) { r in
                FlatListRow {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.desc).font(Theme.serif(15)).foregroundStyle(Theme.ink)
                            Text("Reimbursement to \(r.who) · \(r.status == .pending ? "pending" : "approved")")
                                .font(Theme.serif(12)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Text(Formatting.money(r.amount))
                            .font(Theme.serif(15))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                }
            }

            Button("Log an expense to this line") {
                nav.logExpense(prefillCategory: categoryCode)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 24)
            .bareListRow()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.paper.ignoresSafeArea())
        .sheet(item: $editingEntry) { entry in
            EditTransactionSheet(entry: entry)
        }
    }
}
