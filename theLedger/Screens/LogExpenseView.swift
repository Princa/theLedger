import SwiftUI

private enum LogKind { case expense, income }

struct LogExpenseView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(Navigator.self) private var nav

    @State private var kind: LogKind = .expense
    @State private var amountText: String = ""
    @State private var desc: String = ""
    @State private var categoryCode: String = "20"
    @State private var payer: String = "Team account"
    @State private var incomeSource: IncomeSource = .levy
    @State private var receiptAttached = false
    @State private var addingCategory = false
    @State private var newCategoryText = ""
    @State private var addingPayer = false
    @State private var newPayerText = ""
    @FocusState private var amountFocused: Bool

    private var amount: Double { Double(amountText) ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                DarkChip(label: "Money out", isSelected: kind == .expense) { kind = .expense }
                DarkChip(label: "Money in", isSelected: kind == .income) { kind = .income }
            }
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Amount")
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("$").font(Theme.serif(40)).foregroundStyle(Theme.ink)
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(Theme.serif(44))
                        .foregroundStyle(Theme.ink)
                        .tracking(-0.5)
                        .monospacedDigit()
                        .focused($amountFocused)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Theme.ink).frame(height: 2)
                        }
                }
            }
            .padding(.top, 16)

            Kicker(text: kind == .income ? "Received from" : "What was it for")
                .padding(.top, 28)
                .padding(.bottom, 8)
            TextField(
                kind == .income ? "e.g. Hillside Dental — rink board" : "e.g. Refs & timekeepers, home game",
                text: $desc
            )
            .font(Theme.serif(16))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .frame(height: 46)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.divider))
            .clipShape(RoundedRectangle(cornerRadius: Theme.sharpCorner))

            if kind == .income {
                incomeFields
            } else {
                expenseFields
            }
        }
        .onAppear {
            if let code = nav.pendingLogCategoryCode {
                categoryCode = code
                nav.pendingLogCategoryCode = nil
            }
        }
    }

    // MARK: - Income

    private var incomeFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            Kicker(text: "Where it came from")
                .padding(.top, 28)
                .padding(.bottom, 8)
            WrapChips() {
                ForEach(IncomeSource.allCases) { source in
                    Chip(label: source.rawValue, isSelected: incomeSource == source) { incomeSource = source }
                }
            }

            Text(incomeNote)
                .font(Theme.serif(14))
                .foregroundStyle(Theme.mutedSoft)
                .lineSpacing(3)
                .padding(.top, 24)

            primaryButton(label: "Record deposit") {
                if store.logIncome(amount: amount, desc: desc, source: incomeSource) {
                    resetForm()
                    nav.goTab(.home)
                }
            }
            .padding(.top, 16)
        }
    }

    private var incomeNote: String {
        guard amount > 0 else { return "Deposits post straight to the ledger and to Money in." }
        return "\(Formatting.money(amount)) in from \(incomeSource.rawValue.lowercased()) brings the balance to \(Formatting.money(store.balance + amount))."
    }

    // MARK: - Expense

    private var expenseFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            Kicker(text: "What kind of expense")
                .padding(.top, 28)
                .padding(.bottom, 8)
            WrapChips() {
                ForEach(store.categories) { cat in
                    Chip(label: cat.name, isSelected: categoryCode == cat.code) { categoryCode = cat.code }
                }
                DashedAddChip(label: "+ New type") {
                    addingCategory.toggle()
                    newCategoryText = ""
                }
            }
            if addingCategory {
                HStack(spacing: 6) {
                    TextField("e.g. Skills clinic", text: $newCategoryText)
                        .font(Theme.serif(15))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 40)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.divider))
                    Button("Add") {
                        if let code = store.addCategory(named: newCategoryText) {
                            categoryCode = code
                            addingCategory = false
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                }
                .padding(.top, 8)
            }

            Kicker(text: "Paid by")
                .padding(.top, 28)
                .padding(.bottom, 8)
            WrapChips() {
                ForEach(store.payers, id: \.self) { p in
                    Chip(label: p, isSelected: payer == p) { payer = p }
                }
                DashedAddChip(label: "+ New person") {
                    addingPayer.toggle()
                    newPayerText = ""
                }
            }
            if addingPayer {
                HStack(spacing: 6) {
                    TextField("Parent or staff name", text: $newPayerText)
                        .font(Theme.serif(15))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 40)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.divider))
                    Button("Add") {
                        if let name = store.addPayer(named: newPayerText) {
                            payer = name
                            addingPayer = false
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                }
                .padding(.top, 8)
            }

            Kicker(text: "Receipt")
                .padding(.top, 28)
                .padding(.bottom, 8)
            Button(action: { receiptAttached.toggle() }) {
                Text(receiptAttached ? "✓ receipt-dec16.jpg attached" : "Photograph or attach a receipt")
                    .font(Theme.serif(15))
                    .foregroundStyle(receiptAttached ? Theme.accent700 : Theme.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 88)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.sharpCorner)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .foregroundStyle(Theme.ink.opacity(0.35))
                    )
            }
            .buttonStyle(.plain)

            Text(formNote)
                .font(Theme.serif(14))
                .foregroundStyle(Theme.mutedSoft)
                .lineSpacing(3)
                .padding(.top, 24)

            primaryButton(label: saveLabel) {
                if store.logExpense(amount: amount, desc: desc, categoryCode: categoryCode, payer: payer) {
                    resetForm()
                    nav.goTab(.home)
                }
            }
            .padding(.top, 16)
        }
    }

    private var saveLabel: String { payer == "Team account" ? "Record expense" : "Queue reimbursement" }

    private var formNote: String {
        guard amount > 0 else { return "Pick a line and an amount and the effect on the balance shows here before you save." }
        if payer == "Team account" {
            let cat = store.category(for: categoryCode)
            let remaining = (cat?.budget ?? 0) - store.actualSpend(for: categoryCode) - amount
            return "\(Formatting.money(amount)) from the team account leaves \(Formatting.money(store.balance - amount)) on hand and \(Formatting.money(remaining)) on \(cat?.name ?? "")."
        }
        return "\(Formatting.money(amount)) paid by \(payer) will queue as a reimbursement and hold against the balance."
    }

    private func resetForm() {
        amountText = ""
        desc = ""
        receiptAttached = false
        addingCategory = false
        addingPayer = false
    }

    private func primaryButton(label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(PrimaryButtonStyle())
    }
}

/// A simple flow layout for chip rows that wraps onto multiple lines.
struct WrapChips: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.serif(compact ? 14 : 16))
            .foregroundStyle(Theme.paper)
            .frame(maxWidth: compact ? nil : .infinity)
            .frame(height: compact ? 40 : 50)
            .padding(.horizontal, compact ? 14 : 0)
            .background(configuration.isPressed ? Theme.accent700 : Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.sharpCorner))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.serif(15))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(configuration.isPressed ? Theme.surface : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.divider))
            .clipShape(RoundedRectangle(cornerRadius: Theme.sharpCorner))
    }
}
