import SwiftUI

struct SpendingByLineView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(Navigator.self) private var nav

    var body: some View {
        PlainScrollScreen {
            StatTrio(items: [
                .init(label: "Spent YTD", value: Formatting.money(store.categoryActualTotal, cents: false)),
                .init(label: "Budget", value: Formatting.money(store.budgetTotal, cents: false)),
                .init(label: "Remaining", value: Formatting.money(store.budgetRemaining, cents: false)),
            ], valueSize: 26)
            .padding(.top, 12)
            .padding(.bottom, 20)

            VStack(spacing: 18) {
                ForEach(store.categories) { cat in
                    let actual = store.actualSpend(for: cat.code)
                    let over = store.categoryIsOverBudget(cat)
                    CategoryProgressRow(
                        name: cat.name,
                        actualLabel: Formatting.money(actual),
                        trailingLabel: Formatting.money(actual),
                        pct: store.categoryPct(cat),
                        barColor: over ? Theme.clubRed : Theme.accent,
                        note: over
                            ? "\(Formatting.money(actual - cat.budget)) over budget"
                            : "\(Formatting.money(cat.budget - actual)) left of \(Formatting.money(cat.budget, cents: false))",
                        action: { nav.push(.category(cat.code)) }
                    )
                }
            }
        }
    }
}
