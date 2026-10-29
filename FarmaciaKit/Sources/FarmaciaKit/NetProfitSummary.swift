import Foundation

// MARK: - Net Profit Summary
//
// The dashboard's netProfit block (OWNER and ACCOUNTANT only).

public struct NetProfitSummary: Decodable, Sendable {
    public let amount: String
    public let marginPercent: String
    /// Service revenue net profit includes but sales leave out; absent from older servers.
    public let yastasServiceRevenue: String?
    /// Sales and cost from sale totals, the figures net profit is computed from (the
    /// dashboard's `sales` sums sale items instead); absent from older servers.
    public let salesRevenue: String?
    public let costOfSales: String?
}
