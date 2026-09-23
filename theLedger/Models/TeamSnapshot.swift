import Foundation

/// A complete, self-contained copy of one team's data, for shipping to and
/// from CloudKit as a single JSON blob (see CloudSyncService). Deliberately
/// decoupled from the SwiftData @Model classes — those aren't directly
/// Codable-friendly, and this keeps the wire format stable even if the
/// local schema changes shape later.
struct TeamSnapshot: Codable {
    struct TeamDTO: Codable {
        var name: String
        var shortLabel: String
        var division: String
        var founded: String
        var season: String
        var bankMask: String
        var signingAuthority: String
        var levySchedule: String
        var visibleTo: String
        var seasonStart: Date
        var seasonEnd: Date
        var joinCode: String
        /// Optional on the wire so snapshots written before this field
        /// existed still decode — a missing key means "no link set".
        var sheetsURL: String?
    }
    struct PlayerDTO: Codable {
        var jerseyNumber: Int
        var name: String
        var position: Position
        var instalmentsPaid: [Bool]
    }
    struct StaffDTO: Codable {
        var name: String
        var role: StaffRole
    }
    struct CategoryDTO: Codable {
        var code: String
        var name: String
        var budget: Double
        var sortIndex: Int
    }
    struct LedgerDTO: Codable {
        var date: Date
        var desc: String
        var withdrawal: Double?
        var deposit: Double?
        var categoryCode: String?
        var incomeSource: IncomeSource?
        var levyTag: String?
        /// Optional on the wire so snapshots written before this field
        /// existed still decode — a missing key means "an ordinary entry,
        /// not one another screen owns".
        var origin: LedgerOrigin?
        var sequence: Int
    }
    struct ReimbursementDTO: Codable {
        var who: String
        var desc: String
        var amount: Double
        var categoryCode: String
        var status: ReimbursementStatus
        var statusNote: String
    }
    struct SponsorDTO: Codable {
        var name: String
        var meta: String
        var amount: Double
        var status: SponsorStatus
    }

    var team: TeamDTO
    var players: [PlayerDTO]
    var staff: [StaffDTO]
    var categories: [CategoryDTO]
    var ledger: [LedgerDTO]
    var reimbursements: [ReimbursementDTO]
    var sponsors: [SponsorDTO]
    var payers: [String]
}
