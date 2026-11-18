import Foundation
import Testing
@testable import FarmaciaKit

struct ScanROITests {
    @Test("given a metadata rect (top-left origin), should give Vision's bottom-left rect: y = 1 − y − h")
    func flipsY() {
        let rect = ScanROI.visionRect(fromMetadataRect: CGRect(x: 0.2, y: 0.1, width: 0.3, height: 0.6))
        #expect(close(rect, CGRect(x: 0.2, y: 0.3, width: 0.3, height: 0.6)))
    }

    @Test("given a rect spilling outside 0…1, should clamp to the unit square first")
    func clamps() {
        let rect = ScanROI.visionRect(fromMetadataRect: CGRect(x: -0.1, y: 0.9, width: 0.5, height: 0.3))
        #expect(close(rect, CGRect(x: 0, y: 0, width: 0.4, height: 0.1)))
    }

    @Test("given a rect fully outside the image, should fall back to the whole image")
    func outside() {
        #expect(ScanROI.visionRect(fromMetadataRect: CGRect(x: 2, y: 2, width: 1, height: 1)) == CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    private func close(_ a: CGRect, _ b: CGRect) -> Bool {
        [a.minX - b.minX, a.minY - b.minY, a.width - b.width, a.height - b.height].allSatisfy { abs($0) < 1e-9 }
    }
}
