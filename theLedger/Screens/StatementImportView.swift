import SwiftUI

struct StatementImportView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(Navigator.self) private var nav

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selected").font(Theme.serif(12)).foregroundStyle(Theme.muted)
                    Text("\(store.importSelectedCount) of \(store.importedRows.count)").font(Theme.serif(19))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Net").font(Theme.serif(12)).foregroundStyle(Theme.muted)
                    Text(Formatting.signedMoney(store.importNet)).font(Theme.serif(19)).monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("New balance").font(Theme.serif(12)).foregroundStyle(Theme.muted)
                    Text(Formatting.money(store.importNewBalance)).font(Theme.serif(19)).monospacedDigit()
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 6)

            Text(store.importDuplicateNote + " Tap a row's type to change it.")
                .font(Theme.serif(12))
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(store.importedRows.enumerated()), id: \.element.id) { index, row in
                    ImportRowView(row: row, index: index)
                        .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
                }
            }

            HStack(spacing: 8) {
                Button("Merge into ledger") {
                    store.confirmImport()
                    nav.push(.ledger)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Discard") {
                    store.discardImport()
                    nav.push(.ledger)
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 110)
            }
            .padding(.top, 22)
        }
    }
}

private struct ImportRowView: View {
    @Environment(LedgerStore.self) private var store
    let row: ImportRow
    let index: Int

    private var amount: Double { row.deposit > 0 ? row.deposit : row.withdrawal }
    private var signed: String { (row.deposit > 0 ? "+" : "-") + Formatting.money(amount) }
    private var catLabel: String {
        row.categoryCode == "—" ? "Money in" : (store.category(for: row.categoryCode)?.name ?? row.categoryCode)
    }
    private var catColor: Color { row.categoryCode == "99" ? Theme.clubDarkRed : Theme.muted }
    private var meta: String {
        var s = row.dateLabel
        if row.isDuplicate { s += " · Looks like a duplicate" }
        if row.categoryCode == "99" && row.deposit == 0 { s += " · needs a type" }
        return s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 11) {
                Button(action: toggleIncluded) {
                    Text(row.included ? "✓" : "")
                        .font(Theme.serif(13))
                        .foregroundStyle(Theme.paper)
                        .frame(width: 24, height: 24)
                        .background(row.included ? Theme.accent : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(row.included ? Theme.accent : Theme.hairline))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.desc).font(Theme.serif(15))
                    Text(meta).font(Theme.serif(12)).foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: togglePicker) {
                    Text(catLabel)
                        .font(Theme.serif(13))
                        .foregroundStyle(catColor)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .overlay(Capsule().strokeBorder(Theme.divider))
                }
                .buttonStyle(.plain)

                Text(signed)
                    .font(Theme.serif(15))
                    .monospacedDigit()
                    .foregroundStyle(row.deposit > 0 ? Theme.accent700 : Theme.ink)
            }

            if row.categoryPickerOpen {
                WrapChips() {
                    ForEach(store.categories) { cat in
                        Chip(label: cat.name, isSelected: cat.code == row.categoryCode) {
                            store.importedRows[index].categoryCode = cat.code
                            store.importedRows[index].categoryPickerOpen = false
                        }
                    }
                }
                .padding(.leading, 35)
                .padding(.top, 10)
            }
        }
        .padding(.vertical, 11)
    }

    private func toggleIncluded() {
        store.importedRows[index].included.toggle()
    }
    private func togglePicker() {
        store.importedRows[index].categoryPickerOpen.toggle()
    }
}
