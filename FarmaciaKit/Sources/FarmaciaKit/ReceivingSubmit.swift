import Foundation

// MARK: - Receiving Submit
//
// What a tap on "Recibir inventario" does. While the preferred supplier's cost
// is still loading, a form without a cost waits for it instead of reporting
// "Falta costo" for a cost that's on its way (tasks/receive-before-suppliers-load-epic.md).

public enum ReceivingSubmit {
    public enum Action: Equatable, Sendable { case wait, showIssues, save }

    public static func action(isLoadingSupplierCost: Bool, unitCost: Double?, issues: [ReceivingForm.Issue]) -> Action {
        if isLoadingSupplierCost && unitCost == nil { return .wait }
        return issues.isEmpty ? .save : .showIssues
    }
}
