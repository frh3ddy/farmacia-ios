import Foundation
import Testing
@testable import FarmaciaKit

struct ExpiryPlacementTests {
    let day = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("given a product never received, should be prominent")
    func neverReceived() {
        #expect(ExpiryPlacement(expiriesNewestFirst: []) == .prominent)
    }

    @Test("given a latest receiving without an expiry, should be optional")
    func latestWithout() {
        #expect(ExpiryPlacement(expiriesNewestFirst: [nil, day]) == .optional)
    }

    @Test("given a latest receiving with an expiry, should be prominent")
    func latestWith() {
        #expect(ExpiryPlacement(expiriesNewestFirst: [day, nil]) == .prominent)
    }
}
