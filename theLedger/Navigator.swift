import Foundation

enum RootTab: String, CaseIterable, Hashable {
    case home, levies, log, spend, more
}

enum SubRoute: Hashable {
    case category(String)
    case reimbursements
    case ledger
    case importReview
    case moneyIn
    case report
    case refunds
    case teamSettings
    case cloudSync
}

/// Mirrors the prototype's single `{ tab, sub }` navigation state: a sub-screen
/// stacks over whatever the active tab is, and the tab bar stays visible throughout.
@Observable
final class Navigator {
    var tab: RootTab = .home
    var sub: SubRoute? = nil

    /// Set by "Log an expense to this line" so the Log screen can pre-select the category.
    var pendingLogCategoryCode: String? = nil

    func goTab(_ tab: RootTab) {
        self.tab = tab
        self.sub = nil
    }

    func push(_ route: SubRoute) {
        sub = route
    }

    func back() {
        sub = nil
    }

    func logExpense(prefillCategory code: String) {
        pendingLogCategoryCode = code
        tab = .log
        sub = nil
    }
}
