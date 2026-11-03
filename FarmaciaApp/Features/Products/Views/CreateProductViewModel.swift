import SwiftUI
import FarmaciaKit

// MARK: - Create Product View Model

@MainActor
class CreateProductViewModel: ObservableObject {
    // Form fields
    @Published var name = ""
    @Published var sku = ""
    @Published var description = ""
    @Published var sellingPrice: Double?
    @Published var costPrice: Double?
    @Published var initialStock: Int?
    @Published var syncToSquare = true
    @Published var soldAtAllLocations = true
    @Published var selectedSupplier: Supplier?
    /// One per product being created: a retry (or the offline queue's replay) of this create reuses it.
    let clientRequestId = UUID().uuidString

    // State
    @Published var isSubmitting = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    @Published var successMessage = ""
    @Published var suppliers: [Supplier] = []
    /// The product the server created (not set when the create was queued
    /// offline): the view reports it so Productos lists it right away.
    @Published var createdProduct: Product?

    private let apiClient = APIClient.shared

    func loadSuppliers() async {
        do {
            let response: SupplierListResponse = try await apiClient.request(endpoint: .listSuppliers)
            suppliers = response.data
        } catch {
            // Optional — the picker just shows empty if this fails.
            print("Failed to load suppliers: \(error)")
        }
    }

    /// How the form started (e.g. with a scanned SKU): the baseline for
    /// "has the user entered anything?".
    private let start: ProductDraft

    init(prefillSku: String? = nil) {
        let prefill = prefillSku?.isEmpty == false ? prefillSku : nil
        start = ProductDraft(prefillSku: prefill)
        if let prefill {
            sku = prefill
        }
    }

    /// Unsaved work the form protects (no swipe-to-dismiss, Cancelar asks).
    /// The photo lives in the view, so it's passed in.
    func hasChanges(hasPhoto: Bool) -> Bool {
        draft(hasPhoto: hasPhoto).hasChanges(from: start)
    }

    /// The optional fields (Más detalles) hold something.
    var hasDetails: Bool { draft(hasPhoto: false).hasDetails }

    private func draft(hasPhoto: Bool) -> ProductDraft {
        var draft = ProductDraft()
        draft.name = name
        draft.sku = sku
        draft.description = description
        draft.sellingPrice = sellingPrice
        draft.costPrice = costPrice
        draft.initialStock = initialStock
        draft.syncToSquare = syncToSquare
        draft.soldAtAllLocations = soldAtAllLocations
        draft.supplierId = selectedSupplier?.id
        draft.hasPhoto = hasPhoto
        return draft
    }

    // MARK: - Computed Properties

    /// Crear's rule (FarmaciaKit `ProductDraft.canSave`): name and price; a
    /// quantity creates initial stock and then needs its cost.
    var isValid: Bool { draft(hasPhoto: false).canSave }

    var showMarginPreview: Bool {
        sellingPrice != nil && costPrice != nil
    }
    
    var profitPerUnit: Double? {
        guard let price = sellingPrice, let cost = costPrice else { return nil }
        return price - cost
    }
    
    var marginPercent: Double? {
        guard let price = sellingPrice, let cost = costPrice else { return nil }
        return Margin.percent(price: price, cost: cost)
    }
    
    // MARK: - Actions
    
    func createProduct(locationId: String, image: UIImage? = nil) async {
        isSubmitting = true
        let createsStock = draft(hasPhoto: false).createsInitialStock
        
        do {
            let request = CreateProductRequest(
                name: name.trimmingCharacters(in: .whitespaces),
                sku: sku.isEmpty ? nil : sku.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
                sellingPrice: sellingPrice ?? 0,
                costPrice: createsStock ? costPrice : nil,
                initialStock: createsStock ? initialStock : nil,
                supplierId: createsStock ? selectedSupplier?.id : nil,
                locationId: locationId,
                syncToSquare: syncToSquare,
                soldAtAllLocations: soldAtAllLocations,
                clientRequestId: clientRequestId
            )
            
            let response: APIResponse<CreateProductResponse> = try await apiClient.request(
                endpoint: .createProduct,
                body: request
            )
            
            let data = try response.requireData()
            createdProduct = data.product
            var message = "Producto \"\(name)\" creado."
            if data.squareSynced {
                message += "\n✓ Sincronizado con Square POS"
            }
            if data.inventoryCreated {
                message += "\n✓ Inventario inicial agregado"
            }
            
            // Upload image if one was selected (resized to 1600px ceiling first)
            if let image = image, let imageData = image.jpegDataForUpload() {
                do {
                    let _: ImageUploadResponse = try await apiClient.uploadImage(
                        endpoint: .uploadProductImage(id: data.product.id),
                        imageData: imageData,
                        filename: "product_\(data.product.id).jpg"
                    )
                    message += "\n✓ Imagen subida"
                    // Report the product again with its image URL, so Productos'
                    // copy gets the thumbnail (it listed the photo-less one).
                    if let refreshed: ProductDetailResponse = try? await apiClient.request(
                        endpoint: .getProduct(id: data.product.id),
                        queryParams: ["locationId": locationId]
                    ) {
                        createdProduct = refreshed.data
                    }
                } catch {
                    message += "\n⚠ No se pudo subir la imagen (el producto sí se creó)"
                    print("Failed to upload product image: \(error)")
                }
            }
            
            successMessage = message
            showSuccess = true
        } catch NetworkError.queuedForSync {
            // The queued replay carries this create's clientRequestId, so it
            // can't duplicate itself; creating the product again from a new
            // form would. No product id exists yet, so image upload can't run.
            // Productos reloads when the queue syncs, so the product shows up
            // by itself then (ProductsView, onChange of pendingCount).
            var message = "\"\(name)\" se creará cuando vuelva la conexión y aparecerá en la lista en ese momento. Evita crearlo de nuevo mientras tanto."
            // The photo waits on the device and uploads once the create syncs
            // (OfflinePhotoStore / OfflineQueueManager).
            if let image {
                if let jpeg = image.jpegDataForUpload(),
                   OfflinePhotoStore.save(jpeg, forRequest: clientRequestId) {
                    message += " La foto se sube al sincronizar."
                } else {
                    message += "\n\nLa foto no se pudo guardar: agrégala desde el producto cuando ya aparezca en la lista."
                }
            }
            successMessage = "Sin conexión. " + message
            showSuccess = true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "Error al crear producto"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSubmitting = false
    }
}
