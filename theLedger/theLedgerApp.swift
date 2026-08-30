import SwiftUI

@main
struct TheLedgerApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                // The design is a single fixed paper/ink palette with no dark
                // variant, so system Dark Mode must not be allowed to swap
                // default (semantic) text colors to white against it.
                .preferredColorScheme(.light)
        }
    }
}
