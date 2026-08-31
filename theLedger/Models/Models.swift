import Foundation
import SwiftData

enum IncomeSource: String, CaseIterable, Identifiable, Codable {
    case levy = "Levy"
    case sponsorship = "Sponsorship"
    case fundraising = "Fundraising"
    case otherIncome = "Other income"

    var id: String { rawValue }
}

enum ReimbursementStatus: String, Codable {
    case pending
    case approved
    case paid
}

enum Position: String, CaseIterable, Identifiable, Codable {
    case forward = "Forward"
    case defence = "Defence"
    case goalie = "Goalie"

    var id: String { rawValue }
}

enum StaffRole: String, CaseIterable, Identifiable, Codable {
    case headCoach = "Head coach"
    case assistantCoach = "Assistant coach"
    case trainer = "Trainer"
    case teamManager = "Team manager"

    var id: String { rawValue }
}

enum SponsorStatus: String, Codable {
    case received
    case committed
    case inConversation
}

// MARK: - Persisted models
//
// SwiftData-backed so every edit survives an app restart/update, and so
// this schema can later sync through a CloudKit-backed store without a
// data migration. No @Attribute(.unique) constraints — CloudKit-backed
// SwiftData stores don't support them, and this app is headed there.

@Model
final class Player {
    var id: UUID = UUID()
    var jerseyNumber: Int = 0
    var name: String = ""
    var position: Position = Position.forward
    /// Four instalment flags, in due-date order.
    var instalmentsPaid: [Bool] = [false, false, false, false]

    init(id: UUID = UUID(), jerseyNumber: Int, name: String, position: Position, instalmentsPaid: [Bool] = [false, false, false, false]) {
        self.id = id
        self.jerseyNumber = jerseyNumber
        self.name = name
        self.position = position
        self.instalmentsPaid = instalmentsPaid
    }

    var hasClearedLevy: Bool { instalmentsPaid.allSatisfy { $0 } }
}

@Model
final class StaffMember {
    var id: UUID = UUID()
    var name: String = ""
    var role: StaffRole = StaffRole.assistantCoach

    init(id: UUID = UUID(), name: String, role: StaffRole) {
        self.id = id
        self.name = name
        self.role = role
    }
}

/// Budget line. `actual` is never stored here — it is always derived from
/// the ledger so every screen stays consistent with a single source of truth.
@Model
final class BudgetCategory {
    /// Internal code, never shown to the user.
    var code: String = ""
    var name: String = ""
    var budget: Double = 0
    /// Stable display order — codes aren't reliably sortable as strings
    /// ("100" would sort before "20"), and SwiftData fetch order isn't
    /// guaranteed without an explicit sort key.
    var sortIndex: Int = 0

    init(code: String, name: String, budget: Double, sortIndex: Int = 0) {
        self.code = code
        self.name = name
        self.budget = budget
        self.sortIndex = sortIndex
    }

    var id: String { code }
}

@Model
final class LedgerEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var desc: String = ""
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
    /// Insertion order. The ledger is deliberately shown in the order
    /// entries were recorded, not sorted by `date` — a CSV import can add
    /// entries dated earlier than ones already on screen, and they should
    /// still land at the end, not reshuffle everything above them.
    var sequence: Int = 0

    init(id: UUID = UUID(), date: Date, desc: String, withdrawal: Double? = nil, deposit: Double? = nil, categoryCode: String? = nil, incomeSource: IncomeSource? = nil, levyTag: String? = nil, sequence: Int = 0) {
        self.id = id
        self.date = date
        self.desc = desc
        self.withdrawal = withdrawal
        self.deposit = deposit
        self.categoryCode = categoryCode
        self.incomeSource = incomeSource
        self.levyTag = levyTag
        self.sequence = sequence
    }
}

@Model
final class Reimbursement {
    var id: UUID = UUID()
    var who: String = ""
    var desc: String = ""
    var amount: Double = 0
    var categoryCode: String = ""
    var status: ReimbursementStatus = ReimbursementStatus.pending
    var statusNote: String = ""

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

@Model
final class Sponsor {
    var id: UUID = UUID()
    var name: String = ""
    var meta: String = ""
    var amount: Double = 0
    var status: SponsorStatus = SponsorStatus.inConversation

    init(id: UUID = UUID(), name: String, meta: String, amount: Double, status: SponsorStatus) {
        self.id = id
        self.name = name
        self.meta = meta
        self.amount = amount
        self.status = status
    }
}

/// A person "Log an expense" can be paid by, beyond the default "Team account".
@Model
final class Payer {
    var name: String = ""
    init(name: String) { self.name = name }
}

@Model
final class Team {
    var name: String = "Oakville Rangers Hockey Club"
    var shortLabel: String = "ORHC · U12 AA"
    var division: String = "Tri-County AA · treasurer template"
    var founded: String = "Est. 1960 · Oakville, Ontario"
    var season: String = "2026/27"
    var bankMask: String = "Team chequing ····4417"
    var signingAuthority: String = "Treasurer + Manager"
    var levySchedule: String = "$1,000 × 4"
    var visibleTo: String = "Treasurer, Manager, Coaches"
    var seasonStart: Date = DateComponents(calendar: .current, year: 2026, month: 9, day: 1).date!
    var seasonEnd: Date = DateComponents(calendar: .current, year: 2027, month: 4, day: 30).date!
    /// The code another device/user will use to join this team's shared data
    /// once cloud sync is wired up. Generated once, stable thereafter.
    var joinCode: String = Team.generateJoinCode()

    init() {}

    static func generateJoinCode() -> String {
        // Excludes visually ambiguous characters (0/O, 1/I/L).
        let alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
        return String((0..<8).compactMap { _ in alphabet.randomElement() })
    }
}
