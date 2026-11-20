import Foundation
import Testing
@testable import FarmaciaKit

struct BenchPlanTests {
    private let modes = Array(BenchPlan.standard.prefix(2))

    @Test("given the standard plan, should test the old scanner, then wide 1080p, triple 1080p and wide 4K")
    func standardOrder() {
        #expect(BenchPlan.standard.map(\.legacy) == [true, false, false, false])
        #expect(BenchPlan.standard.dropFirst().map { "\($0.camera)-\($0.preset)" }
                == ["wide-hd1080", "triple-hd1080", "wide-hd4K"])
    }

    @Test("given the lot plan, should test Apple's live text (the baseline), then the lab at 1080p and at 4K")
    func lotOrder() {
        #expect(BenchPlan.lotStandard.map(\.legacy) == [true, false, false])
        #expect(BenchPlan.lotStandard.dropFirst().map { "\($0.camera)-\($0.preset)" } == ["wide-hd1080", "wide-hd4K"])
        #expect(BenchPlan(modes: BenchPlan.lotStandard, target: 1).current?.name == "Lector de Apple")
    }

    @Test("given fewer scans than the target, should stay on the first mode and count them")
    func counting() {
        var plan = BenchPlan(modes: modes, target: 3)
        #expect(plan.record() == nil)
        #expect(plan.record() == nil)
        #expect(plan.current == modes[0])
        #expect(plan.count == 2)
    }

    @Test("given the target reached, should switch to the next mode and restart the count")
    func switches() {
        var plan = BenchPlan(modes: modes, target: 2)
        plan.record()
        #expect(plan.record() == .next(modes[1]))
        #expect(plan.current == modes[1])
        #expect(plan.count == 0)
    }

    @Test("given the last mode done, should finish and stop counting")
    func finishes() {
        var plan = BenchPlan(modes: modes, target: 1)
        plan.record()
        #expect(plan.record() == .finished)
        #expect(plan.current == nil)
        #expect(plan.record() == nil)
    }

    @Test("given a target below 1, should use 1 scan per mode", arguments: [0, -3])
    func clampsTarget(target: Int) {
        var plan = BenchPlan(modes: modes, target: target)
        #expect(plan.target == 1)
        #expect(plan.record() == .next(modes[1]))
    }

    @Test("given a mode's last opening, should switch to the next and announce both")
    func announcesNext() {
        var plan = BenchPlan(modes: modes, target: 2)
        #expect(plan.recordOpening(finished: "Fin.") == BenchPlan.Step(switchTo: nil, announcement: nil))
        #expect(plan.recordOpening(finished: "Fin.") == BenchPlan.Step(
            switchTo: modes[1], announcement: "\(modes[0].name) listo (2 escaneos). Ahora: \(modes[1].name)."))
    }

    @Test("given the last mode's last opening, should announce the end without a switch")
    func announcesEnd() {
        var plan = BenchPlan(modes: modes, target: 1)
        plan.recordOpening(finished: "Fin.")
        #expect(plan.recordOpening(finished: "Fin.") == BenchPlan.Step(switchTo: nil, announcement: "Fin."))
    }

    @Test("given a saved plan, should decode to the same mode and count")
    func roundTrips() throws {
        var plan = BenchPlan(modes: BenchPlan.standard, target: 2)
        plan.record()
        plan.record()
        plan.record()
        #expect(try JSONDecoder().decode(BenchPlan.self, from: JSONEncoder().encode(plan)) == plan)
    }
}
