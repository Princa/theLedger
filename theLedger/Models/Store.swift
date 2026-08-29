import Foundation
import Observation

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

    let asOfDate = LedgerStore.date(2026, 12, 15)
    let todayDate = LedgerStore.date(2026, 12, 16)

    let instalmentDueDates: [Date] = [
        LedgerStore.date(2026, 6, 10),
        LedgerStore.date(2026, 9, 1),
        LedgerStore.date(2026, 10, 1),
        LedgerStore.date(2026, 11, 1),
    ]

    /// Amount held for a scheduled but not-yet-paid team commitment (shown in "Needs you").
    let scheduledPaymentAmount: Double = 1700
    let scheduledPaymentCategoryCode = "30"
    let scheduledPaymentNote = "Scheduled payment, Tournaments — Nov 7"

    let sponsorshipSeasonTarget: Double = 9000

    // MARK: - Core state

    var team = Team()
    var roster: [Player]
    var staff: [StaffMember]
    var categories: [BudgetCategory]
    var ledger: [LedgerEntry]
    var reimbursements: [Reimbursement]
    var sponsors: [Sponsor]
    var payers: [String]

    var importedRows: [ImportRow] = []
    var importFileName: String = ""

    var toastMessage: String? = nil
    private var toastWorkItem: DispatchWorkItem?

    // MARK: - Seed data

    init() {
        roster = LedgerStore.seedRoster()
        staff = [
            StaffMember(name: "Jeff Perry", role: .headCoach),
            StaffMember(name: "Mel Rolph", role: .assistantCoach),
            StaffMember(name: "Torin Wang", role: .trainer),
            StaffMember(name: "Jordan Reeves", role: .teamManager),
        ]
        categories = [
            BudgetCategory(code: "10", name: "Assessments", budget: 37078),
            BudgetCategory(code: "20", name: "Refs", budget: 4200),
            BudgetCategory(code: "25", name: "Equipment", budget: 3000),
            BudgetCategory(code: "30", name: "Tournaments", budget: 6400),
            BudgetCategory(code: "40", name: "Playoffs", budget: 1200),
            BudgetCategory(code: "60", name: "Travel", budget: 2500),
            BudgetCategory(code: "71", name: "Goalie coach", budget: 2800),
            BudgetCategory(code: "82", name: "Recognition", budget: 600),
            BudgetCategory(code: "83", name: "Parties", budget: 1500),
            BudgetCategory(code: "97", name: "Coaches", budget: 16000),
            BudgetCategory(code: "98", name: "Bank", budget: 200),
            BudgetCategory(code: "99", name: "Other", budget: 500),
        ]
        reimbursements = [
            Reimbursement(who: "Mel Rolph", desc: "Team water bottles ×20", amount: 284.75, categoryCode: "25", status: .pending, statusNote: "Submitted 2 days ago"),
            Reimbursement(who: "Torin Wang", desc: "Medical supplies, trainer bag", amount: 142.08, categoryCode: "25", status: .pending, statusNote: "Submitted yesterday"),
            Reimbursement(who: "Jordan Reeves", desc: "Player recognition — hard hat & chef hat", amount: 653.72, categoryCode: "82", status: .pending, statusNote: "Submitted 4 days ago"),
        ]
        sponsors = [
            Sponsor(name: "Hillside Dental", meta: "Received Nov 3 · rink board", amount: 4500, status: .received),
            Sponsor(name: "Kerr St. Automotive", meta: "Committed, invoice sent", amount: 3000, status: .committed),
            Sponsor(name: "Bronte Physio", meta: "In conversation", amount: 1500, status: .inConversation),
        ]
        payers = ["Team account", "Mel Rolph", "Jordan Reeves", "Torin Wang", "Jeff Perry"]

        let d = LedgerStore.date
        ledger = [
            LedgerEntry(date: d(2026, 6, 10), desc: "Player levy — instalment #1 (17 of 17)", deposit: 17000, incomeSource: .levy),
            LedgerEntry(date: d(2026, 9, 1), desc: "Player levy — instalment #2 (17 of 17)", deposit: 17000, incomeSource: .levy),
            LedgerEntry(date: d(2026, 9, 5), desc: "Oakville Rangers Assessment #1", withdrawal: 18539, categoryCode: "10"),
            LedgerEntry(date: d(2026, 10, 1), desc: "Player levy — instalment #3 (14 of 17)", deposit: 14000, incomeSource: .levy),
            LedgerEntry(date: d(2026, 10, 15), desc: "Oakville Rangers Assessment #2", withdrawal: 18539, categoryCode: "10"),
            LedgerEntry(date: d(2026, 10, 20), desc: "Tournament — St. Thomas Boston Pizza Cup", withdrawal: 1700, categoryCode: "30"),
            LedgerEntry(date: d(2026, 11, 3), desc: "Sponsorship — Hillside Dental", deposit: 4500, incomeSource: .sponsorship),
            LedgerEntry(date: d(2026, 11, 10), desc: "Refs & timekeepers — home games ×13", withdrawal: 1850, categoryCode: "20"),
            LedgerEntry(date: d(2026, 11, 18), desc: "Goalie instruction ×3 sessions", withdrawal: 900, categoryCode: "71"),
            LedgerEntry(date: d(2026, 11, 24), desc: "Practice jerseys & team supplies", withdrawal: 1486.72, categoryCode: "25"),
            LedgerEntry(date: d(2026, 11, 30), desc: "Coach compensation — Nov", withdrawal: 4000, categoryCode: "97"),
            LedgerEntry(date: d(2026, 12, 2), desc: "Fundraising — raffle night", deposit: 1280, incomeSource: .fundraising),
            LedgerEntry(date: d(2026, 12, 8), desc: "Signing party — gift bags & balloons", withdrawal: 341.43, categoryCode: "83"),
            LedgerEntry(date: d(2026, 12, 8), desc: "TeamSnap subscription", withdrawal: 169.84, categoryCode: "83"),
            LedgerEntry(date: d(2026, 12, 9), desc: "Summer pool party — pizza", withdrawal: 209.19, categoryCode: "83"),
            LedgerEntry(date: d(2026, 12, 15), desc: "Bank charges — Q2", withdrawal: 138.6, categoryCode: "98"),
        ]
    }

    private static func seedRoster() -> [Player] {
        let raw: [(Int, String, Position, [Bool])] = [
            (34, "Paxton Boone", .forward, [true, true, false, false]),
            (87, "Emmet Buccitti", .defence, [true, true, false, false]),
            (14, "Finnegan Cheeseman", .defence, [true, true, true, false]),
            (29, "Owen Cooper", .goalie, [true, true, true, false]),
            (12, "Luke Fiorino", .forward, [true, true, true, false]),
            (77, "Victor Gomes", .defence, [true, true, true, false]),
            (10, "Weston Hughes", .forward, [true, true, false, false]),
            (73, "Stuart Kendon", .forward, [true, true, true, false]),
            (86, "Preston Lau", .forward, [true, true, true, false]),
            (13, "Hunter Maxwell", .forward, [true, true, true, false]),
            (2, "Pierce Perry", .defence, [true, true, true, false]),
            (44, "Ben Reeves", .forward, [true, true, true, false]),
            (15, "Harrison Rolph", .defence, [true, true, true, false]),
            (93, "Filip Strenk", .forward, [true, true, true, false]),
            (88, "Alexander Wang", .defence, [true, true, true, false]),
            (1, "Jacko Wan", .goalie, [true, true, true, false]),
            (21, "Anna Zhou", .forward, [true, true, true, false]),
        ]
        return raw.map { Player(jerseyNumber: $0.0, name: $0.1, position: $0.2, instalmentsPaid: $0.3) }
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

    var budgetTotal: Double { categories.reduce(0) { $0 + $1.budget } }
    var categoryActualTotal: Double { categories.reduce(0) { $0 + actualSpend(for: $1.code) } }
    var budgetRemaining: Double { budgetTotal - categoryActualTotal }

    var projectedRevenue: Double { levyTarget + sponsorshipSeasonTarget + fundraisingIncome }
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
            ledger.append(LedgerEntry(date: todayDate, desc: desc, withdrawal: amount, categoryCode: categoryCode))
            say("\(Formatting.money(amount)) recorded to \(cat?.name ?? "").  Balance \(Formatting.money(balance)).")
        } else {
            reimbursements.append(Reimbursement(who: payer, desc: desc, amount: amount, categoryCode: categoryCode, status: .pending, statusNote: "Submitted just now"))
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
        ledger.append(LedgerEntry(date: todayDate, desc: desc, deposit: amount, incomeSource: source))
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
        categories.append(BudgetCategory(code: nextCode, name: trimmed, budget: 0))
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
        payers.append(trimmed)
        say("Added \(trimmed). Their expenses will queue as reimbursements.")
        return trimmed
    }

    // MARK: - Ledger row deletion (swipe-to-delete)

    func deleteLedgerEntry(_ id: UUID) {
        guard let entry = ledger.first(where: { $0.id == id }) else { return }
        ledger.removeAll { $0.id == id }
        say("Deleted — \(entry.desc).  Balance \(Formatting.money(balance)).")
    }

    // MARK: - Levy instalment toggle

    func toggleInstalment(playerID: UUID, index: Int) {
        guard let pi = roster.firstIndex(where: { $0.id == playerID }) else { return }
        let wasPaid = roster[pi].instalmentsPaid[index]
        let tag = "lv-\(playerID.uuidString)-\(index)"
        if let existing = ledger.firstIndex(where: { $0.levyTag == tag }) {
            ledger.remove(at: existing)
        } else {
            let desc = (wasPaid ? "Levy reversal — " : "Player levy — ") + roster[pi].name + ", instalment #\(index + 1)"
            ledger.append(LedgerEntry(date: todayDate, desc: desc, deposit: wasPaid ? -1000 : 1000, incomeSource: .levy, levyTag: tag))
        }
        roster[pi].instalmentsPaid[index].toggle()
        let verb = wasPaid ? "Reversed" : "Recorded"
        say("\(verb) $1,000 — \(roster[pi].name), instalment #\(index + 1). Balance \(Formatting.money(balance)).")
    }

    // MARK: - Reimbursement flow

    func actOnReimbursement(_ id: UUID) {
        guard let i = reimbursements.firstIndex(where: { $0.id == id }) else { return }
        switch reimbursements[i].status {
        case .pending:
            reimbursements[i].status = .approved
            reimbursements[i].statusNote = "Approved — ready to pay"
            say("Approved. \(Formatting.money(reimbursements[i].amount)) held against the balance.")
        case .approved:
            let r = reimbursements[i]
            reimbursements[i].status = .paid
            reimbursements[i].statusNote = "Paid by e-transfer, Dec 16"
            ledger.append(LedgerEntry(date: todayDate, desc: "Reimbursement — \(r.who), \(r.desc)", withdrawal: r.amount, categoryCode: r.categoryCode))
            say("Paid \(Formatting.money(r.amount)) to \(r.who). Balance \(Formatting.money(balance)).")
        case .paid:
            break
        }
    }

    // MARK: - Roster / staff management

    func addPlayer() -> UUID {
        let p = Player(jerseyNumber: 0, name: "New player", position: .forward)
        roster.append(p)
        say("Player added — set the name and number, then record levies on the Levies tab.")
        return p.id
    }

    func removePlayer(_ id: UUID) {
        guard let name = roster.first(where: { $0.id == id })?.name else { return }
        roster.removeAll { $0.id == id }
        say("\(name) removed from the roster.")
    }

    func addStaff() -> UUID {
        let s = StaffMember(name: "New staff member", role: .assistantCoach)
        staff.append(s)
        say("Staff member added — set the name and role.")
        return s.id
    }

    func removeStaff(_ id: UUID) {
        guard let name = staff.first(where: { $0.id == id })?.name else { return }
        staff.removeAll { $0.id == id }
        say("\(name) removed from the bench staff.")
    }

    // MARK: - Reports

    func sendReportToParents() {
        say("Statement sent to \(roster.count) families and \(staff.count) staff.")
    }

    func exportWorkbook() {
        say("Workbook exported — 5 sheets, \(ledger.count) transactions.")
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
                ledger.append(LedgerEntry(date: r.date, desc: r.desc, deposit: r.deposit, incomeSource: .otherIncome))
            } else {
                ledger.append(LedgerEntry(date: r.date, desc: r.desc, withdrawal: r.withdrawal, categoryCode: r.categoryCode))
            }
        }
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
