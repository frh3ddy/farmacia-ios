import Testing
@testable import FarmaciaKit

struct LotFilterTests {
    @Test("given passes 0–6, should cycle plain, brightest channel, joined dots, relief, darkened, deep relief, plain")
    func cycles() {
        #expect((0...6).map(LotFilter.forPass) == [.plain, .maxComponent, .dotJoin, .relief, .darkened, .deepRelief, .plain])
    }
}
