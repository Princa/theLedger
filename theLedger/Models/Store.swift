import Foundation
import Observation
import SwiftData

struct ImportRow: Identifiable {
    let id = UUID()
    var date: Date
    var dateLabel: String
    var desc: String
    var withdrawal: Double
    var deposit: Double
    /// "—" for deposits (never auto-categorized), a category code otherwise.
    var categoryCode: String
    var isDuplicate: Bool
    var included: Bool
    var categoryPickerOpen: Bool = false
}

@Observable
final class LedgerStore {

    // MARK: - Reference dates

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: .current, year: year, month: month, day: day).date!
    }

    /// Always the real current date — the nav header badge and every new entry
    /// timestamp track today, not a frozen demo date.
    var asOfDate: Date { Date() }
    var todayDate: Date { Date() }

    let instalmentDueDates: [Date] = [
        LedgerStore.date(2026, 6, 10),
        LedgerStore.date(2026, 9, 1),
        LedgerStore.date(2026, 10, 1),
        LedgerStore.date(2026, 11, 1),
    ]

    /// Amount held for a scheduled but not-yet-paid team commitment (shown in "Needs you").
    /// Zero by default — set this once a real payment is scheduled.
    var scheduledPaymentAmount: Double = 0
    var scheduledPaymentCategoryCode = "30"
    var scheduledPaymentNote = ""

    var sponsorshipSeasonTarget: Double = 0

    // MARK: - Persistence

    /// nil until `attach(_:)` runs (once, from RootTabView on first appearance).
    private var modelContext: ModelContext?
    private var ledgerSequenceCounter = 0

    private var context: ModelContext {
        guard let modelContext else {
            fatalError("LedgerStore used before attach(_:) was called")
        }
        return modelContext
    }

    /// Wires this store to the app's SwiftData store: loads existing data, or
    /// seeds it (once) on a brand-new install. Safe to call more than once —
    /// only the first call does anything.
    func attach(_ context: ModelContext) {
        guard modelContext == nil else { return }
        modelContext = context
        loadOrSeed()
    }

    private func fetchAll<T: PersistentModel>(_ type: T.Type, sortBy: [SortDescriptor<T>] = []) -> [T] {
        guard let modelContext else { return [] }
        var descriptor = FetchDescriptor<T>()
        descriptor.sortBy = sortBy
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func save() {
        try? modelContext?.save()
    }

    private func refreshRoster() { roster = fetchAll(Player.self, sortBy: [SortDescriptor(\.jerseyNumber)]) }
    private func refreshStaff() { staff = fetchAll(StaffMember.self) }
    private func refreshCategories() { categories = fetchAll(BudgetCategory.self, sortBy: [SortDescriptor(\.sortIndex)]) }
    private func refreshLedger() { ledger = fetchAll(LedgerEntry.self, sortBy: [SortDescriptor(\.sequence)]) }
    private func refreshReimbursements() { reimbursements = fetchAll(Reimbursement.self) }
    private func refreshSponsors() { sponsors = fetchAll(Sponsor.self) }
    private func refreshPayers() { payers = ["Team account"] + fetchAll(Payer.self, sortBy: [SortDescriptor(\.name)]).map(\.name) }

    private func nextSequence() -> Int {
        defer { ledgerSequenceCounter += 1 }
        return ledgerSequenceCounter
    }

    /// Roster mirrors the real Oakville Rangers U12 AA team as already
    /// entered in GameDay, so both apps agree on the same players by
    /// default — instalments all start unpaid, since GameDay doesn't
    /// track levy payments. No fictional staff, transactions,
    /// reimbursements, or sponsors — a real treasurer adds those from the
    /// app. The budget line names stay as a reusable expense-type
    /// template (the "ORHC treasurer template"), with every budget reset
    /// to $0 since there's no in-app editor for that figure yet — set
    /// them by logging real expenses/income against each line.
    private func loadOrSeed() {
        guard let modelContext else { return }

        if let existingTeam = fetchAll(Team.self).first {
            team = existingTeam
        } else {
            let newTeam = Team()
            modelContext.insert(newTeam)
            team = newTeam
        }

        refreshCategories()
        if categories.isEmpty {
            for (i, seed) in LedgerStore.defaultCategories().enumerated() {
                seed.sortIndex = i
                modelContext.insert(seed)
            }
            refreshCategories()
        }

        refreshRoster()
        if roster.isEmpty {
            for p in LedgerStore.defaultRoster() { modelContext.insert(p) }
            refreshRoster()
        }

        refreshStaff()
        refreshLedger()
        ledgerSequenceCounter = (ledger.map(\.sequence).max() ?? -1) + 1
        refreshReimbursements()
        refreshSponsors()
        refreshPayers()

        save()
    }

    // MARK: - Cloud sync snapshot (see CloudSyncService)

    func exportSnapshot() -> TeamSnapshot {
        TeamSnapshot(
            team: TeamSnapshot.TeamDTO(
                name: team.name, shortLabel: team.shortLabel, division: team.division,
                founded: team.founded, season: team.season, bankMask: team.bankMask,
                signingAuthority: team.signingAuthority, levySchedule: team.levySchedule,
                visibleTo: team.visibleTo, seasonStart: team.seasonStart, seasonEnd: team.seasonEnd,
                joinCode: team.joinCode, sheetsURL: team.sheetsURL
            ),
            players: roster.map {
                TeamSnapshot.PlayerDTO(jerseyNumber: $0.jerseyNumber, name: $0.name, position: $0.position, instalmentsPaid: $0.instalmentsPaid)
            },
            staff: staff.map { TeamSnapshot.StaffDTO(name: $0.name, role: $0.role) },
            categories: categories.map {
                TeamSnapshot.CategoryDTO(code: $0.code, name: $0.name, budget: $0.budget, sortIndex: $0.sortIndex)
            },
            ledger: ledger.map {
                TeamSnapshot.LedgerDTO(date: $0.date, desc: $0.desc, withdrawal: $0.withdrawal, deposit: $0.deposit, categoryCode: $0.categoryCode, incomeSource: $0.incomeSource, levyTag: $0.levyTag, origin: $0.origin, sequence: $0.sequence)
            },
            reimbursements: reimbursements.map {
                TeamSnapshot.ReimbursementDTO(who: $0.who, desc: $0.desc, amount: $0.amount, categoryCode: $0.categoryCode, status: $0.status, statusNote: $0.statusNote)
            },
            sponsors: sponsors.map {
                TeamSnapshot.SponsorDTO(name: $0.name, meta: $0.meta, amount: $0.amount, status: $0.status)
            },
            payers: payers.filter { $0 != "Team account" }
        )
    }

    /// Replaces every locally-stored record with what's in `snapshot`. Used
    /// after joining a team by code, or pulling a newer copy from the cloud
    /// — local-only data not yet pushed is discarded, so callers should warn
    /// before calling this.
    func importSnapshot(_ snapshot: TeamSnapshot) {
        guard let modelContext else { return }

        for p in fetchAll(Player.self) { modelContext.delete(p) }
        for s in fetchAll(StaffMember.self) { modelContext.delete(s) }
        for c in fetchAll(BudgetCategory.self) { modelContext.delete(c) }
        for e in fetchAll(LedgerEntry.self) { modelContext.delete(e) }
        for r in fetchAll(Reimbursement.self) { modelContext.delete(r) }
        for sp in fetchAll(Sponsor.self) { modelContext.delete(sp) }
        for p in fetchAll(Payer.self) { modelContext.delete(p) }
        for t in fetchAll(Team.self) { modelContext.delete(t) }

        let newTeam = Team()
        newTeam.name = snapshot.team.name
        newTeam.shortLabel = snapshot.team.shortLabel
        newTeam.division = snapshot.team.division
        newTeam.founded = snapshot.team.founded
        newTeam.season = snapshot.team.season
        newTeam.bankMask = snapshot.team.bankMask
        newTeam.signingAuthority = snapshot.team.signingAuthority
        newTeam.levySchedule = snapshot.team.levySchedule
        newTeam.visibleTo = snapshot.team.visibleTo
        newTeam.seasonStart = snapshot.team.seasonStart
        newTeam.seasonEnd = snapshot.team.seasonEnd
        newTeam.joinCode = snapshot.team.joinCode
        newTeam.sheetsURL = snapshot.team.sheetsURL ?? ""
        modelContext.insert(newTeam)
        team = newTeam

        for p in snapshot.players {
            modelContext.insert(Player(jerseyNumber: p.jerseyNumber, name: p.name, position: p.position, instalmentsPaid: p.instalmentsPaid))
        }
        for s in snapshot.staff {
            modelContext.insert(StaffMember(name: s.name, role: s.role))
        }
        for c in snapshot.categories {
            modelContext.insert(BudgetCategory(code: c.code, name: c.name, budget: c.budget, sortIndex: c.sortIndex))
        }
        for e in snapshot.ledger {
            modelContext.insert(LedgerEntry(date: e.date, desc: e.desc, withdrawal: e.withdrawal, deposit: e.deposit, categoryCode: e.categoryCode, incomeSource: e.incomeSource, levyTag: e.levyTag, origin: e.origin, sequence: e.sequence))
        }
        for r in snapshot.reimbursements {
            modelContext.insert(Reimbursement(who: r.who, desc: r.desc, amount: r.amount, categoryCode: r.categoryCode, status: r.status, statusNote: r.statusNote))
        }
        for sp in snapshot.sponsors {
            modelContext.insert(Sponsor(name: sp.name, meta: sp.meta, amount: sp.amount, status: sp.status))
        }
        for name in snapshot.payers where name != "Team account" {
            modelContext.insert(Payer(name: name))
        }

        save()
        refreshRoster()
        refreshStaff()
        refreshCategories()
        refreshLedger()
        ledgerSequenceCounter = (ledger.map(\.sequence).max() ?? -1) + 1
        refreshReimbursements()
        refreshSponsors()
        refreshPayers()
    }

    // MARK: - Core state
    //
    // Populated by attach(_:) / the refresh*() helpers above — these are
    // plain in-memory snapshots of what's in the SwiftData store, not the
    // store itself, so every mutating method below re-fetches after it
    // writes to keep them in sync (and to make sure @Observable sees a
    // fresh array, since mutating an object *inside* an unchanged array
    // reference wouldn't otherwise trigger a SwiftUI update).

    var team = Team()
    var roster: [Player] = []
    var staff: [StaffMember] = []
    var categories: [BudgetCategory] = []
    var ledger: [LedgerEntry] = []
    var reimbursements: [Reimbursement] = []
    var sponsors: [Sponsor] = []
    var payers: [String] = ["Team account"]

    var importedRows: [ImportRow] = []
    var importFileName: String = ""

    var toastMessage: String? = nil
    private var toastWorkItem: DispatchWorkItem?

    private static func defaultCategories() -> [BudgetCategory] {
        [
            BudgetCategory(code: "10", name: "Assessments", budget: 0),
            BudgetCategory(code: "20", name: "Refs", budget: 0),
            BudgetCategory(code: "25", name: "Equipment", budget: 0),
            BudgetCategory(code: "30", name: "Tournaments", budget: 0),
            BudgetCategory(code: "40", name: "Playoffs", budget: 0),
            BudgetCategory(code: "60", name: "Travel", budget: 0),
            BudgetCategory(code: "71", name: "Goalie coach", budget: 0),
            BudgetCategory(code: "82", name: "Recognition", budget: 0),
            BudgetCategory(code: "83", name: "Parties", budget: 0),
            BudgetCategory(code: "97", name: "Coaches", budget: 0),
            BudgetCategory(code: "98", name: "Bank", budget: 0),
            BudgetCategory(code: "99", name: "Other", budget: 0),
        ]
    }

    /// Oakville Rangers U12 AA roster, matching GameDay's team database.
    private static func defaultRoster() -> [Player] {
        let raw: [(Int, String, Position)] = [
            (1, "Jacko Wan", .goalie),
            (2, "Pierce Perry", .defence),
            (10, "Weston Hughes", .forward),
            (12, "Luke Fiorino", .forward),
            (13, "Hunter Maxwell", .forward),
            (14, "Finnegan Cheeseman", .defence),
            (15, "Harrison Rolph", .defence),
            (21, "Anna Zhou", .forward),
            (29, "Owen Cooper", .goalie),
            (34, "Paxton Boone", .forward),
            (44, "Ben Reeves", .forward),
            (73, "Stuart Kendon", .forward),
            (77, "Victor Gomes", .defence),
            (86, "Preston Lau", .forward),
            (87, "Emmet Buccitti", .defence),
            (88, "Alexander Wang", .defence),
            (93, "Filip Strenk", .forward),
        ]
        return raw.map { Player(jerseyNumber: $0.0, name: $0.1, position: $0.2) }
    }

    // MARK: - Derived money (single source of truth)

    func actualSpend(for categoryCode: String) -> Double {
        ledger.filter { $0.categoryCode == categoryCode }.reduce(0) { $0 + ($1.withdrawal ?? 0) }
    }

    func income(from source: IncomeSource) -> Double {
        ledger.filter { $0.incomeSource == source }.reduce(0) { $0 + ($1.deposit ?? 0) }
    }

    var levyIncome: Double { income(from: .levy) }
    var sponsorshipIncome: Double { income(from: .sponsorship) }
    var fundraisingIncome: Double { income(from: .fundraising) }
    var otherIncomeTotal: Double { income(from: .otherIncome) }
    var revenueReceived: Double { levyIncome + sponsorshipIncome + fundraisingIncome + otherIncomeTotal }

    var totalSpent: Double { ledger.reduce(0) { $0 + ($1.withdrawal ?? 0) } }
    var balance: Double { revenueReceived - totalSpent }

    var pendingReimbursementTotal: Double {
        reimbursements.filter { $0.status != .paid }.reduce(0) { $0 + $1.amount }
    }

    var committed: Double { pendingReimbursementTotal + scheduledPaymentAmount }
    var freeToSpend: Double { balance - committed }

    var levyTarget: Double { Double(roster.count) * 4000 }
    var levyPaidFromSchedule: Double {
        roster.reduce(0) { $0 + Double($1.instalmentsPaid.filter { $0 }.count) * 1000 }
    }
    var levyDue: Double { levyTarget - levyPaidFromSchedule }
    var pendingSponsorPledges: Double {
        sponsors.filter { $0.status != .received }.reduce(0) { $0 + $1.amount }
    }
    var stillToCollect: Double { levyDue + pendingSponsorPledges }

    var unpaidInstalment3Count: Int { roster.filter { !$0.instalmentsPaid[2] }.count }

    /// The overall spending envelope is automatic, not manually set: it's
    /// everything the team expects to bring in this season — levies,
    /// sponsorship, and fundraising — not a sum of individually-edited
    /// per-line budgets (there's no UI for those yet).
    var budgetTotal: Double { levyTarget + sponsorshipSeasonTarget + fundraisingIncome }
    var categoryActualTotal: Double { categories.reduce(0) { $0 + actualSpend(for: $1.code) } }
    var budgetRemaining: Double { budgetTotal - categoryActualTotal }

    var projectedRevenue: Double { budgetTotal }
    var projectedExpense: Double {
        categories.reduce(0) { $0 + max($1.budget, actualSpend(for: $1.code)) } + pendingReimbursementTotal
    }
    var projectedSurplus: Double { projectedRevenue - projectedExpense }
    var perPlayerRefund: Double { roster.isEmpty ? 0 : projectedSurplus / Double(roster.count) }

    var seasonElapsedPct: Int {
        let total = team.seasonEnd.timeIntervalSince(team.seasonStart)
        guard total > 0 else { return 0 }
        let elapsed = asOfDate.timeIntervalSince(team.seasonStart)
        return min(100, max(0, Int((elapsed / total * 100).rounded())))
    }
    var budgetSpentPct: Int {
        guard budgetTotal > 0 else { return 0 }
        return min(100, Int((categoryActualTotal / budgetTotal * 100).rounded()))
    }
    var burnNote: String {
        "Assessments and coach compensation are front-loaded, so spend runs ahead of the calendar. Tournaments and bus travel are the remaining weight: \(Formatting.money(budgetRemaining, cents: false)) still to come."
    }

    func categoryPct(_ category: BudgetCategory) -> Int {
        guard category.budget > 0 else { return 0 }
        return min(100, Int((actualSpend(for: category.code) / category.budget * 100).rounded()))
    }
    func categoryIsOverBudget(_ category: BudgetCategory) -> Bool {
        actualSpend(for: category.code) > category.budget
    }
    func category(for code: String) -> BudgetCategory? {
        categories.first { $0.code == code }
    }

    // MARK: - Toast

    func say(_ message: String) {
        toastWorkItem?.cancel()
        toastMessage = message
        let work = DispatchWorkItem { [weak self] in self?.toastMessage = nil }
        toastWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6, execute: work)
    }

    // MARK: - Expense / income logging

    @discardableResult
    func logExpense(amount: Double, desc rawDesc: String, categoryCode: String, payer: String) -> Bool {
        guard amount > 0 else { say("Enter an amount first."); return false }
        let cat = category(for: categoryCode)
        let desc = rawDesc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Expense — \(cat?.name ?? "")"
            : rawDesc.trimmingCharacters(in: .whitespacesAndNewlines)
        let toTeam = payer == "Team account"
        if toTeam {
            context.insert(LedgerEntry(date: todayDate, desc: desc, withdrawal: amount, categoryCode: categoryCode, sequence: nextSequence()))
            save()
            refreshLedger()
            say("\(Formatting.money(amount)) recorded to \(cat?.name ?? "").  Balance \(Formatting.money(balance)).")
        } else {
            context.insert(Reimbursement(who: payer, desc: desc, amount: amount, categoryCode: categoryCode, status: .pending, statusNote: "Submitted just now"))
            save()
            refreshReimbursements()
            say("\(Formatting.money(amount)) queued as a reimbursement to \(payer).")
        }
        return true
    }

    @discardableResult
    func logIncome(amount: Double, desc rawDesc: String, source: IncomeSource) -> Bool {
        guard amount > 0 else { say("Enter an amount first."); return false }
        let desc = rawDesc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(source.rawValue) received"
            : rawDesc.trimmingCharacters(in: .whitespacesAndNewlines)
        context.insert(LedgerEntry(date: todayDate, desc: desc, deposit: amount, incomeSource: source, sequence: nextSequence()))
        save()
        refreshLedger()
        say("\(Formatting.money(amount)) recorded as \(source.rawValue.lowercased()). Balance \(Formatting.money(balance)).")
        return true
    }

    func addCategory(named name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { say("Give the expense type a name."); return nil }
        if categories.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            say("\u{201C}\(trimmed)\u{201D} already exists.")
            return nil
        }
        let nextCode = String((categories.compactMap { Int($0.code) }.max() ?? 0) + 1)
        let nextSortIndex = (categories.map(\.sortIndex).max() ?? -1) + 1
        context.insert(BudgetCategory(code: nextCode, name: trimmed, budget: 0, sortIndex: nextSortIndex))
        save()
        refreshCategories()
        say("Added \u{201C}\(trimmed)\u{201D} — no budget set yet, edit it on Spending.")
        return nextCode
    }

    func addPayer(named name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { say("Enter a name."); return nil }
        if payers.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            say("\(trimmed) is already on the list.")
            return nil
        }
        context.insert(Payer(name: trimmed))
        save()
        refreshPayers()
        say("Added \(trimmed). Their expenses will queue as reimbursements.")
        return trimmed
    }

    // MARK: - Ledger row deletion (swipe-to-delete)

    /// Explains a locked row when it's tapped. The transaction lists hide the
    /// swipe and edit affordances for these, so this is the only thing a tap
    /// does — it tells the treasurer which screen owns the entry.
    func explainLock(_ entry: LedgerEntry) {
        guard let note = entry.lockNote else { return }
        say(note)
    }

    func deleteLedgerEntry(_ id: UUID) {
        guard let entry = ledger.first(where: { $0.id == id }) else { return }
        guard !entry.isLocked else { explainLock(entry); return }
        let desc = entry.desc
        context.delete(entry)
        save()
        refreshLedger()
        say("Deleted — \(desc).  Balance \(Formatting.money(balance)).")
    }

    // MARK: - Ledger row editing

    /// Edits an existing entry in place. Keeps its original deposit/withdrawal
    /// direction and levy tag (if any) — only description, amount, date, and
    /// the category/income-source tag are editable. Entries another screen owns
    /// are refused outright; there's no way to express, say, an $800 levy
    /// instalment on a $1,000 × 4 schedule.
    func updateLedgerEntry(id: UUID, date: Date, desc: String, amount: Double, categoryCode: String?, incomeSource: IncomeSource?) {
        guard let entry = ledger.first(where: { $0.id == id }) else { return }
        guard !entry.isLocked else { explainLock(entry); return }
        let trimmedDesc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.date = date
        entry.desc = trimmedDesc.isEmpty ? entry.desc : trimmedDesc
        if entry.withdrawal != nil {
            entry.withdrawal = amount
            entry.categoryCode = categoryCode
        } else {
            // The sheet edits the amount unsigned, so a reversal (a negative
            // deposit) keeps its sign here rather than flipping to money in.
            entry.deposit = (entry.deposit ?? 0) < 0 ? -amount : amount
            entry.incomeSource = incomeSource
        }
        save()
        refreshLedger()
        say("Updated — \(entry.desc). Balance \(Formatting.money(balance)).")
    }

    // MARK: - Levy instalment toggle

    func toggleInstalment(playerID: UUID, index: Int) {
        guard let player = roster.first(where: { $0.id == playerID }) else { return }
        let wasPaid = player.instalmentsPaid[index]
        let tag = "lv-\(playerID.uuidString)-\(index)"
        if let existing = ledger.first(where: { $0.levyTag == tag }) {
            context.delete(existing)
        } else {
            let desc = (wasPaid ? "Levy reversal — " : "Player levy — ") + player.name + ", instalment #\(index + 1)"
            context.insert(LedgerEntry(date: todayDate, desc: desc, deposit: wasPaid ? -1000 : 1000, incomeSource: .levy, levyTag: tag, origin: .levy, sequence: nextSequence()))
        }
        player.instalmentsPaid[index].toggle()
        save()
        refreshLedger()
        refreshRoster()
        let verb = wasPaid ? "Reversed" : "Recorded"
        say("\(verb) $1,000 — \(player.name), instalment #\(index + 1). Balance \(Formatting.money(balance)).")
    }

    // MARK: - Reimbursement flow

    func actOnReimbursement(_ id: UUID) {
        guard let r = reimbursements.first(where: { $0.id == id }) else { return }
        switch r.status {
        case .pending:
            r.status = .approved
            r.statusNote = "Approved — ready to pay"
            save()
            refreshReimbursements()
            say("Approved. \(Formatting.money(r.amount)) held against the balance.")
        case .approved:
            r.status = .paid
            r.statusNote = "Paid by e-transfer, \(Formatting.shortDate(todayDate))"
            context.insert(LedgerEntry(date: todayDate, desc: "Reimbursement — \(r.who), \(r.desc)", withdrawal: r.amount, categoryCode: r.categoryCode, origin: .reimbursement, sequence: nextSequence()))
            save()
            refreshReimbursements()
            refreshLedger()
            say("Paid \(Formatting.money(r.amount)) to \(r.who). Balance \(Formatting.money(balance)).")
        case .paid:
            break
        }
    }

    // MARK: - Roster / staff management

    func addPlayer() -> UUID {
        let p = Player(jerseyNumber: 0, name: "New player", position: .forward)
        context.insert(p)
        save()
        refreshRoster()
        say("Player added — set the name and number, then record levies on the Levies tab.")
        return p.id
    }

    func removePlayer(_ id: UUID) {
        guard let player = roster.first(where: { $0.id == id }) else { return }
        let name = player.name
        context.delete(player)
        save()
        refreshRoster()
        say("\(name) removed from the roster.")
    }

    func addStaff() -> UUID {
        let s = StaffMember(name: "New staff member", role: .assistantCoach)
        context.insert(s)
        save()
        refreshStaff()
        say("Staff member added — set the name and role.")
        return s.id
    }

    func removeStaff(_ id: UUID) {
        guard let member = staff.first(where: { $0.id == id }) else { return }
        let name = member.name
        context.delete(member)
        save()
        refreshStaff()
        say("\(name) removed from the bench staff.")
    }

    // MARK: - Reports

    func sendReportToParents() {
        say("Statement sent to \(roster.count) families and \(staff.count) staff.")
    }

    func exportWorkbook() {
        say("Workbook exported — 5 sheets, \(ledger.count) transactions.")
    }

    // MARK: - Google Sheets reference copy
    //
    // The app doesn't write to the sheet — this is just a pointer to a copy
    // the treasurer keeps in Drive, so the report can open it side by side.

    /// The stored link, ready to hand to `openURL`. nil when none is set.
    var sheetsLink: URL? { LedgerStore.normalizedLink(team.sheetsURL) }

    /// Stores what was pasted, normalized. Empty input clears the link.
    @discardableResult
    func setSheetsURL(_ raw: String) -> Bool {
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            team.sheetsURL = ""
            save()
            say("Sheets link removed.")
            return true
        }
        guard let link = LedgerStore.normalizedLink(raw) else {
            say("That doesn't look like a web address — paste the sheet's link.")
            return false
        }
        team.sheetsURL = link.absoluteString
        save()
        say("Sheets link saved.")
        return true
    }

    /// Adds the scheme a pasted address usually lacks, and keeps only http(s)
    /// — so a `javascript:` or `file:` string is rejected at the point it's
    /// typed rather than stored and silently failing to open later.
    static func normalizedLink(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: withScheme),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host(), !host.isEmpty
        else { return nil }
        return url
    }

    // MARK: - CSV statement import

    private static let categoryRules: [(keywords: [String], code: String)] = [
        (["e-tfr", "e-transfer", "etransfer", "reimburs"], "99"),
        (["assess", "orhc", "rangers hockey"], "10"),
        (["ref", "referee", "timekeep", "official"], "20"),
        (["jersey", "equip", "sportchek", "sport chek", "pro stock", "prostock", "supplies", "tape", "water bottle"], "25"),
        (["tournament", "showcase", "cup", "hotel", "marriott", "holiday inn"], "30"),
        (["playdown", "playoff"], "40"),
        (["bus", "coach lines", "travel", "transport"], "60"),
        (["goalie", "instruct", "skills", "clinic", "powerskat", "power skat"], "71"),
        (["award", "plaque", "trophy", "recognition"], "82"),
        (["pizza", "restaurant", "party", "teamsnap", "catering", "banquet"], "83"),
        (["coach comp", "honorar", "coach expense"], "97"),
        (["service charge", "monthly plan", "nsf", "overdraft", "bank fee"], "98"),
    ]

    static func guessCategoryCode(for description: String) -> String {
        let d = description.lowercased()
        for rule in categoryRules where rule.keywords.contains(where: { d.contains($0) }) {
            return rule.code
        }
        return "99"
    }

    static let sampleCSV = """
    Date,Description,Withdrawal,Deposit
    2025-12-18,MONTHLY PLAN FEE,16.95,
    2025-12-19,INTERAC E-TFR SENT M ROLPH,284.75,
    2025-12-20,SPORTCHEK OAKVILLE #4412,412.60,
    2025-12-22,DEPOSIT - LEVY J ZHOU,,1000.00
    2025-12-27,HOLIDAY INN ST THOMAS,1240.00,
    2026-01-03,POWERSKATING ACADEMY,540.00,
    2026-01-05,DEPOSIT - KERR ST AUTOMOTIVE,,3000.00
    """

    private func duplicateKey(desc: String, amount: Double) -> String {
        "\(desc.lowercased())|\(Formatting.rawAmount(amount))"
    }

    func parseStatement(_ text: String, fileName: String) {
        let lines = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { say("That file had no rows in it."); return }

        let head = lines[0].lowercased()
        let looksLikeHeader = head.contains("date") && head.contains("desc")
        let body = looksLikeHeader ? Array(lines.dropFirst()) : lines

        let known = Set(ledger.map { duplicateKey(desc: $0.desc, amount: $0.withdrawal ?? $0.deposit ?? 0) })

        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.timeZone = TimeZone(identifier: "UTC")

        var rows: [ImportRow] = []
        for line in body {
            let fields = LedgerStore.splitCSVLine(line)
            guard fields.count >= 3 else { continue }
            let rawDate = fields[0]
            let desc = fields[1]
            let wd = Formatting.parseAmount(fields.count > 2 ? fields[2] : "")
            let dep = Formatting.parseAmount(fields.count > 3 ? fields[3] : "")
            guard wd != 0 || dep != 0 else { continue }

            let parsedDate = inputFormatter.date(from: rawDate) ?? todayDate
            let key = duplicateKey(desc: desc, amount: wd != 0 ? wd : dep)
            rows.append(ImportRow(
                date: parsedDate,
                dateLabel: Formatting.shortDate(parsedDate),
                desc: desc,
                withdrawal: wd,
                deposit: dep,
                categoryCode: dep != 0 ? "—" : LedgerStore.guessCategoryCode(for: desc),
                isDuplicate: known.contains(key),
                included: !known.contains(key)
            ))
        }
        guard !rows.isEmpty else {
            say("No transactions found — expecting Date, Description, Withdrawal, Deposit.")
            return
        }
        importedRows = rows
        importFileName = fileName
    }

    private static func splitCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    func loadDemoStatement() {
        parseStatement(LedgerStore.sampleCSV, fileName: "chequing-4417-dec.csv")
    }

    var importDuplicateNote: String {
        let dupCount = importedRows.filter { $0.isDuplicate }.count
        return dupCount > 0
            ? "\(dupCount) row(s) already appear in the ledger and were left unticked."
            : "No duplicates against the existing ledger."
    }

    var importSelectedCount: Int { importedRows.filter { $0.included }.count }
    var importNet: Double {
        importedRows.filter { $0.included }.reduce(0) { $0 + $1.deposit - $1.withdrawal }
    }
    var importNewBalance: Double { balance + importNet }

    func confirmImport() {
        let selected = importedRows.filter { $0.included }
        guard !selected.isEmpty else { say("Nothing ticked to import."); return }
        for r in selected {
            if r.deposit > 0 {
                context.insert(LedgerEntry(date: r.date, desc: r.desc, deposit: r.deposit, incomeSource: .otherIncome, sequence: nextSequence()))
            } else {
                context.insert(LedgerEntry(date: r.date, desc: r.desc, withdrawal: r.withdrawal, categoryCode: r.categoryCode, sequence: nextSequence()))
            }
        }
        save()
        refreshLedger()
        let count = selected.count
        importedRows = []
        importFileName = ""
        say("\(count) transactions merged. Balance \(Formatting.money(balance)).")
    }

    func discardImport() {
        importedRows = []
        importFileName = ""
    }
}
