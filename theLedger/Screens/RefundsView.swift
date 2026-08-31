import SwiftUI

struct RefundsView: View {
    @Environment(LedgerStore.self) private var store

    private var surplus: Double { store.projectedSurplus }

    var body: some View {
        PlainScrollScreen {
            VStack(alignment: .leading, spacing: 6) {
                Kicker(text: "Projected per player")
                Text(Formatting.money(store.perPlayerRefund))
                    .font(Theme.heroRefund)
                    .tracking(-1.2)
                    .monospacedDigit()
                    .foregroundStyle(surplus >= 0 ? Theme.ink : Theme.clubDarkRed)
                Text(refundNote)
                    .font(Theme.serif(14))
                    .foregroundStyle(Theme.mutedSoft)
                    .lineSpacing(3)
            }
            .padding(.top, 14)
            .padding(.bottom, 4)

            Kicker(text: "Refund status")
                .padding(.top, 28)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(store.roster) { player in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(player.jerseyNumber)")
                            .font(Theme.serif(14)).monospacedDigit().foregroundStyle(Theme.muted)
                            .frame(width: 34, alignment: .leading)
                        Text(player.name).font(Theme.serif(15)).foregroundStyle(Theme.ink).frame(maxWidth: .infinity, alignment: .leading)
                        StatusTag(
                            text: player.hasClearedLevy ? "Levy clear" : "Levy owing",
                            background: player.hasClearedLevy ? Theme.accent100 : Theme.clubRed.opacity(0.14),
                            foreground: player.hasClearedLevy ? Theme.accent800 : Theme.clubDarkRed
                        )
                        Text(Formatting.money(store.perPlayerRefund))
                            .font(Theme.serif(15))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                            .frame(width: 62, alignment: .trailing)
                    }
                    .padding(.vertical, 11)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
                }
            }
        }
    }

    private var refundNote: String {
        surplus >= 0
            ? "A surplus of \(Formatting.money(surplus)) divided across \(store.roster.count) players, issued after the final ORHC assessment settles in April."
            : "A shortfall of \(Formatting.money(-surplus)). A top-up levy would be needed before season end."
    }
}
