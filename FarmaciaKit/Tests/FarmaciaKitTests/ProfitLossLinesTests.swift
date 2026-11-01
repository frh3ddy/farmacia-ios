import Foundation
import Testing
@testable import FarmaciaKit

/// The server computes net profit = gross profit − (expenses + merma) + Yastás,
/// and sends operatingExpenses.total already including merma.
struct ProfitLossLinesTests {
    func lines(revenue: String = "100000", cost: String = "60000", expensesTotal: String = "22000",
               shrinkage: String = "2000", yastas: String? = "3000", net: String = "21000") -> ProfitLossLines {
        ProfitLossLines(revenue: revenue, costOfSales: cost, operatingExpensesTotal: expensesTotal,
                        shrinkage: shrinkage, yastasServiceRevenue: yastas, netProfit: net)
    }

    func row(_ label: String, in pl: ProfitLossLines) -> String? {
        pl.lines.first { $0.label == label }?.amount
    }

    @Test("given expenses total 22,000 that include merma 2,000, should show Gastos Operativos 20,000 and Merma 2,000 (merma once)")
    func mermaOnce() {
        let pl = lines()
        #expect(row("Gastos Operativos", in: pl) == "20000")
        #expect(row("Merma", in: pl) == "2000")
    }

    @Test("given revenue 100,000, cost 60,000, expenses 22,000 incl. merma 2,000 and Yastás 3,000, the rows should sum to the server's net profit 21,000")
    func addsUp() {
        let pl = lines()
        #expect(pl.lines.map(\.label) == ["Ingresos", "Costo de Ventas", "Gastos Operativos", "Merma", "Yastás", "Ganancia Neta"])
        #expect(row("Ganancia Neta", in: pl) == "21000")
        #expect(pl.addsUp)
    }

    @Test("given Yastás 0 or an older server without the field, should omit the Yastás row",
          arguments: ["0", "0.00", nil] as [String?])
    func noYastas(yastas: String?) {
        let pl = lines(yastas: yastas, net: "18000")
        #expect(row("Yastás", in: pl) == nil)
        #expect(pl.addsUp)
    }

    @Test("given amounts with cents, should add up exactly")
    func cents() {
        let pl = lines(revenue: "1234.56", cost: "617.28", expensesTotal: "300.10", shrinkage: "0.10", yastas: "0.01", net: "317.19")
        #expect(pl.addsUp)
    }

    @Test("given lines that don't reach the server's net profit, should keep the server's figure and report addsUp false")
    func serverWins() {
        let pl = lines(net: "25000")
        #expect(row("Ganancia Neta", in: pl) == "25000")
        #expect(!pl.addsUp)
    }

    @Test("given an expense amount that isn't a number, should show the server's total as one row (merma included) and report addsUp false")
    func unparseable() {
        let pl = lines(expensesTotal: "N/A")
        #expect(pl.lines.map(\.label) == ["Ingresos", "Costo de Ventas", "Gastos Operativos (incl. merma)", "Yastás", "Ganancia Neta"])
        #expect(row("Gastos Operativos (incl. merma)", in: pl) == "N/A")
        #expect(!pl.addsUp)
    }

    func summary(_ json: String) throws -> NetProfitSummary {
        try JSONDecoder().decode(NetProfitSummary.self, from: Data(json.utf8))
    }

    @Test("given net profit carrying its own sales and cost (sale totals), should use them over the item-summed figures")
    func usesProfitLossTotals() throws {
        // Items sum to 101,000 revenue, but a 1,000 discount on the whole sale makes the sale totals 100,000.
        let net = try summary(#"{"amount":"21000","marginPercent":"20.39","yastasServiceRevenue":"3000","salesRevenue":"100000","costOfSales":"60000"}"#)
        let pl = ProfitLossLines(netProfit: net, itemRevenue: "101000", itemCost: "60000", operatingExpensesTotal: "22000", shrinkage: "2000")
        #expect(row("Ingresos", in: pl) == "100000")
        #expect(pl.addsUp)
    }

    @Test("given an older server without them, should fall back to the item-summed figures")
    func fallsBack() throws {
        let net = try summary(#"{"amount":"18000","marginPercent":"18.00"}"#)
        let pl = ProfitLossLines(netProfit: net, itemRevenue: "100000", itemCost: "60000", operatingExpensesTotal: "22000", shrinkage: "2000")
        #expect(row("Ingresos", in: pl) == "100000")
        #expect(row("Costo de Ventas", in: pl) == "60000")
        #expect(pl.addsUp)
    }

    @Test("given net merma -300 from losses 200 and stock recovered 500, should show Merma 200 and Mercancía recuperada 500, never a negative merma")
    func recoveredLine() {
        let pl = ProfitLossLines(revenue: "100000", costOfSales: "60000", operatingExpensesTotal: "19700",
                                 shrinkage: "-300", shrinkageLosses: "200", shrinkageRecovered: "500",
                                 yastasServiceRevenue: nil, netProfit: "20300")
        #expect(pl.lines.map(\.label) == ["Ingresos", "Costo de Ventas", "Gastos Operativos", "Merma", "Mercancía recuperada", "Ganancia Neta"])
        #expect(row("Gastos Operativos", in: pl) == "20000")
        #expect(row("Merma", in: pl) == "200")
        #expect(row("Mercancía recuperada", in: pl) == "500")
        #expect(pl.addsUp)
    }

    @Test("given nothing recovered, should omit the Mercancía recuperada row")
    func nothingRecovered() {
        let pl = ProfitLossLines(revenue: "100000", costOfSales: "60000", operatingExpensesTotal: "22000",
                                 shrinkage: "2000", shrinkageLosses: "2000", shrinkageRecovered: "0",
                                 yastasServiceRevenue: nil, netProfit: "18000")
        #expect(row("Mercancía recuperada", in: pl) == nil)
        #expect(pl.addsUp)
    }

    @Test("given an older server that sends recovered 500 but no losses, should show only the net Merma row and still add up")
    func recoveredWithoutLosses() {
        let pl = ProfitLossLines(revenue: "100000", costOfSales: "60000", operatingExpensesTotal: "19700",
                                 shrinkage: "-300", shrinkageRecovered: "500",
                                 yastasServiceRevenue: nil, netProfit: "20300")
        #expect(pl.lines.map(\.label) == ["Ingresos", "Costo de Ventas", "Gastos Operativos", "Merma", "Ganancia Neta"])
        #expect(row("Merma", in: pl) == "-300")
        #expect(pl.addsUp)
    }

    @Test("given net merma -300 from losses 200 and recovered 500, the statement's merma rows should be Merma 200 and Mercancía recuperada 500")
    func shrinkageRowsSplit() {
        #expect(ProfitLossLines.shrinkageLines(shrinkage: "-300", losses: "200", recovered: "500") == [
            .init(label: "Merma", amount: "200", kind: .shrinkage),
            .init(label: "Mercancía recuperada", amount: "500", kind: .income),
        ])
    }

    @Test("given recovered 500 but no losses (older server), the statement should show one Merma row with the net -300, not count the recovery twice")
    func shrinkageRowsWithoutLosses() {
        #expect(ProfitLossLines.shrinkageLines(shrinkage: "-300", losses: nil, recovered: "500") == [
            .init(label: "Merma", amount: "-300", kind: .shrinkage),
        ])
    }

    @Test("given a row, should say whether it adds to or subtracts from the result")
    func kinds() {
        #expect(lines().lines.map(\.kind) == [.income, .cost, .cost, .shrinkage, .income, .total])
    }
}
