import SwiftUI

struct ReimbursementQueueView: View {
    @Environment(LedgerStore.self) private var store

    var body: some View {
        PlainScrollScreen {
            VStack(alignment: .leading, spacing: 2) {
                Text("Owed to parents and staff").font(Theme.serif(12)).foregroundStyle(Theme.muted)
                Text(Formatting.money(store.pendingReimbursementTotal)).font(Theme.heroReimbTotal).monospacedDigit().foregroundStyle(Theme.ink)
            }
            .padding(.vertical, 18)

            VStack(spacing: 0) {
                ForEach(store.reimbursements) { r in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(r.who).font(Theme.serif(17)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(Formatting.money(r.amount)).font(Theme.serif(17)).monospacedDigit().foregroundStyle(Theme.ink)
                        }
                        Text(r.desc).font(Theme.serif(14)).foregroundStyle(Theme.ink).padding(.top, 2)
                        Text("\(r.statusNote) · \(store.category(for: r.categoryCode)?.name ?? "")")
                            .font(Theme.serif(12)).foregroundStyle(Theme.muted).padding(.top, 2)

                        HStack(spacing: 10) {
                            StatusTag(text: statusLabel(r.status), background: statusBg(r.status), foreground: statusFg(r.status))
                            if r.status != .paid {
                                Button(r.status == .pending ? "Approve" : "Pay by e-transfer") {
                                    store.actOnReimbursement(r.id)
                                }
                                .buttonStyle(PrimaryButtonStyle(compact: true))
                            }
                        }
                        .padding(.top, 12)
                    }
                    .padding(.vertical, 16)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
                }
            }

            Text("Approving holds the amount against the balance; paying writes it to the bank ledger and the budget line.")
                .font(Theme.serif(13))
                .foregroundStyle(Theme.mutedStrong)
                .lineSpacing(3)
                .padding(.top, 16)
                .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
        }
    }

    private func statusLabel(_ s: ReimbursementStatus) -> String {
        switch s {
        case .pending: return "Awaiting approval"
        case .approved: return "Approved"
        case .paid: return "Paid"
        }
    }
    private func statusBg(_ s: ReimbursementStatus) -> Color {
        switch s {
        case .pending: return Theme.clubRed.opacity(0.14)
        case .approved: return Theme.accent100
        case .paid: return Theme.neutral100
        }
    }
    private func statusFg(_ s: ReimbursementStatus) -> Color {
        switch s {
        case .pending: return Theme.clubDarkRed
        case .approved: return Theme.accent800
        case .paid: return Theme.neutral800
        }
    }
}
