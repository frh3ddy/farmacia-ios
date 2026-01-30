import Foundation

// MARK: - Location

struct Location: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let squareId: String?
    let name: String
    let address: String?
    let isActive: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Location List Response

struct LocationListResponse: Decodable {
    let locations: [Location]
    let count: Int
}
