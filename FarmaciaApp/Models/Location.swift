import Foundation

// MARK: - Location

struct Location: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let squareId: String?
    let name: String
    let address: String?
    let isActive: Bool?  // Optional to handle minimal responses
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Location List Response
// Note: The backend returns locations directly as an array in the 'data' field
// The APIClient wrapper extracts 'data', so we just decode the array
typealias LocationListResponse = [Location]
