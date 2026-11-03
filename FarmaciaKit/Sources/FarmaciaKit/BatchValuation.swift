import Foundation

// MARK: - Batch Valuation
//
// One FIFO lot from GET /inventory/reports/valuation (`byProduct[].batches[]`).

public struct BatchValuation: Decodable, Identifiable, Equatable, Sendable {
    public let batchId: String
    public let quantity: Int
    public let unitCost: String
    public let value: String
    public let receivedAt: Date
    public let age: Int  // days since received

    // Lot metadata (from the linked InventoryReceiving)
    public let source: String?            // "PURCHASE", "OPENING_BALANCE", "ADJUSTMENT"
    public let batchNumber: String?
    public let expiryDate: Date?
    public let manufacturingDate: Date?
    public let invoiceNumber: String?
    public let supplierId: String?
    public let supplierName: String?

    public init(
        batchId: String, quantity: Int, unitCost: String = "0", value: String = "0",
        receivedAt: Date, age: Int = 0, source: String? = nil, batchNumber: String? = nil,
        expiryDate: Date? = nil, manufacturingDate: Date? = nil, invoiceNumber: String? = nil,
        supplierId: String? = nil, supplierName: String? = nil
    ) {
        self.batchId = batchId
        self.quantity = quantity
        self.unitCost = unitCost
        self.value = value
        self.receivedAt = receivedAt
        self.age = age
        self.source = source
        self.batchNumber = batchNumber
        self.expiryDate = expiryDate
        self.manufacturingDate = manufacturingDate
        self.invoiceNumber = invoiceNumber
        self.supplierId = supplierId
        self.supplierName = supplierName
    }

    public var id: String { batchId }

    /// Expired → critical, within `Expiry.warningDays` → caution; nil without an expiry date.
    public var expiryTone: Tone? {
        expiryDate.map { Expiry.tone(daysUntil: Expiry.daysUntil($0)) }
    }

    public var sourceLabel: String {
        BatchSource.label(source)
    }

    /// The order FIFO sells lots: oldest received first.
    public static func fifoOrder(_ lots: [BatchValuation]) -> [BatchValuation] {
        lots.sorted { $0.receivedAt < $1.receivedAt }
    }

    /// The lot the next sale takes from: the oldest one with stock left.
    public static func nextOut(_ lots: [BatchValuation]) -> BatchValuation? {
        fifoOrder(lots).first { $0.quantity > 0 }
    }
}

// MARK: - Lot Summary
//
// Counts for the Lotes FIFO section: by shelf age (`BatchAge.tone`) and by expiry (`expiryTone`).

public struct LotSummary: Equatable, Sendable {
    public let fresh: Int     // 0–30 days
    public let moderate: Int  // 31–90 days
    public let old: Int       // 91+ days
    public let expired: Int
    public let expiringSoon: Int

    public init(lots: [BatchValuation]) {
        let ages = lots.map { BatchAge.tone(days: $0.age) }
        fresh = ages.filter { $0 == .positive }.count
        moderate = ages.filter { $0 == .caution }.count
        old = ages.filter { $0 == .critical }.count
        expired = lots.filter { $0.expiryTone == .critical }.count
        expiringSoon = lots.filter { $0.expiryTone == .caution }.count
    }
}
