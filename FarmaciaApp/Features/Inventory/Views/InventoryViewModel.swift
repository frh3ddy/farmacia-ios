import Foundation
import FarmaciaKit

// MARK: - Inventory ViewModel

@MainActor
class InventoryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var suppliers: [Supplier] = []
    @Published var recentReceivings: [InventoryReceiving] = []
    @Published var recentAdjustments: [InventoryAdjustment] = []

    @Published var isLoadingProducts = false
    @Published var isLoadingReceivings = false
    @Published var isLoadingAdjustments = false
    @Published var isSubmitting = false

    @Published var errorMessage: String?
    @Published var showError = false
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

    // MARK: - Load Products
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let response: ProductListResponse = try await apiClient.request(endpoint: .listProducts)
            products = response.data
        } catch is CancellationError {
            // Request was cancelled, don't show error
            return
        } catch let error as NetworkError {
            if error.errorDescription?.lowercased().contains("cancel") == true {
                return
            }
            errorMessage = error.errorDescription
            showError = true
        } catch {
            if error.localizedDescription.lowercased().contains("cancel") {
                return
            }
            errorMessage = "Error al cargar productos"
            showError = true
        }
    }

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

    // MARK: - Load Receivings
    func loadReceivings(locationId: String) async {
        isLoadingReceivings = true
        defer { isLoadingReceivings = false }

        do {
            let response: ReceivingListResponse = try await apiClient.request(
                endpoint: .listReceivingsByLocation(locationId: locationId)
            )
            recentReceivings = response.data
        } catch is CancellationError {
            // Request was cancelled, don't show error
            return
        } catch let error as NetworkError {
            // Don't show cancelled errors
            if error.errorDescription?.lowercased().contains("cancel") == true {
                return
            }
            errorMessage = error.errorDescription
            showError = true
        } catch {
            // Don't show cancelled errors
            if error.localizedDescription.lowercased().contains("cancel") {
                return
            }
            errorMessage = "Error al cargar recepciones"
            showError = true
        }
    }

    // MARK: - Load Adjustments
    func loadAdjustments(locationId: String) async {
        isLoadingAdjustments = true
        defer { isLoadingAdjustments = false }

        do {
            let response: AdjustmentListResponse = try await apiClient.request(
                endpoint: .adjustmentsByLocation(locationId: locationId)
            )
            recentAdjustments = response.data
        } catch is CancellationError {
            // Request was cancelled, don't show error
            return
        } catch let error as NetworkError {
            if error.errorDescription?.lowercased().contains("cancel") == true {
                return
            }
            errorMessage = error.errorDescription
            showError = true
        } catch {
            if error.localizedDescription.lowercased().contains("cancel") {
                return
            }
            errorMessage = "Error al cargar ajustes"
            showError = true
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
            successMessage = response.message
            showSuccess = true

            // Write-through: update cache with fresh product data from response
            if let updatedProduct = response.data.product {
                ProductCacheManager.shared.saveProduct(updatedProduct)
            }

            // Reload receivings
            await loadReceivings(locationId: request.locationId)

            return true
        } catch {
            return saved(SaveOutcome(error: error, fallback: "Error al recibir inventario"))
        }
    }

    // MARK: - Create Adjustment
    /// `clientRequestId` is the form's, kept across retries. `countedQuantity`
    /// (count correction only) lets the API derive the change from its own stock.
    func createAdjustment(
        type: AdjustmentType,
        productId: String,
        quantity: Int,
        countedQuantity: Int? = nil,
        locationId: String,
        reason: String?,
        notes: String?,
        clientRequestId: String
    ) async -> Bool {
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
                unitCost: nil,
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
            await loadAdjustments(locationId: locationId)
            return true
        } catch {
            return saved(SaveOutcome(error: error, fallback: "Error al crear ajuste"))
        }
    }

    private func saved(_ outcome: SaveOutcome) -> Bool {
        guard case .failed(let message) = outcome else { return true }
        saveError = message
        return false
    }

    // MARK: - Retry Adjustment Square Sync
    func retryAdjustmentSquareSync(adjustmentId: String, locationId: String) async {
        do {
            let response: RetrySquareSyncResponse = try await apiClient.request(
                endpoint: .retryAdjustmentSquareSync(adjustmentId: adjustmentId)
            )
            successMessage = response.message
            showSuccess = true
            await loadAdjustments(locationId: locationId)
        } catch is CancellationError {
            return
        } catch let error as NetworkError {
            if error.errorDescription?.lowercased().contains("cancel") == true {
                return
            }
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Error al reintentar la sincronización con Square"
            showError = true
        }
    }

    // MARK: - Search Products
    func searchProducts(_ query: String) -> [Product] {
        guard !query.isEmpty else { return products }
        let lowercased = query.lowercased()
        return products.filter { product in
            product.displayName.lowercased().contains(lowercased) ||
            product.sku?.lowercased().contains(lowercased) == true ||
            product.name.lowercased().contains(lowercased)
        }
    }
}

// Note: ReceivingCreateResponse is defined in Inventory.swift
