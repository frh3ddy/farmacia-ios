import Foundation

// MARK: - Profit & Loss Lines
//
// The dashboard's P&L card. The server computes
//   net profit = gross profit − (expenses + merma) + Yastás service revenue
// and sends operatingExpenses.total with merma already in it, so showing that
// total next to a Merma row counted merma twice, and Yastás had no row. The rows
// here show merma once and Yastás when there is any; net profit is always the
// server's figure, and `addsUp` checks the rows reach it (Decimal, never Double).

public struct ProfitLossLines: Sendable {
    public struct Line: Equatable, Sendable {
        /// income adds, cost and shrinkage (merma) subtract, total is the result.
        public enum Kind: Sendable { case income, cost, shrinkage, total }
        public let label: String
        public let amount: String
        public let kind: Kind
    }

    public let lines: [Line]
    public let addsUp: Bool

    public init(revenue: String, costOfSales: String, operatingExpensesTotal: String,
                shrinkage: String, yastasServiceRevenue: String?, netProfit: String) {
        let yastas = yastasServiceRevenue.flatMap(Self.decimal)
        let yastasLine = yastas.flatMap { $0 > 0 ? Line(label: "Yastás", amount: "\($0)", kind: .income) : nil }

        var lines = [
            Line(label: "Ingresos", amount: revenue, kind: .income),
            Line(label: "Costo de Ventas", amount: costOfSales, kind: .cost),
        ]

        if let revenue = Self.decimal(revenue), let cost = Self.decimal(costOfSales),
           let expensesTotal = Self.decimal(operatingExpensesTotal), let merma = Self.decimal(shrinkage) {
            let expenses = expensesTotal - merma
            lines.append(Line(label: "Gastos Operativos", amount: "\(expenses)", kind: .cost))
            lines.append(Line(label: "Merma", amount: shrinkage, kind: .shrinkage))
            let sum = revenue - cost - expenses - merma + (yastas ?? 0)
            addsUp = Self.decimal(netProfit) == sum
        } else {
            // Can't split merma out of a total we can't read: one row, as the server sent it.
            lines.append(Line(label: "Gastos Operativos (incl. merma)", amount: operatingExpensesTotal, kind: .cost))
            addsUp = false
        }

        if let yastasLine { lines.append(yastasLine) }
        lines.append(Line(label: "Ganancia Neta", amount: netProfit, kind: .total))
        self.lines = lines
    }

    /// The dashboard card: revenue and cost from the same P&L as net profit when the server
    /// sends them, else the item-summed figures (older servers).
    public init(netProfit: NetProfitSummary, itemRevenue: String, itemCost: String,
                operatingExpensesTotal: String, shrinkage: String) {
        self.init(revenue: netProfit.salesRevenue ?? itemRevenue,
                  costOfSales: netProfit.costOfSales ?? itemCost,
                  operatingExpensesTotal: operatingExpensesTotal,
                  shrinkage: shrinkage,
                  yastasServiceRevenue: netProfit.yastasServiceRevenue,
                  netProfit: netProfit.amount)
    }

    /// Server money strings are plain decimals ("1234.56"); anything else is unreadable.
    private static func decimal(_ string: String) -> Decimal? {
        guard string.range(of: #"^-?\d+(\.\d+)?$"#, options: .regularExpression) != nil else { return nil }
        return Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))
    }
}
