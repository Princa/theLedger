import SwiftUI

/// Flat progress bar: ink @ 12% track, colored fill. Used for burn-rate and budget bars.
struct ProgressBarView: View {
    var pct: Int
    var color: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.trackFill)
                Rectangle()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(max(pct, 0), 100)) / 100)
            }
        }
        .frame(height: height)
    }
}
