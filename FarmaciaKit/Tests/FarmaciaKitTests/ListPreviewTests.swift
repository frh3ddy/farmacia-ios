import Testing
@testable import FarmaciaKit

/// How a detail block previews a list: one empty row, the first few, or the first few plus "Ver todo".
struct ListPreviewTests {
    @Test("given 0 events, should be collapsed")
    func empty() {
        #expect(ListPreview(count: 0, limit: 5) == .collapsed)
    }

    @Test("given up to the limit, should show them all without a see-all link",
          arguments: [1, 5])
    func fits(count: Int) {
        #expect(ListPreview(count: count, limit: 5) == .list(shown: count, hasMore: false))
    }

    @Test("given more than the limit, should show the limit and a see-all link")
    func overflow() {
        #expect(ListPreview(count: 7, limit: 3) == .list(shown: 3, hasMore: true))
    }
}
