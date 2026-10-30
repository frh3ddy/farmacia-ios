import Foundation
import Testing
@testable import FarmaciaKit

/// Dashboard bodies as farmacia-ops sends them per role. A cashier's carries
/// nothing the pharmacy paid (no cost, gross profit, inventory value, aging value).
struct DashboardReportTests {
    func decode(_ json: String) throws -> DashboardReport {
        try JSONDecoder().decode(DashboardReport.self, from: Data(json.utf8))
    }

    let cashierBody = #"""
    {"period":{"startDate":"2026-10-01T06:00:00.000Z","endDate":"2026-10-30T05:59:59.999Z"},"locationId":"centro",
     "sales":{"totalRevenue":"100000","totalUnitsSold":420,"totalSales":152},
     "inventory":{"totalUnits":3800,"totalProducts":610},
     "adjustments":{"totalAdjustments":7},
     "receivings":{"totalReceivings":12,"totalQuantity":900}}
    """#

    let ownerBody = #"""
    {"period":{"startDate":"2026-10-01T06:00:00.000Z","endDate":null},"locationId":"centro",
     "sales":{"totalRevenue":"100000","totalCOGS":"60000","grossProfit":"40000","grossMarginPercent":"40.00","totalUnitsSold":420,"totalSales":152},
     "inventory":{"totalUnits":3800,"totalValue":"250000","totalProducts":610,"averageCostPerUnit":"65.79",
       "aging":{"under30Days":{"units":1000,"value":"60000"},"days30to60":{"units":900,"value":"55000"},"days60to90":{"units":800,"value":"50000"},"over90Days":{"units":1100,"value":"85000"}}},
     "adjustments":{"totalAdjustments":7,"totalLoss":"2000","totalGain":"150","netImpact":"-1850"},
     "receivings":{"totalReceivings":12,"totalQuantity":900,"totalCost":"58000"},
     "operatingExpenses":{"total":"22000","byType":[{"type":"RENT","amount":"20000","percentage":"100.00"}],"shrinkage":"2000"},
     "netProfit":{"amount":"21000","marginPercent":"20.39","yastasServiceRevenue":"3000","salesRevenue":"100000","costOfSales":"60000"}}
    """#

    @Test("given a cashier dashboard body without cost fields, should decode")
    func cashier() throws {
        let report = try decode(cashierBody)
        #expect(report.sales.totalRevenue == "100000")
        #expect(report.sales.totalSales == 152)
        #expect(report.sales.totalCOGS == nil)
        #expect(report.sales.grossProfit == nil)
        #expect(report.inventory.totalUnits == 3800)
        #expect(report.inventory.totalValue == nil)
        #expect(report.inventory.aging == nil)
        #expect(report.adjustments.totalAdjustments == 7)
        #expect(report.adjustments.netImpact == nil)
        #expect(report.receivings.totalCost == nil)
        #expect(report.netProfit == nil)
    }

    @Test("given an owner's full body, should decode every field as before")
    func owner() throws {
        let report = try decode(ownerBody)
        #expect(report.sales.totalCOGS == "60000")
        #expect(report.sales.grossMarginPercent == "40.00")
        #expect(report.inventory.averageCostPerUnit == "65.79")
        #expect(report.inventory.aging?.over90Days.value == "85000")
        #expect(report.adjustments.netImpact == "-1850")
        #expect(report.receivings.totalCost == "58000")
        #expect(report.operatingExpenses?.shrinkage == "2000")
        #expect(report.netProfit?.costOfSales == "60000")
    }
}
