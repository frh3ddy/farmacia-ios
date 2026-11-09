import Testing
@testable import FarmaciaKit

/// The color of the photographed object: the average of the lifted subject's
/// opaque pixels. The removed background is transparent and must not count.
struct DominantColorTests {
    @Test("given one opaque green pixel and one transparent red pixel, should return green")
    func ignoresTransparent() {
        let rgba: [UInt8] = [0, 255, 0, 255,   255, 0, 0, 0]
        #expect(DominantColor.average(rgba: rgba) == DominantColor.RGB(red: 0, green: 1, blue: 0))
    }

    @Test("given two opaque pixels, should average them")
    func averages() {
        let rgba: [UInt8] = [255, 0, 0, 255,   0, 0, 255, 255]
        #expect(DominantColor.average(rgba: rgba) == DominantColor.RGB(red: 0.5, green: 0, blue: 0.5))
    }

    @Test("given an all-transparent buffer, should return nil")
    func allTransparent() {
        #expect(DominantColor.average(rgba: [9, 9, 9, 0, 9, 9, 9, 0]) == nil)
    }
}
