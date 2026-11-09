import Foundation
import Testing
@testable import FarmaciaKit

/// Apple Intelligence gets a fixed time to name a photo. The caller must get
/// control back at the limit even if the work ignores cancellation (a task
/// group would wait for it), and a cancelled caller gets nil at once.
struct DeadlineTests {
    @Test("given work that finishes in time, should return its value")
    func fastWork() async {
        let value = await Deadline.within(.seconds(2)) { "Botella verde" }
        #expect(value == "Botella verde")
    }

    @Test("given work that ignores cancellation and overruns, should return nil at the limit")
    func stubbornWork() async {
        let clock = ContinuousClock()
        let start = clock.now
        let value = await Deadline.within(.milliseconds(50)) { () -> String? in
            // Blocks and never checks cancellation, like a model busy encoding the image.
            Thread.sleep(forTimeInterval: 1.5)
            return "tarde"
        }
        #expect(value == nil)
        #expect(clock.now - start < .milliseconds(1000))
    }

    @Test("given a cancelled caller, should return nil without waiting for the work")
    func cancelledCaller() async {
        let clock = ContinuousClock()
        let start = clock.now
        let task = Task { await Deadline.within(.seconds(5)) { () -> String? in
            try? await Task.sleep(for: .seconds(3))
            return "tarde"
        } }
        task.cancel()
        #expect(await task.value == nil)
        #expect(clock.now - start < .seconds(1))
    }
}
