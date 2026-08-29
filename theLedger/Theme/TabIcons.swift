import SwiftUI

/// Line-drawn tab icons matching the design's linework (no SF Symbols).
/// Each is authored on a 24×24 viewBox to mirror the reference SVGs exactly.
enum TabIcon {
    struct Home: Shape {
        func path(in rect: CGRect) -> Path {
            let s = rect.width / 24
            var p = Path()
            p.addEllipse(in: CGRect(x: (12 - 8) * s, y: (12 - 8) * s, width: 16 * s, height: 16 * s))
            return p
        }
    }

    /// The vertical stem + centre dot are drawn separately so the outer ring stays unfilled.
    struct HomeCenter: View {
        var color: Color
        var size: CGFloat

        var body: some View {
            let s = size / 24
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 12 * s, y: 4 * s))
                    p.addLine(to: CGPoint(x: 12 * s, y: 20 * s))
                }
                .stroke(color, lineWidth: 1.6)
                Circle()
                    .fill(color)
                    .frame(width: 4.8 * s, height: 4.8 * s)
                    .position(x: 12 * s, y: 12 * s)
            }
        }
    }

    struct Levies: Shape {
        func path(in rect: CGRect) -> Path {
            let s = rect.width / 24
            var p = Path()
            p.move(to: CGPoint(x: 9 * s, y: 4 * s))
            p.addLine(to: CGPoint(x: 4 * s, y: 6.5 * s))
            p.addLine(to: CGPoint(x: 4 * s, y: 11 * s))
            p.addLine(to: CGPoint(x: 6.5 * s, y: 11 * s))
            p.addLine(to: CGPoint(x: 6.5 * s, y: 20 * s))
            p.addLine(to: CGPoint(x: 17.5 * s, y: 20 * s))
            p.addLine(to: CGPoint(x: 17.5 * s, y: 11 * s))
            p.addLine(to: CGPoint(x: 20 * s, y: 11 * s))
            p.addLine(to: CGPoint(x: 20 * s, y: 6.5 * s))
            p.addLine(to: CGPoint(x: 15 * s, y: 4 * s))
            p.addArc(center: CGPoint(x: 12 * s, y: 4 * s), radius: 3 * s, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            p.closeSubpath()
            return p
        }
    }

    struct LeviesPost: Shape {
        func path(in rect: CGRect) -> Path {
            let s = rect.width / 24
            var p = Path()
            p.move(to: CGPoint(x: 12 * s, y: 12 * s))
            p.addLine(to: CGPoint(x: 12 * s, y: 16 * s))
            return p
        }
    }

    struct Log: Shape {
        func path(in rect: CGRect) -> Path {
            let s = rect.width / 24
            var p = Path()
            p.addEllipse(in: CGRect(x: (12 - 8.5) * s, y: (12 - 5) * s, width: 17 * s, height: 10 * s))
            return p
        }
    }

    struct LogCross: Shape {
        func path(in rect: CGRect) -> Path {
            let s = rect.width / 24
            var p = Path()
            p.move(to: CGPoint(x: 8.5 * s, y: 12 * s))
            p.addLine(to: CGPoint(x: 15.5 * s, y: 12 * s))
            p.move(to: CGPoint(x: 12 * s, y: 8.6 * s))
            p.addLine(to: CGPoint(x: 12 * s, y: 15.4 * s))
            return p
        }
    }

    struct Spend: Shape {
        func path(in rect: CGRect) -> Path {
            let s = rect.width / 24
            var p = Path()
            p.move(to: CGPoint(x: 4 * s, y: 7 * s))
            p.addLine(to: CGPoint(x: 20 * s, y: 7 * s))
            p.move(to: CGPoint(x: 4 * s, y: 12 * s))
            p.addLine(to: CGPoint(x: 15 * s, y: 12 * s))
            p.move(to: CGPoint(x: 4 * s, y: 17 * s))
            p.addLine(to: CGPoint(x: 10 * s, y: 17 * s))
            return p
        }
    }

    struct More: View {
        var color: Color
        var size: CGFloat

        var body: some View {
            let s = size / 24
            HStack(spacing: 0) {
                ForEach([6.0, 12.0, 18.0], id: \.self) { cx in
                    Circle()
                        .fill(color)
                        .frame(width: 3.4 * s, height: 3.4 * s)
                        .position(x: cx * s, y: 12 * s)
                }
            }
            .frame(width: size, height: size)
        }
    }
}

/// One custom tab icon, drawn with strokes to match the reference's 1.6pt linework.
struct CustomTabIcon: View {
    enum Kind { case home, levies, log, spend, more }

    let kind: Kind
    var isActive: Bool
    var size: CGFloat = 22

    private var color: Color { isActive ? Theme.clubDarkRed : Theme.muted }

    var body: some View {
        Group {
            switch kind {
            case .home:
                ZStack {
                    TabIcon.Home().stroke(color, lineWidth: 1.6)
                    TabIcon.HomeCenter(color: color, size: size)
                }
            case .levies:
                ZStack {
                    TabIcon.Levies().stroke(color, lineWidth: 1.6)
                    TabIcon.LeviesPost().stroke(color, lineWidth: 1.6)
                }
            case .log:
                ZStack {
                    TabIcon.Log().stroke(color, lineWidth: 1.6)
                    TabIcon.LogCross().stroke(color, lineWidth: 1.6)
                }
            case .spend:
                TabIcon.Spend().stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            case .more:
                TabIcon.More(color: color, size: size)
            }
        }
        .frame(width: size, height: size)
    }
}
