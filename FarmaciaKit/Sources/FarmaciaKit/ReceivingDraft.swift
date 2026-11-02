import Foundation

// MARK: - Receiving Draft
//
// What the receive-inventory form holds, as a value, so "has the user entered
// anything?" is a comparison with how the form opened. The baseline includes
// what the form fills in itself (the preferred supplier, its last cost): the
// form updates its baseline when it auto-fills. Drives the form's protection
// against losing work: no swipe-to-dismiss, and Cancelar asks before
// discarding, once there are changes.

public struct ReceivingDraft: Equatable, Sendable {
    public var quantity: Int?
    public var unitCost: Double?
    public var updatesPrice = false
    public var newPrice: Double?
    public var supplierId: String?
    public var invoiceNumber = ""
    public var batchNumber = ""
    public var hasExpiry = false
    public var expiryDate: Date
    public var notes = ""

    /// A fresh form; `expiryDate` is the date its picker starts on.
    public init(expiryDate: Date) {
        self.expiryDate = expiryDate
    }

    public func hasChanges(from start: ReceivingDraft) -> Bool {
        saved != start.saved
    }

    /// Only what a save would use: text trimmed, and values behind a switch
    /// that's off (a new price, an expiry date) dropped.
    private var saved: Saved {
        Saved(
            quantity: quantity,
            unitCost: unitCost,
            newPrice: updatesPrice ? newPrice : nil,
            updatesPrice: updatesPrice,
            supplierId: supplierId,
            invoiceNumber: invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            batchNumber: batchNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            expiryDate: hasExpiry ? expiryDate : nil,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private struct Saved: Equatable {
        let quantity: Int?
        let unitCost: Double?
        let newPrice: Double?
        let updatesPrice: Bool
        let supplierId: String?
        let invoiceNumber: String
        let batchNumber: String
        let expiryDate: Date?
        let notes: String
    }
}
