import Foundation

// MARK: - Cost Change
//
// How a receiving's unit cost compares with the supplier's last cost, shown
// under the cost ("▲ 8% vs último $16.50"). Catches price increases and typos.
// Up is a heads-up (caution), not an error; down is good news.

public struct CostChange: Equatable, Sendable {
    public let percent: Double
    public let last: Double

    /// nil without both costs, without a positive last cost, or for a change under 1¢.
    public init?(current: Double?, last: Double) {
        guard let current, last > 0, abs(current - last) >= 0.01 else { return nil }
        self.percent = (current - last) / last * 100
        self.last = last
    }

    public var isUp: Bool { percent > 0 }

    public var tone: Tone { isUp ? .caution : .positive }

    public var text: String {
        let rounded = Int(abs(percent).rounded())
        let amount = rounded == 0 ? "<1%" : "\(rounded)%"
        return "\(isUp ? "▲" : "▼") \(amount) vs último \(ReportFormat.currency(last))"
    }
}
