import Foundation

enum Formatting {
    private static func numberFormatter(cents: Bool) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.minimumFractionDigits = cents ? 2 : 0
        f.maximumFractionDigits = cents ? 2 : 0
        return f
    }

    /// "$1,234.56" or "-$1,234.56". Pass `cents: false` for whole-dollar figures.
    static func money(_ amount: Double, cents: Bool = true) -> String {
        let value = abs(amount)
        let s = numberFormatter(cents: cents).string(from: NSNumber(value: value)) ?? String(format: cents ? "%.2f" : "%.0f", value)
        return (amount < 0 ? "-$" : "$") + s
    }

    /// "+$1,234.56" for a positive figure, "-$1,234.56" for a negative one.
    static func signedMoney(_ amount: Double, cents: Bool = true) -> String {
        amount < 0 ? money(amount, cents: cents) : "+" + money(amount, cents: cents)
    }

    /// Stable key fragment for duplicate detection: drops trailing .00 the way JS's `||` coercion effectively did.
    static func rawAmount(_ amount: Double) -> String {
        if amount == amount.rounded() {
            return String(Int(amount))
        }
        return String(format: "%.2f", amount)
    }

    static func parseAmount(_ raw: String) -> Double {
        let cleaned = raw.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    private static let badgeDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    static func badgeDate(_ date: Date) -> String {
        badgeDateFormatter.string(from: date).uppercased()
    }

    private static let reportDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    static func reportDate(_ date: Date) -> String {
        reportDateFormatter.string(from: date)
    }
}
