import Foundation
import Testing
@testable import FarmaciaKit

struct StartupZoomTests {
    // tan(fov/2) = 0.25: at 100 mm the camera sees 50 mm across, so a 35 mm code fills 70%.
    private let fov = 2 * atan(0.25) * 180 / .pi

    @Test("given a lens that can't focus at the distance where the code fills the box, should zoom by the ratio")
    func zoomsIn() {
        let zoom = StartupZoom.factor(minFocusMM: 200, fovDegrees: fov, codeWidthMM: 35, boxWidthFraction: 0.7, maxZoom: 10)
        #expect(abs(zoom - 2.0) < 1e-9)
    }

    @Test("given a lens that focuses closer than that distance, should not zoom")
    func noZoom() {
        #expect(StartupZoom.factor(minFocusMM: 80, fovDegrees: fov, codeWidthMM: 35, boxWidthFraction: 0.7, maxZoom: 10) == 1)
    }

    @Test("given a needed zoom above the device's maximum, should clamp to it")
    func clamps() {
        #expect(StartupZoom.factor(minFocusMM: 200, fovDegrees: fov, codeWidthMM: 35, boxWidthFraction: 0.7, maxZoom: 1.5) == 1.5)
    }

    @Test("given an unknown minimum focus distance (-1 or 0), should not zoom", arguments: [-1.0, 0.0])
    func unknownFocus(minFocus: Double) {
        #expect(StartupZoom.factor(minFocusMM: minFocus, fovDegrees: fov, codeWidthMM: 35, boxWidthFraction: 0.7, maxZoom: 10) == 1)
    }
}
