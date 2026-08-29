import SwiftUI

/// iOS-native left-swipe-to-delete: drag reveals a 104pt red "Delete" action;
/// past ~52pt of drag it snaps open, releasing under that threshold snaps back.
struct SwipeToDeleteRow<Content: View>: View {
    var onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var isOpen = false

    private let actionWidth: CGFloat = 104
    private let threshold: CGFloat = 52

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onDelete) {
                Text("Delete")
                    .font(Theme.serif(15))
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Theme.clubRed)
            }
            .buttonStyle(.plain)

            content()
                .background(Theme.paper)
                .offset(x: offset)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            let base: CGFloat = isOpen ? -actionWidth : 0
                            offset = max(-actionWidth, min(0, base + value.translation.width))
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.22)) {
                                if offset < -threshold {
                                    offset = -actionWidth
                                    isOpen = true
                                } else {
                                    offset = 0
                                    isOpen = false
                                }
                            }
                        }
                )
        }
        .clipped()
    }
}
