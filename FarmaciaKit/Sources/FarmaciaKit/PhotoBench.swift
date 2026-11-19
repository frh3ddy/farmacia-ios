import Foundation

// MARK: - Photo search benchmark
//
// `swift run scan-bench --photo-search <refs> <queries>` (tasks/photo-search-epic.md,
// step 8). Reference photos are named after their product ("Jabón neutro.jpg");
// query photos end with the product they show after the last underscore
// ("IMG_5770_Jabón neutro.HEIC").

public enum PhotoBench {
    public struct Result: Equatable, Sendable {
        public let expected: String
        /// Product names, best first.
        public let ranked: [String]
        public init(expected: String, ranked: [String]) {
            self.expected = expected
            self.ranked = ranked
        }
    }

    /// The share of queries whose product is in the first `k`.
    public static func hitRate(_ results: [Result], top k: Int) -> Double {
        guard !results.isEmpty else { return 0 }
        let hits = results.filter { $0.ranked.prefix(k).contains($0.expected) }.count
        return Double(hits) / Double(results.count)
    }

    public static func referenceName(fromFilename name: String) -> String {
        (name as NSString).deletingPathExtension
    }

    public static func expected(fromFilename name: String) -> String? {
        let stem = (name as NSString).deletingPathExtension
        guard let underscore = stem.lastIndex(of: "_") else { return nil }
        let product = String(stem[stem.index(after: underscore)...])
        return product.isEmpty ? nil : product
    }
}
