import Foundation

enum LocaleFormatting {
    /// Locale-aware percent string (e.g. "65%", "٪٦٥").
    static func percent(_ value: Double) -> String {
        value.clamped(to: 0...1).formatted(.percent.precision(.fractionLength(0)))
    }

    /// Short time in the user's current locale.
    static func shortTime(_ date: Date = .now) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened))
    }

    /// Live Activity / widget “Updated 3:41 PM” line.
    static func updatedAt(_ date: Date = .now) -> String {
        let time = shortTime(date)
        return String(localized: "Updated \(time)", comment: "Live Activity timestamp; argument is a localized short time")
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
