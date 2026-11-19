import Foundation

// MARK: - Bench plan
//
// The on-device benchmark as a checklist: each mode gets `target` scanner openings
// (reads and give-ups), then the plan moves to the next mode by itself so nobody has
// to remember which modes are done.

public struct BenchPlan: Equatable, Sendable, Codable {
    public struct Mode: Equatable, Sendable, Codable {
        public var name: String
        /// The old CodeScanner instead of the Vision scanner (camera/preset then unused).
        public var legacy: Bool
        public var camera: ScanSettings.Camera
        public var preset: ScanSettings.Preset
    }

    public enum Event: Equatable, Sendable {
        case next(Mode)
        case finished
    }

    public static let standard: [Mode] = [
        Mode(name: "Escáner anterior", legacy: true, camera: .wide, preset: .hd1080),
        Mode(name: "Gran angular 1080p", legacy: false, camera: .wide, preset: .hd1080),
        Mode(name: "Triple 1080p", legacy: false, camera: .triple, preset: .hd1080),
        Mode(name: "Gran angular 4K", legacy: false, camera: .wide, preset: .hd4K),
    ]

    public let modes: [Mode]
    /// Scanner openings per mode.
    public let target: Int
    public private(set) var index = 0
    /// Openings so far in the current mode.
    public private(set) var count = 0

    public init(modes: [Mode] = standard, target: Int) {
        self.modes = modes
        self.target = max(target, 1)
    }

    /// The mode to scan with; nil once every mode is done.
    public var current: Mode? { modes.indices.contains(index) ? modes[index] : nil }

    /// Counts one scanner opening in the current mode; says when the mode changes.
    @discardableResult
    public mutating func record() -> Event? {
        guard current != nil else { return nil }
        count += 1
        guard count >= target else { return nil }
        index += 1
        count = 0
        return current.map(Event.next) ?? .finished
    }
}
