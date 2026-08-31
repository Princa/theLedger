import SwiftUI
import SwiftData

@main
struct TheLedgerApp: App {
    // Local-only for now (Phase 1: persistence). Phase 2 layers a
    // CloudKit-backed public database on top, keyed by Team.joinCode, so a
    // manager/coach can join the same data with a code — SwiftData's
    // automatic CloudKit sync only covers a single private account, not
    // that join-by-code flow, so that part will be hand-rolled separately.
    let modelContainer: ModelContainer = {
        let schema = Schema([
            Team.self, Player.self, StaffMember.self, BudgetCategory.self,
            LedgerEntry.self, Reimbursement.self, Sponsor.self, Payer.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                // The design is a single fixed paper/ink palette with no dark
                // variant, so system Dark Mode must not be allowed to swap
                // default (semantic) text colors to white against it.
                .preferredColorScheme(.light)
        }
        .modelContainer(modelContainer)
    }
}
