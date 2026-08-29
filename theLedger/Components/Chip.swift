import SwiftUI

/// Pill-shaped filter/category chip. Selected chips fill with a color; unselected
/// chips show a hairline outline only.
struct Chip: View {
    let label: String
    let isSelected: Bool
    var selectedFill: Color = Theme.accent
    var selectedText: Color = Theme.paper
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.serif(14))
                .lineLimit(1)
                .foregroundStyle(isSelected ? selectedText : Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(isSelected ? selectedFill : Color.clear)
                .overlay(
                    Capsule().strokeBorder(isSelected ? selectedFill : Theme.hairline, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// The two-way "Money out / Money in" style chip: filled ink/black when selected.
struct DarkChip: View {
    let label: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Chip(label: label, isSelected: isSelected, selectedFill: Theme.ink, selectedText: Theme.paper, action: action)
    }
}

/// Dashed "+ New type" / "+ New person" chip that opens an inline text field.
struct DashedAddChip: View {
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.serif(14))
                .foregroundStyle(Theme.accent700)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .overlay(
                    Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Theme.ink.opacity(0.35))
                )
        }
        .buttonStyle(.plain)
    }
}

/// Small status pill used for reimbursement/refund states ("Approved", "Levy owing", …).
struct StatusTag: View {
    let text: String
    let background: Color
    let foreground: Color

    var body: some View {
        Text(text)
            .font(Theme.serif(12))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(background)
            .clipShape(Capsule())
    }
}
