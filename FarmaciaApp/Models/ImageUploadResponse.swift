import Foundation

// MARK: - Product Image Upload Response

struct ImageUploadResponse: Decodable {
    let success: Bool
    let imageUrl: String?
    let squareSynced: Bool?
    let squareImageId: String?
    let message: String?
}
