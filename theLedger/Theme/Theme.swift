import SwiftUI
import UIKit

enum Theme {
    // MARK: - Colors

    static let ink = Color(hex: 0x201E1D)
    static let paper = Color(hex: 0xF3F2F2)
    static let surface = Color(hex: 0xEAE9E9)
    static let divider = ink.opacity(0.16)
    static let hairline = ink.opacity(0.30)
    static let muted = ink.opacity(0.55)
    static let mutedStrong = ink.opacity(0.60)
    static let mutedSoft = ink.opacity(0.65)
    static let trackFill = ink.opacity(0.12)

    static let accent = Color(hex: 0x0088B0)
    static let accent600 = Color(hex: 0x1186AC)
    static let accent700 = Color(hex: 0x006786)
    static let accent800 = Color(hex: 0x004961)
    static let accent100 = Color(hex: 0xE9F8FF)

    static let clubRed = Color(hex: 0xDE393C)
    static let clubDarkRed = Color(hex: 0xA81F24)

    static let neutral100 = Color(hex: 0xE4E4E3)
    static let neutral800 = ink.opacity(0.70)

    // MARK: - Type

    /// Serif family throughout — Source Serif 4 if bundled/available, else New York (ui-serif).
    private static let hasSourceSerif4: Bool = !UIFont.fontNames(forFamilyName: "Source Serif 4").isEmpty

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if hasSourceSerif4 {
            return .custom("Source Serif 4", fixedSize: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    static let navTitle = serif(30, weight: .semibold)
    static let heroBalance = serif(56, weight: .regular)
    static let heroRefund = serif(52, weight: .regular)
    static let heroReimbTotal = serif(34, weight: .regular)
    static let kicker = Font.system(size: 11, weight: .regular).width(.standard)

    // MARK: - Shape / spacing

    static let screenPadding: CGFloat = 22
    static let rowMinHeight: CGFloat = 44
    static let buttonMinHeight: CGFloat = 48
    static let sharpCorner: CGFloat = 2
    static let pillCorner: CGFloat = 16
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Uppercase, tracked section label used above every list ("BURN RATE", "NEEDS YOU", …).
struct Kicker: View {
    let text: String
    var color: Color = Theme.accent700

    var body: some View {
        Text(text.uppercased())
            .font(Theme.kicker)
            .tracking(1.3)
            .foregroundStyle(color)
    }
}

/// Dark rounded-2pt toast, pinned above the tab bar.
struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(Theme.serif(14))
            .foregroundStyle(Theme.paper)
            .lineSpacing(3)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.sharpCorner))
            .padding(.horizontal, 16)
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}

struct ToastOverlay: ViewModifier {
    var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                ToastView(message: message)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeOut(duration: 0.2), value: message)
            }
        }
    }
}

extension View {
    func toast(_ message: String?) -> some View {
        modifier(ToastOverlay(message: message))
    }
}
