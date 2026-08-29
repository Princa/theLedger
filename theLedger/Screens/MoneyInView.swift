import SwiftUI

struct MoneyInView: View {
    @Environment(LedgerStore.self) private var store

    private var deposits: [LedgerEntry] {
        store.ledger.filter { ($0.deposit ?? 0) != 0 }.reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Received YTD").font(Theme.serif(12)).foregroundStyle(Theme.muted)
                Text(Formatting.money(store.revenueReceived, cents: false)).font(Theme.heroReimbTotal).monospacedDigit()
                Text("Against a season plan of \(Formatting.money(store.projectedRevenue, cents: false)).")
                    .font(Theme.serif(13)).foregroundStyle(Theme.mutedStrong)
            }
            .padding(.vertical, 12)
            .padding(.bottom, 8)

            VStack(spacing: 22) {
                revenueLine(
                    name: "Player levies", actual: store.levyIncome, target: store.levyTarget,
                    note: "\(store.roster.count) players × $1,000 × 4 instalments."
                )
                revenueLine(
                    name: "Sponsorship", actual: store.sponsorshipIncome, target: store.sponsorshipSeasonTarget,
                    note: "\(store.sponsors.filter { $0.status == .received }.count) of \(store.sponsors.count) sponsors received."
                )
                revenueLine(
                    name: "Fundraising", actual: store.fundraisingIncome, target: store.fundraisingIncome,
                    note: "Tracked as fundraising deposits come in."
                )
            }

            Kicker(text: "Deposits received")
                .padding(.top, 24)
                .padding(.bottom, 6)
            VStack(spacing: 0) {
                ForEach(deposits) { entry in
                    SwipeToDeleteRow(onDelete: { store.deleteLedgerEntry(entry.id) }) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.desc).font(Theme.serif(15))
                                Text(Formatting.shortDate(entry.date) + (entry.incomeSource.map { " · \($0.rawValue)" } ?? ""))
                                    .font(Theme.serif(12)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Text(Formatting.signedMoney(entry.deposit ?? 0))
                                .font(Theme.serif(15))
                                .monospacedDigit()
                                .foregroundStyle(Theme.accent700)
                        }
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
                }
            }

            Kicker(text: "Sponsors")
                .padding(.top, 28)
                .padding(.bottom, 6)
            VStack(spacing: 0) {
                ForEach(store.sponsors) { sponsor in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sponsor.name).font(Theme.serif(15))
                            Text(sponsor.meta).font(Theme.serif(12)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Text(sponsor.status == .received ? "+" + Formatting.money(sponsor.amount, cents: false) : Formatting.money(sponsor.amount, cents: false))
                            .font(Theme.serif(15))
                            .monospacedDigit()
                            .foregroundStyle(sponsor.status == .received ? Theme.accent700 : Theme.muted)
                    }
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
                }
            }
        }
    }

    private func revenueLine(name: String, actual: Double, target: Double, note: String) -> some View {
        let pct = target > 0 ? min(100, Int((actual / target * 100).rounded())) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(name).font(Theme.serif(17))
                Spacer()
                Text("\(Formatting.money(actual, cents: false)) / \(Formatting.money(target, cents: false))")
                    .font(Theme.serif(14)).monospacedDigit().foregroundStyle(Theme.mutedStrong)
            }
            ProgressBarView(pct: pct, color: Theme.accent, height: 5)
            Text(note).font(Theme.serif(13)).foregroundStyle(Theme.mutedStrong)
        }
    }
}
