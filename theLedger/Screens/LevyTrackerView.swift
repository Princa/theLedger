import SwiftUI

struct LevyTrackerView: View {
    @Environment(LedgerStore.self) private var store

    private let dueLabels = ["Jun 10", "Sep 1", "Oct 1", "Nov 1"]

    var body: some View {
        PlainScrollScreen {
            HStack(alignment: .top, spacing: 26) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Collected").font(Theme.serif(12)).foregroundStyle(Theme.muted)
                    Text(Formatting.money(store.levyIncome, cents: false)).font(Theme.serif(26)).monospacedDigit().foregroundStyle(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Outstanding").font(Theme.serif(12)).foregroundStyle(Theme.muted)
                    Text(Formatting.money(store.levyDue, cents: false)).font(Theme.serif(26)).monospacedDigit().foregroundStyle(Theme.clubDarkRed)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 6)

            Text("\(store.unpaidInstalment3Count) of \(store.roster.count) still owe instalment #3. Instalment #4 (Nov 1) has not been invoiced.")
                .font(Theme.serif(13))
                .foregroundStyle(Theme.mutedStrong)
                .lineSpacing(3)
                .padding(.bottom, 18)

            HStack(spacing: 10) {
                Text("#").font(Theme.serif(11)).tracking(1.0).frame(width: 34, alignment: .leading)
                Text("Player").font(Theme.serif(11)).tracking(1.0).frame(maxWidth: .infinity, alignment: .leading)
                Text(dueLabels.joined(separator: " · ")).font(Theme.serif(11)).tracking(1.0)
            }
            .foregroundStyle(Theme.muted)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(store.roster) { player in
                    HStack(spacing: 10) {
                        Text("\(player.jerseyNumber)")
                            .font(Theme.serif(14))
                            .monospacedDigit()
                            .foregroundStyle(Theme.muted)
                            .frame(width: 34, alignment: .leading)
                        Text(player.name)
                            .font(Theme.serif(15))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 7) {
                            ForEach(0..<4, id: \.self) { i in
                                InstalmentSquare(paid: player.instalmentsPaid[i]) {
                                    store.toggleInstalment(playerID: player.id, index: i)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 9)
                    .frame(minHeight: 44)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
                }
            }

            Text("Tap an instalment square to record or reverse a payment.")
                .font(Theme.serif(13))
                .foregroundStyle(Theme.muted)
                .padding(.top, 14)
        }
    }
}

private struct InstalmentSquare: View {
    let paid: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(paid ? "✓" : "")
                .font(Theme.serif(12))
                .foregroundStyle(Theme.paper)
                .frame(width: 26, height: 26)
                .background(paid ? Theme.accent : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 1).strokeBorder(paid ? Theme.accent : Theme.hairline))
        }
        .buttonStyle(.plain)
    }
}
