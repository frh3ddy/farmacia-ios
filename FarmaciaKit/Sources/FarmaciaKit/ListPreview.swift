// MARK: - List Preview
//
// How a detail block previews a list (activity, lots): nothing → one empty
// row; up to `limit` → all of them; more → the first `limit` and "Ver todo".
public enum ListPreview: Equatable, Sendable {
    case collapsed
    case list(shown: Int, hasMore: Bool)

    public init(count: Int, limit: Int) {
        self = count <= 0 ? .collapsed : .list(shown: min(count, limit), hasMore: count > limit)
    }
}
