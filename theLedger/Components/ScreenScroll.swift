import SwiftUI

/// Standard scrollable screen body: paper background, standard screen
/// padding, dismisses the keyboard on drag. Used by every screen that
/// doesn't need `List`'s native swipe-actions.
struct PlainScrollScreen<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 6)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.paper.ignoresSafeArea())
    }
}

/// A List row with the design's hairline divider on top and no default
/// system inset/background/separator, so it reads exactly like the flat
/// custom rows elsewhere in the app while still getting List's native
/// swipe-actions and scroll behavior.
struct FlatListRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.screenPadding, bottom: 0, trailing: Theme.screenPadding))
            .listRowSeparator(.hidden)
            .listRowBackground(Theme.paper)
            .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
    }
}

extension View {
    /// Strips a List row down to plain content with the app's screen
    /// padding and no system chrome — for header/footer blocks (hero
    /// figures, buttons) that shouldn't get the hairline divider a
    /// `FlatListRow` line item gets.
    func bareListRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.screenPadding, bottom: 0, trailing: Theme.screenPadding))
            .listRowSeparator(.hidden)
            .listRowBackground(Theme.paper)
    }
}
