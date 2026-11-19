import Testing
@testable import FarmaciaKit

struct LotFilterTests {
    @Test("given passes 0–4, should cycle plain, brightest channel, joined dots, relief, plain")
    func cycles() {
        #expect((0...4).map(LotFilter.forPass) == [.plain, .maxComponent, .dotJoin, .relief, .plain])
    }
}
