import SwiftUI
import FarmaciaKit

// MARK: - Create Product View Model

@MainActor
class CreateProductViewModel: ObservableObject {
    // Form fields
    @Published var name = ""
    @Published var sku = ""
    @Published var gtin = ""
    @Published var description = ""
    @Published var sellingPrice: Double?
    @Published var costPrice: Double?
    @Published var initialStock: Int?
    @Published var syncToSquare = true
    @Published var soldAtAllLocations = true
    @Published var selectedSupplier: Supplier?
    /// The initial stock's lote and caducidad; sent only with stock.
    @Published var batchNumber = ""
    @Published var expiryMonth: MonthYear?
    /// One per product being created: a retry (or the offline queue's replay) of this create reuses it.
    let clientRequestId = UUID().uuidString

    // State
    @Published var isSubmitting = false
    @Published var showError = false
    @Published var errorMessage = ""
    /// Something to read after creating (offline queue, photo trouble):
    /// shown as an alert instead of the button's checkmark.
    @Published var showSuccess = false
    @Published var successMessage = ""
    /// Created with nothing to report: the button shows a checkmark, then the sheet closes.
    @Published var isDone = false
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

    /// How the form started (e.g. with a scanned barcode): the baseline for
    /// "has the user entered anything?".
    private let start: ProductDraft

    init(prefillBarcode: String? = nil) {
        let prefill = prefillBarcode?.isEmpty == false ? prefillBarcode : nil
        start = ProductDraft(prefillBarcode: prefill)
        if let prefill {
            gtin = prefill
        }
    }

    /// Unsaved work the form protects (no swipe-to-dismiss, Cancelar asks).
    /// The photo lives in the view, so it's passed in.
    func hasChanges(hasPhoto: Bool) -> Bool {
        draft(hasPhoto: hasPhoto).hasChanges(from: start)
    }

    private func draft(hasPhoto: Bool) -> ProductDraft {
        var draft = ProductDraft()
        draft.name = name
        draft.sku = sku
        draft.gtin = gtin
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

    /// What Crear still needs, in form order (FarmaciaKit `ProductDraft.issues`):
    /// a name and a price; a quantity creates initial stock and then needs its cost.
    var issues: [ProductDraft.Issue] { draft(hasPhoto: false).issues }

    // MARK: - Actions
    
    func createProduct(locationId: String, image: UIImage? = nil) async {
        isSubmitting = true
        let createsStock = draft(hasPhoto: false).createsInitialStock
        
        do {
            let request = CreateProductRequest(
                name: name.trimmingCharacters(in: .whitespaces),
                sku: sku.isEmpty ? nil : sku.trimmingCharacters(in: .whitespaces),
                gtin: gtin.trimmingCharacters(in: .whitespaces).isEmpty ? nil : gtin.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
                sellingPrice: sellingPrice ?? 0,
                costPrice: createsStock ? costPrice : nil,
                initialStock: createsStock ? initialStock : nil,
                supplierId: createsStock ? selectedSupplier?.id : nil,
                locationId: locationId,
                syncToSquare: syncToSquare,
                soldAtAllLocations: soldAtAllLocations,
                batchNumber: batchNumber,
                expiryDate: expiryMonth?.firstDay(),
                clientRequestId: clientRequestId
            )
            
            let response: APIResponse<CreateProductResponse> = try await apiClient.request(
                endpoint: .createProduct,
                body: request
            )
            
            let data = try response.requireData()
            createdProduct = data.product
            
            // Upload image if one was selected (resized to 1600px ceiling first)
            if let image = image, let imageData = image.jpegDataForUpload() {
                do {
                    let _: ImageUploadResponse = try await apiClient.uploadImage(
                        endpoint: .uploadProductImage(id: data.product.id),
                        imageData: imageData,
                        filename: "product_\(data.product.id).jpg"
                    )
                    // Report the product again with its image URL, so Productos'
                    // copy gets the thumbnail (it listed the photo-less one).
                    if let refreshed: ProductDetailResponse = try? await apiClient.request(
                        endpoint: .getProduct(id: data.product.id),
                        queryParams: ["locationId": locationId]
                    ) {
                        createdProduct = refreshed.data
                    }
                } catch {
                    print("Failed to upload product image: \(error)")
                    successMessage = "\"\(name)\" se creó, pero no se pudo subir la foto. Agrégala desde el producto."
                    showSuccess = true
                    isSubmitting = false
                    return
                }
            }

            if syncToSquare && !data.squareSynced {
                successMessage = "\"\(name)\" se creó, pero no se pudo agregar a Square POS: por ahora solo existe en la app."
                showSuccess = true
            } else {
                isDone = true
            }
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
