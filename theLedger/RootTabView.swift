import SwiftUI

struct RootTabView: View {
    @State private var store = LedgerStore()
    @State private var nav = Navigator()
    @State private var edgeDragOffset: CGFloat = 0

    private let edgeStripWidth: CGFloat = 24
    private let backThreshold: CGFloat = 70

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                title: headerTitle,
                subtitle: headerSubtitle,
                isRoot: nav.sub == nil,
                onBack: nav.sub == nil ? nil : { nav.back() },
                asOf: store.asOfDate
            )

            ZStack(alignment: .leading) {
                content
                    .offset(x: edgeDragOffset)

                if nav.sub != nil {
                    Color.clear
                        .frame(width: edgeStripWidth)
                        .contentShape(Rectangle())
                        .gesture(edgeBackGesture)
                }
            }

            TabBar(selected: nav.tab) { tab in
                nav.goTab(tab)
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .toast(store.toastMessage)
        .environment(store)
        .environment(nav)
        .tint(Theme.accent)
    }

    /// Mirrors iOS's screen-edge interactive-pop: only recognized when the
    /// drag starts within the leading-edge strip, so it never competes with
    /// vertical scrolling or a row's own swipe-to-delete gesture.
    private var edgeBackGesture: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .local)
            .onChanged { value in
                edgeDragOffset = max(0, min(value.translation.width, 200))
            }
            .onEnded { value in
                let shouldGoBack = value.translation.width > backThreshold
                withAnimation(.easeOut(duration: 0.22)) {
                    edgeDragOffset = 0
                }
                if shouldGoBack {
                    nav.back()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let sub = nav.sub {
            switch sub {
            case .category(let code):
                CategoryDetailView(categoryCode: code)
            case .reimbursements:
                ReimbursementQueueView()
            case .ledger:
                BankLedgerView()
            case .importReview:
                StatementImportView()
            case .moneyIn:
                MoneyInView()
            case .report:
                TreasurersReportView()
            case .refunds:
                RefundsView()
            case .teamSettings:
                TeamSettingsView()
            }
        } else {
            switch nav.tab {
            case .home: DashboardView()
            case .levies: LevyTrackerView()
            case .log: LogExpenseView()
            case .spend: SpendingByLineView()
            case .more: MoreView()
            }
        }
    }

    private var headerTitle: String {
        if let sub = nav.sub {
            switch sub {
            case .category(let code): return store.category(for: code)?.name ?? "Line detail"
            case .reimbursements: return "Reimbursements"
            case .ledger: return "Bank ledger"
            case .importReview: return "Review statement"
            case .moneyIn: return "Money in"
            case .report: return "Treasurer's report"
            case .refunds: return "Refunds"
            case .teamSettings: return "Team & settings"
            }
        }
        switch nav.tab {
        case .home: return "This season"
        case .levies: return "Player levies"
        case .log: return "Log an expense"
        case .spend: return "Spending"
        case .more: return "More"
        }
    }

    private var headerSubtitle: String {
        if let sub = nav.sub {
            switch sub {
            case .category: return "Budget line detail"
            case .reimbursements:
                let count = store.reimbursements.filter { $0.status != .paid }.count
                return "\(count) awaiting you"
            case .ledger: return "Every movement, running balance"
            case .importReview: return store.importFileName.isEmpty ? "Imported transactions" : store.importFileName
            case .moneyIn: return "Levies, sponsorship, fundraising"
            case .report: return "As at \(Formatting.reportDate(store.asOfDate))"
            case .refunds: return "Projected season-end position"
            case .teamSettings: return store.team.name
            }
        }
        switch nav.tab {
        case .home: return "\(store.team.name) — \(store.team.season)"
        case .levies: return "$1,000 × 4 instalments · \(store.roster.count) players"
        case .log: return "Against a budget line"
        case .spend: return "Budget vs actual by line"
        case .more: return "Reports, revenue, roster"
        }
    }
}

/// Custom bottom tab bar with hand-drawn linework icons.
private struct TabBar: View {
    let selected: RootTab
    let onSelect: (RootTab) -> Void

    private struct TabSpec: Identifiable {
        let tab: RootTab
        let label: String
        let icon: CustomTabIcon.Kind
        var id: RootTab { tab }
    }

    private let tabs: [TabSpec] = [
        TabSpec(tab: .home, label: "Home", icon: .home),
        TabSpec(tab: .levies, label: "Levies", icon: .levies),
        TabSpec(tab: .log, label: "Log", icon: .log),
        TabSpec(tab: .spend, label: "Spend", icon: .spend),
        TabSpec(tab: .more, label: "More", icon: .more),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { spec in
                let isActive = spec.tab == selected
                Button(action: { onSelect(spec.tab) }) {
                    VStack(spacing: 4) {
                        CustomTabIcon(kind: spec.icon, isActive: isActive)
                        Text(spec.label)
                            .font(Theme.serif(11))
                            .tracking(0.4)
                    }
                    .foregroundStyle(isActive ? Theme.clubDarkRed : Theme.muted)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(
            Theme.paper
                .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
        )
    }
}

#Preview {
    RootTabView()
}
