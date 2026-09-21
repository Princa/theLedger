import Foundation
import CloudKit
import Observation

enum CloudSyncError: LocalizedError {
    case codeNotFound
    case notLinked
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .codeNotFound: return "No team found with that code. Double-check it and try again."
        case .notLinked: return "This device isn't linked to a shared team yet."
        case .notSignedIn: return "Sign in to iCloud in Settings to sync with other devices."
        }
    }
}

/// Hand-rolled CloudKit sync: the whole team's data lives as a single JSON
/// snapshot in one CKRecord in the app's PUBLIC database, keyed by a short
/// join code. SwiftData's own CloudKit integration only mirrors to a
/// single private account, not a "type a code, see someone else's data"
/// flow, so this talks to CloudKit directly instead.
///
/// Deliberately simple for a first version: sync is manual (Push / Pull),
/// not automatic-on-every-edit, and there's no field-by-field merge — the
/// whole snapshot moves as one unit, last write wins. That's an honest
/// trade for a small volunteer team, not a hidden limitation.
@Observable
final class CloudSyncService {
    @ObservationIgnored private let container = CKContainer(identifier: "iCloud.princa.RinkLedger")
    @ObservationIgnored private lazy var database = container.publicCloudDatabase

    private static let recordType = "TeamShare"
    private static let joinCodeKey = "joinCode"
    private static let payloadKey = "payload"
    private static let updatedAtKey = "updatedAt"
    private static let defaultsKey = "cloudSyncRecordName"

    @ObservationIgnored
    private var linkedRecordName: String? {
        get { UserDefaults.standard.string(forKey: Self.defaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.defaultsKey) }
    }

    var isLinked: Bool { linkedRecordName != nil }
    var isSyncing = false
    var lastSyncedAt: Date?
    var lastError: String?

    /// True once we've confirmed this device can actually reach iCloud —
    /// checked lazily, not at init, since it's a network call.
    func checkAccountStatus() async -> Bool {
        (try? await container.accountStatus()) == .available
    }

    /// Creates a brand-new shared record under `joinCode`, seeded with the
    /// current local data. Fails if that code is somehow already taken
    /// (astronomically unlikely given the code space, but checked anyway).
    func createTeam(joinCode: String, snapshot: TeamSnapshot) async throws {
        guard await checkAccountStatus() else { throw CloudSyncError.notSignedIn }
        if (try? await findRecord(joinCode: joinCode)) != nil {
            try await createTeam(joinCode: Team.generateJoinCode(), snapshot: snapshot)
            return
        }
        let record = CKRecord(recordType: Self.recordType)
        record[Self.joinCodeKey] = joinCode
        record[Self.payloadKey] = try encode(snapshot)
        record[Self.updatedAtKey] = Date()
        let saved = try await database.save(record)
        linkedRecordName = saved.recordID.recordName
        lastSyncedAt = Date()
    }

    /// Finds the shared record for `joinCode` and returns its snapshot.
    /// Links this device to that record on success.
    func joinTeam(joinCode: String) async throws -> TeamSnapshot {
        guard await checkAccountStatus() else { throw CloudSyncError.notSignedIn }
        guard let record = try await findRecord(joinCode: joinCode) else {
            throw CloudSyncError.codeNotFound
        }
        guard let data = record[Self.payloadKey] as? Data else {
            throw CloudSyncError.codeNotFound
        }
        linkedRecordName = record.recordID.recordName
        lastSyncedAt = Date()
        return try decode(data)
    }

    /// Pushes the current local snapshot up, overwriting the shared record.
    func push(_ snapshot: TeamSnapshot) async throws {
        guard let recordName = linkedRecordName else { throw CloudSyncError.notLinked }
        guard await checkAccountStatus() else { throw CloudSyncError.notSignedIn }
        let recordID = CKRecord.ID(recordName: recordName)
        let record = try await database.record(for: recordID)
        record[Self.payloadKey] = try encode(snapshot)
        record[Self.updatedAtKey] = Date()
        _ = try await database.save(record)
        lastSyncedAt = Date()
    }

    /// Pulls the latest shared snapshot down.
    func pull() async throws -> TeamSnapshot {
        guard let recordName = linkedRecordName else { throw CloudSyncError.notLinked }
        guard await checkAccountStatus() else { throw CloudSyncError.notSignedIn }
        let recordID = CKRecord.ID(recordName: recordName)
        let record = try await database.record(for: recordID)
        guard let data = record[Self.payloadKey] as? Data else { throw CloudSyncError.codeNotFound }
        lastSyncedAt = Date()
        return try decode(data)
    }

    /// Forgets the link to the shared record. Local data is untouched —
    /// this device just stops being "the same team" as everyone else until
    /// it creates or joins another one.
    func unlink() {
        linkedRecordName = nil
    }

    private func findRecord(joinCode: String) async throws -> CKRecord? {
        let predicate = NSPredicate(format: "%K == %@", Self.joinCodeKey, joinCode)
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        let (results, _) = try await database.records(matching: query, resultsLimit: 1)
        guard let first = results.first, case .success(let record) = first.1 else { return nil }
        return record
    }

    private func encode(_ snapshot: TeamSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    private func decode(_ data: Data) throws -> TeamSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TeamSnapshot.self, from: data)
    }
}
