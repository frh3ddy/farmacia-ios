import Foundation

// MARK: - Lot scan metrics
//
// One row per lot scanner opening, for comparing the live-text reader with the lab reader
// on a device (DEBUG scanner screen → share CSV). `edited` is filled in when the receiving
// is saved: a scanned value the user changed is a misread.

public struct LotScanMetrics: Equatable, Sendable, Codable {
    public enum Reader: String, Sendable, Codable {
        /// VisionKit's DataScannerViewController, the baseline.
        case liveText
        /// Our camera + filters + `LotVote`.
        case lab
    }

    public var date: Date
    /// `utsname` machine identifier, e.g. "iPhone16,1".
    public var device: String
    public var reader: Reader
    public var lot: String?
    public var expiry: MonthYear?
    /// From the scanner opening to the caducidad (or the lote) being taken.
    public var msToExpiry: Int?
    public var msToLot: Int?
    /// Text passes run (lab only).
    public var passes: Int?
    /// The filter of the pass that read the date (lab only).
    public var filter: LotFilter?
    /// Whether the user changed the scanned lote or caducidad before saving; nil until saved.
    public var edited: Bool?
    /// After the accept (DEBUG follow-up, `LotReading`): later passes that read the same date,
    /// and ones that read another date. The data for deciding if 2 reads should be needed.
    public var sameDateReads: Int?
    public var otherDateReads: Int?
    /// Camera and resolution of the lab reader ("wide-hd4K"); nil for live text.
    public var setup: String?

    public init(date: Date, device: String, reader: Reader, lot: String?, expiry: MonthYear?,
                msToExpiry: Int?, msToLot: Int?, passes: Int?, filter: LotFilter?, edited: Bool?,
                sameDateReads: Int? = nil, otherDateReads: Int? = nil, setup: String? = nil) {
        self.date = date
        self.device = device
        self.reader = reader
        self.lot = lot
        self.expiry = expiry
        self.msToExpiry = msToExpiry
        self.msToLot = msToLot
        self.passes = passes
        self.filter = filter
        self.edited = edited
        self.sameDateReads = sameDateReads
        self.otherDateReads = otherDateReads
        self.setup = setup
    }

    /// The form was saved with these values: edited if a value the scanner filled in changed.
    /// A lote the scanner didn't read and the user typed isn't a misread.
    public mutating func recordSave(lot savedLot: String?, expiry savedExpiry: MonthYear?) {
        edited = (lot != nil && savedLot != lot) || (expiry != nil && savedExpiry != expiry)
    }

    public static func csv(_ rows: [LotScanMetrics]) -> String {
        let header = "date,device,reader,outcome,lot,expiry,ms_to_expiry,ms_to_lot,passes,filter,edited,same_date_reads,other_date_reads,setup"
        let lines = rows.map { r in
            [r.date.formatted(.iso8601), r.device, r.reader.rawValue,
             r.lot == nil && r.expiry == nil ? "none" : "read", r.lot ?? "",
             r.expiry.map { String(format: "%04d-%02d", $0.year, $0.month) } ?? "",
             r.msToExpiry.map(String.init) ?? "", r.msToLot.map(String.init) ?? "",
             r.passes.map(String.init) ?? "", r.filter?.rawValue ?? "", r.edited.map { $0 ? "yes" : "no" } ?? "",
             r.sameDateReads.map(String.init) ?? "", r.otherDateReads.map(String.init) ?? "", r.setup ?? ""]
                .map(ScanMetrics.csvField).joined(separator: ",")
        }
        return ([header] + lines).joined(separator: "\n") + "\n"
    }
}
