import SwiftUI
import UniformTypeIdentifiers

struct BankLedgerView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(Navigator.self) private var nav
    @State private var showFileImporter = false

    private struct RunningRow: Identifiable {
        var id: UUID { entry.id }
        let entry: LedgerEntry
        let running: Double
    }

    private var rows: [RunningRow] {
        var run = 0.0
        var result: [RunningRow] = []
        for e in store.ledger {
            run += (e.deposit ?? 0) - (e.withdrawal ?? 0)
            result.append(RunningRow(entry: e, running: run))
        }
        return result.reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: { showFileImporter = true }) {
                    Text("Upload statement (CSV)")
                        .font(Theme.serif(15))
                        .foregroundStyle(Theme.accent700)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.sharpCorner)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                                .foregroundStyle(Theme.ink.opacity(0.35))
                        )
                }
                .buttonStyle(.plain)

                Button("Demo file") {
                    store.loadDemoStatement()
                    if !store.importedRows.isEmpty { nav.push(.importReview) }
                }
                .font(Theme.serif(14))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.divider))
            }
            .padding(.top, 14)

            Text("Export from the bank as CSV with Date, Description, Withdrawal, Deposit. Rows are matched to expense types and checked against what's already here. Swipe a transaction left to delete it.")
                .font(Theme.serif(12))
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .padding(.top, 6)
                .padding(.bottom, 4)

            HStack(spacing: 10) {
                Text("Item").frame(maxWidth: .infinity, alignment: .leading)
                Text("Amount").frame(width: 78, alignment: .trailing)
                Text("Balance").frame(width: 78, alignment: .trailing)
            }
            .font(Theme.serif(11))
            .tracking(1.0)
            .foregroundStyle(Theme.muted)
            .padding(.top, 14)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    SwipeToDeleteRow(onDelete: { store.deleteLedgerEntry(row.entry.id) }) {
                        LedgerRow(entry: row.entry, running: row.running)
                    }
                    .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            guard case .success(let url) = result else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
            store.parseStatement(text, fileName: url.lastPathComponent)
            if !store.importedRows.isEmpty { nav.push(.importReview) }
        }
    }
}

private struct LedgerRow: View {
    @Environment(LedgerStore.self) private var store
    let entry: LedgerEntry
    let running: Double

    private var metaSuffix: String {
        if let source = entry.incomeSource { return " · \(source.rawValue)" }
        if let code = entry.categoryCode, let name = store.category(for: code)?.name { return " · \(name)" }
        return ""
    }

    private var signed: String {
        if let dep = entry.deposit {
            return dep < 0 ? Formatting.money(dep) : "+" + Formatting.money(dep)
        }
        return "-" + Formatting.money(entry.withdrawal ?? 0)
    }

    private var amountColor: Color {
        if let dep = entry.deposit { return dep < 0 ? Theme.clubDarkRed : Theme.accent700 }
        return Theme.ink
    }
    private var isDepositPill: Bool { (entry.deposit ?? 0) > 0 }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.desc).font(Theme.serif(15)).foregroundStyle(Theme.ink)
                Text(Formatting.shortDate(entry.date) + metaSuffix)
                    .font(Theme.serif(12)).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(signed)
                .font(Theme.serif(15))
                .fontWeight(isDepositPill ? .semibold : .regular)
                .monospacedDigit()
                .foregroundStyle(amountColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(isDepositPill ? Theme.accent100 : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .frame(width: 86, alignment: .trailing)

            Text(Formatting.money(running))
                .font(Theme.serif(15))
                .monospacedDigit()
                .foregroundStyle(Theme.mutedStrong)
                .frame(width: 78, alignment: .trailing)
        }
        .padding(.vertical, 11)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
