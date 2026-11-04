import Foundation
import FarmaciaKit

// MARK: - Inventory ViewModel

@MainActor
class InventoryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var suppliers: [Supplier] = []
    @Published var isSubmitting = false

    /// A failed receive or adjustment, shown inside its form (an alert on the
    /// screen behind can't present over the open sheet).
    @Published var saveError: String?
    var showSaveError: Bool {
        get { saveError != nil }
        set { if !newValue { saveError = nil } }
    }
    @Published var successMessage: String?
    @Published var showSuccess = false

    // MARK: - Dependencies
    private let apiClient = APIClient.shared

    // MARK: - Load Suppliers
    func loadSuppliers() async {
        do {
            let response: SupplierListResponse = try await apiClient.request(endpoint: .listSuppliers)
            suppliers = response.data
        } catch {
            // Suppliers are optional, don't show error
            print("Failed to load suppliers: \(error)")
        }
    }

    // MARK: - Receive Inventory
    /// The form builds `request` once per receiving, so a retry reuses its clientRequestId.
    func receiveInventory(_ request: ReceiveInventoryRequest) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let response: ReceivingCreateResponse = try await apiClient.request(
                endpoint: .receiveInventory,
                body: request
            )
            // The form's button shows the checkmark; an alert only when there's
            // something to read: Square didn't take the new stock.
            if let sync = response.data.squareSync, !sync.isSuccess {
                successMessage = response.message
                showSuccess = true
            }

            // Write-through: update cache with fresh product data from response
            if let updatedProduct = response.data.product {
                ProductCacheManager.shared.saveProduct(updatedProduct)
            }
            return true
        } catch {
            return report(SaveOutcome(error: error, fallback: "Error al recibir inventario")) == .saved
        }
    }

    // MARK: - Create Adjustment
    /// `clientRequestId` is the form's, kept across retries. `countedQuantity`
    /// (count correction only) lets the API derive the change from its own stock.
    /// `.costRequired` means the product has no cost on record: the form asks for one.
    func createAdjustment(
        type: AdjustmentType,
        productId: String,
        quantity: Int,
        countedQuantity: Int? = nil,
        unitCost: Double? = nil,
        locationId: String,
        reason: String?,
        notes: String?,
        clientRequestId: String
    ) async -> SaveOutcome {
        isSubmitting = true
        defer { isSubmitting = false }

        // Specific types have a quick endpoint that forces the sign; the rest go generic
        let quickEndpoint: APIEndpoint? = switch type {
        case .damage: .adjustmentDamage
        case .theft: .adjustmentTheft
        case .expired: .adjustmentExpired
        case .found: .adjustmentFound
        case .returnType: .adjustmentReturn
        case .countCorrection: .adjustmentCountCorrection
        case .writeOff: .adjustmentWriteOff
        default: nil
        }

        let body: Encodable = if quickEndpoint != nil {
            QuickAdjustmentRequest(
                locationId: locationId,
                productId: productId,
                quantity: quantity,
                countedQuantity: countedQuantity,
                unitCost: unitCost,
                reason: reason,
                notes: notes,
                syncToSquare: true,
                clientRequestId: clientRequestId
            )
        } else {
            CreateAdjustmentRequest(
                locationId: locationId,
                productId: productId,
                type: type.rawValue,
                quantity: quantity,
                reason: reason,
                notes: notes,
                unitCost: unitCost,
                effectiveDate: nil,
                adjustedBy: nil,
                syncToSquare: true,
                clientRequestId: clientRequestId
            )
        }

        do {
            let response: AdjustmentResponse = try await apiClient.request(
                endpoint: quickEndpoint ?? .createAdjustment,
                body: body
            )
            successMessage = response.message
            showSuccess = true
            return .saved
        } catch {
            return report(SaveOutcome(error: error, fallback: "Error al crear ajuste"))
        }
    }

    /// Shows a failed save's reason inside its form, and hands the outcome back.
    private func report(_ outcome: SaveOutcome) -> SaveOutcome {
        switch outcome {
        case .saved: break
        case .failed(let message), .costRequired(let message): saveError = message
        }
        return outcome
    }
}

// Note: ReceivingCreateResponse is defined in Inventory.swift
