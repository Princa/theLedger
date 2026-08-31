import SwiftUI

/// Modal sheet for editing an existing ledger entry's description, amount,
/// date, and category/income-source tag. Presented by tapping a transaction
/// row on the category detail, bank ledger, or money-in screens.
struct EditTransactionSheet: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let entry: LedgerEntry

    @State private var desc: String
    @State private var amountText: String
    @State private var date: Date
    @State private var categoryCode: String
    @State private var incomeSource: IncomeSource

    init(entry: LedgerEntry) {
        self.entry = entry
        _desc = State(initialValue: entry.desc)
        let amount = entry.withdrawal ?? abs(entry.deposit ?? 0)
        _amountText = State(initialValue: amount == 0 ? "" : String(format: "%.2f", amount))
        _date = State(initialValue: entry.date)
        _categoryCode = State(initialValue: entry.categoryCode ?? "")
        _incomeSource = State(initialValue: entry.incomeSource ?? .otherIncome)
    }

    private var isExpense: Bool { entry.withdrawal != nil }
    private var amount: Double { Double(amountText) ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(Theme.serif(15))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(isExpense ? "Edit expense" : "Edit deposit")
                    .font(Theme.serif(17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Save") { save() }
                    .font(Theme.serif(15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 18)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Kicker(text: "Amount")
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("$").font(Theme.serif(32)).foregroundStyle(Theme.ink)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(Theme.serif(34))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.ink).frame(height: 2)
                            }
                    }
                    .padding(.top, 8)

                    Kicker(text: isExpense ? "What was it for" : "Received from")
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                    TextField("Description", text: $desc)
                        .font(Theme.serif(16))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 46)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.divider))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.sharpCorner))

                    Kicker(text: "Date")
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Theme.accent)

                    if isExpense {
                        Kicker(text: "What kind of expense")
                            .padding(.top, 24)
                            .padding(.bottom, 8)
                        WrapChips() {
                            ForEach(store.categories) { cat in
                                Chip(label: cat.name, isSelected: categoryCode == cat.code) { categoryCode = cat.code }
                            }
                        }
                    } else {
                        Kicker(text: "Where it came from")
                            .padding(.top, 24)
                            .padding(.bottom, 8)
                        WrapChips() {
                            ForEach(IncomeSource.allCases) { source in
                                Chip(label: source.rawValue, isSelected: incomeSource == source) { incomeSource = source }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 40)
            }
        }
        .background(Theme.paper.ignoresSafeArea())
    }

    private func save() {
        store.updateLedgerEntry(
            id: entry.id,
            date: date,
            desc: desc,
            amount: amount,
            categoryCode: isExpense ? categoryCode : nil,
            incomeSource: isExpense ? nil : incomeSource
        )
        dismiss()
    }
}
