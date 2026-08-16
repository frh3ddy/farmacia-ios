import Foundation

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
    @Published var successMessage: String?
    @Published var showSuccess = false

    // MARK: - Dependencies
    private let apiClient = APIClient.shared

    // MARK: - Date Formatter (for date-only fields)
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

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
                endpoint: .ajustesByLocation(locationId: locationId)
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
    func receiveInventory(
        productId: String,
        quantity: Int,
        unitCost: Double,
        locationId: String,
        supplierId: String?,
        invoiceNumber: String?,
        batchNumber: String?,
        expiryDate: Date?,
        notes: String?,
        sellingPrice: Double? = nil,
        syncPriceToSquare: Bool = true
    ) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }

        // Format date as YYYY-MM-DD string to avoid timezone issues
        let expiryDateString = expiryDate.map { Self.dateOnlyFormatter.string(from: $0) }

        let request = ReceiveInventoryRequest(
            locationId: locationId,
            productId: productId,
            quantity: quantity,
            unitCost: unitCost,
            supplierId: supplierId,
            invoiceNumber: invoiceNumber?.isEmpty == true ? nil : invoiceNumber,
            purchaseOrderId: nil,
            batchNumber: batchNumber?.isEmpty == true ? nil : batchNumber,
            expiryDate: expiryDateString,
            manufacturingDate: nil,
            receivedBy: nil,
            notes: notes?.isEmpty == true ? nil : notes,
            syncToSquare: true,
            sellingPrice: sellingPrice,
            syncPriceToSquare: sellingPrice != nil ? syncPriceToSquare : nil,
            clientRequestId: UUID().uuidString
        )

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

            // Reload recepciones
            await loadReceivings(locationId: locationId)

            return true
        } catch NetworkError.queuedForSync {
            // Accepted offline — the global connectivity banner already tells
            // the user it'll sync, so the form can close as if it succeeded.
            return true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
            return false
        } catch {
            errorMessage = "Error al recibir inventario"
            showError = true
            return false
        }
    }

    // MARK: - Create Adjustment
    func createAdjustment(
        type: AdjustmentType,
        productId: String,
        quantity: Int,
        locationId: String,
        reason: String?,
        notes: String?
    ) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }

        // Check if this type has a quick endpoint
        let useQuickEndpoint: Bool
        let endpoint: APIEndpoint

        switch type {
        case .damage:
            endpoint = .adjustmentDamage
            useQuickEndpoint = true
        case .theft:
            endpoint = .adjustmentTheft
            useQuickEndpoint = true
        case .expired:
            endpoint = .adjustmentExpired
            useQuickEndpoint = true
        case .found:
            endpoint = .adjustmentFound
            useQuickEndpoint = true
        case .returnType:
            endpoint = .adjustmentReturn
            useQuickEndpoint = true
        case .countCorrection:
            endpoint = .adjustmentCountCorrection
            useQuickEndpoint = true
        case .writeOff:
            endpoint = .adjustmentWriteOff
            useQuickEndpoint = true
        default:
            endpoint = .createAdjustment
            useQuickEndpoint = false
        }

        // Use quick adjustment for specific types, full adjustment for generic
        if !useQuickEndpoint {
            let request = CreateAdjustmentRequest(
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
                clientRequestId: UUID().uuidString
            )

            do {
                let response: AdjustmentResponse = try await apiClient.request(
                    endpoint: endpoint,
                    body: request
                )
                successMessage = response.message
                showSuccess = true
                await loadAdjustments(locationId: locationId)
                return true
            } catch NetworkError.queuedForSync {
                return true
            } catch let error as NetworkError {
                errorMessage = error.errorDescription
                showError = true
                return false
            } catch {
                errorMessage = "Error al crear ajuste"
                showError = true
                return false
            }
        } else {
            // Quick adjustment endpoints
            let request = QuickAdjustmentRequest(
                locationId: locationId,
                productId: productId,
                quantity: abs(quantity),
                reason: reason,
                notes: notes,
                syncToSquare: true,
                clientRequestId: UUID().uuidString
            )

            do {
                let response: AdjustmentResponse = try await apiClient.request(
                    endpoint: endpoint,
                    body: request
                )
                successMessage = response.message
                showSuccess = true
                await loadAdjustments(locationId: locationId)
                return true
            } catch NetworkError.queuedForSync {
                return true
            } catch let error as NetworkError {
                errorMessage = error.errorDescription
                showError = true
                return false
            } catch {
                errorMessage = "Error al crear ajuste"
                showError = true
                return false
            }
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
