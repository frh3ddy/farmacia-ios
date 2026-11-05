import Foundation

// MARK: - Receiving Submit
//
// What a tap on "Recibir inventario" does. While the preferred supplier's cost
// is still loading, a form without a cost waits for it instead of reporting
// "Falta costo" for a cost that's on its way (tasks/receive-before-suppliers-load-epic.md).

public enum ReceivingSubmit {
    public enum Action: Equatable, Sendable {
        case wait
        /// The first thing missing: the form focuses it.
        case showIssues(ReceivingForm.Issue)
        case save
    }

    /// The preferred supplier is picked only once both the product's suppliers and
    /// the full supplier list are in, so the cost is on its way while either loads.
    public static func action(isLoadingProductSuppliers: Bool, isLoadingSupplierList: Bool,
                              unitCost: Double?, issues: [ReceivingForm.Issue]) -> Action {
        if (isLoadingProductSuppliers || isLoadingSupplierList) && unitCost == nil { return .wait }
        return issues.first.map(Action.showIssues) ?? .save
    }
}
