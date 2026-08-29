import Foundation

enum IncomeSource: String, CaseIterable, Identifiable, Hashable {
    case levy = "Levy"
    case sponsorship = "Sponsorship"
    case fundraising = "Fundraising"
    case otherIncome = "Other income"

    var id: String { rawValue }
}

enum ReimbursementStatus: Hashable {
    case pending
    case approved
    case paid
}

enum Position: String, CaseIterable, Identifiable, Hashable {
    case forward = "Forward"
    case defence = "Defence"
    case goalie = "Goalie"

    var id: String { rawValue }
}

enum StaffRole: String, CaseIterable, Identifiable, Hashable {
    case headCoach = "Head coach"
    case assistantCoach = "Assistant coach"
    case trainer = "Trainer"
    case teamManager = "Team manager"

    var id: String { rawValue }
}

enum SponsorStatus: Hashable {
    case received
    case committed
    case inConversation
}

struct Player: Identifiable, Hashable {
    let id: UUID
    var jerseyNumber: Int
    var name: String
    var position: Position
    /// Four instalment flags, in due-date order.
    var instalmentsPaid: [Bool]

    init(id: UUID = UUID(), jerseyNumber: Int, name: String, position: Position, instalmentsPaid: [Bool] = [false, false, false, false]) {
        self.id = id
        self.jerseyNumber = jerseyNumber
        self.name = name
        self.position = position
        self.instalmentsPaid = instalmentsPaid
    }

    var hasClearedLevy: Bool { instalmentsPaid.allSatisfy { $0 } }
}

struct StaffMember: Identifiable, Hashable {
    let id: UUID
    var name: String
    var role: StaffRole

    init(id: UUID = UUID(), name: String, role: StaffRole) {
        self.id = id
        self.name = name
        self.role = role
    }
}

/// Budget line. `actual` is never stored here — it is always derived from
/// the ledger so every screen stays consistent with a single source of truth.
struct BudgetCategory: Identifiable, Hashable {
    let id: String
    /// Internal code, never shown to the user.
    var code: String { id }
    var name: String
    var budget: Double

    init(code: String, name: String, budget: Double) {
        self.id = code
        self.name = name
        self.budget = budget
    }
}

struct LedgerEntry: Identifiable, Hashable {
    let id: UUID
    var date: Date
    var desc: String
    /// Money leaving the account.
    var withdrawal: Double?
    /// Money entering the account. Can be negative for a reversal (e.g. a levy un-toggle).
    var deposit: Double?
    /// Budget line this entry is tagged to, if it's an expense.
    var categoryCode: String?
    /// Revenue bucket this entry is tagged to, if it's a deposit.
    var incomeSource: IncomeSource?
    /// Ties a levy-instalment entry back to the player/instalment that created it,
    /// so re-tapping the square can find and reverse it.
    var levyTag: String?

    init(id: UUID = UUID(), date: Date, desc: String, withdrawal: Double? = nil, deposit: Double? = nil, categoryCode: String? = nil, incomeSource: IncomeSource? = nil, levyTag: String? = nil) {
        self.id = id
        self.date = date
        self.desc = desc
        self.withdrawal = withdrawal
        self.deposit = deposit
        self.categoryCode = categoryCode
        self.incomeSource = incomeSource
        self.levyTag = levyTag
    }
}

struct Reimbursement: Identifiable, Hashable {
    let id: UUID
    var who: String
    var desc: String
    var amount: Double
    var categoryCode: String
    var status: ReimbursementStatus
    var statusNote: String

    init(id: UUID = UUID(), who: String, desc: String, amount: Double, categoryCode: String, status: ReimbursementStatus, statusNote: String) {
        self.id = id
        self.who = who
        self.desc = desc
        self.amount = amount
        self.categoryCode = categoryCode
        self.status = status
        self.statusNote = statusNote
    }
}

struct Sponsor: Identifiable, Hashable {
    let id: UUID
    var name: String
    var meta: String
    var amount: Double
    var status: SponsorStatus

    init(id: UUID = UUID(), name: String, meta: String, amount: Double, status: SponsorStatus) {
        self.id = id
        self.name = name
        self.meta = meta
        self.amount = amount
        self.status = status
    }
}

struct Team {
    var name: String = "Oakville Rangers Hockey Club"
    var shortLabel: String = "ORHC · U12 AA"
    var division: String = "Tri-County AA · treasurer template"
    var founded: String = "Est. 1960 · Oakville, Ontario"
    var season: String = "2026/27"
    var bankMask: String = "Team chequing ····4417"
    var signingAuthority: String = "Treasurer + Manager"
    var levySchedule: String = "$1,000 × 4"
    var visibleTo: String = "Treasurer, Manager, Coaches"
    var seasonStart: Date = DateComponents(calendar: .current, year: 2026, month: 6, day: 1).date!
    var seasonEnd: Date = DateComponents(calendar: .current, year: 2027, month: 4, day: 30).date!
}
