import AVFoundation
import CoreImage
import FarmaciaKit
import FarmaciaScan
import SwiftUI

// MARK: - Lot lab reader (DEBUG bench)
//
// The lot OCR lab (tasks/lot-ocr-lab-epic.md): our own camera (CameraController) instead
// of VisionKit's live text, each frame read through the next `LotFilter`, accepting on the
// first plausible date (`LotReading`). DEBUG switches it on in Ajustes › Escáner and logs
// one `LotScanMetrics` row per opening, from either reader, to compare them.

/// The lot scanner's DEBUG switch and metrics log (kept across launches, like `ScannerLab`).
@MainActor @Observable
final class LotLab {
    static let shared = LotLab()

    #if DEBUG
    /// Our camera + filters instead of live text.
    var useLab = false
    /// Camera and box for the lab reader (the barcode defaults; 4K to try small print).
    var settings = ScanSettings()
    /// How long the lab reader keeps counting after it fills the form (`LotReading`).
    let followUp: TimeInterval = 1
    /// The rows, and which one filled the form last (`LotScanLog`).
    private var log = LotScanLog()
    var metrics: [LotScanMetrics] { log.rows }

    private init() {
        log = UserDefaults.standard.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(LotScanLog.self, from: $0) } ?? LotScanLog()
    }

    func log(_ row: LotScanMetrics) {
        log.log(row)
        save()
    }

    /// The form that the last scan filled was saved with these values.
    func saved(lot: String?, expiry: MonthYear?) {
        log.saved(lot: lot, expiry: expiry)
        save()
    }

    /// The form closed without saving: its fill must not mark a later save.
    func formClosed() { log.formClosed() }

    func clearMetrics() {
        log.clear()
        save()
    }

    private static let key = "lot.lab.log"

    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(log), forKey: Self.key)
    }
    #else
    let useLab = false
    private init() {}
    func saved(lot: String?, expiry: MonthYear?) {}
    func formClosed() {}
    #endif
}

// MARK: - Frames

/// Frames → the pass's filter → `LotTextReader` → `LotScan` → `LotReading`.
/// Processing queue only (`CameraFrameHandler`).
final class LotFrameHandler: CameraFrameHandler, @unchecked Sendable {
    private let reader = LotTextReader()
    private let followUp: TimeInterval
    private let onAccept: @MainActor @Sendable (LotScan) -> Void
    private let onMetrics: @MainActor @Sendable (LotScanMetrics) -> Void
    private var reading: LotReading
    private var pass = 0
    private var logged = false

    init(followUp: TimeInterval,
         onAccept: @escaping @MainActor @Sendable (LotScan) -> Void,
         onMetrics: @escaping @MainActor @Sendable (LotScanMetrics) -> Void) {
        self.followUp = followUp
        self.onAccept = onAccept
        self.onMetrics = onMetrics
        reading = LotReading(today: MonthYear(date: .now), openedAt: .now, followUp: followUp)
    }

    func started() {
        reading = LotReading(today: MonthYear(date: .now), openedAt: .now, followUp: followUp)
        pass = 0
    }

    func frame(_ buffer: CVPixelBuffer, roi: CGRect) {
        guard !logged else { return }
        let filter = LotFilter.forPass(pass)
        pass += 1
        // ponytail: portrait only (.right); landscape would follow the device rotation.
        let lines = (try? reader.read(CIImage(cvPixelBuffer: buffer), roi: roi, orientation: .right, filter: filter)) ?? []
        let scan = LotScan(lines: lines, barcodes: [], today: MonthYear(date: .now))
        switch reading.pass(scan, filter: filter, at: .now) {
        case .accept(let found): Task { @MainActor in onAccept(found) }
        case .done: log()
        case nil: break
        }
    }

    func stopped() {
        reading.stop() // frames still in flight can't turn a give-up into a read
        log()
    }

    private func log() {
        guard !logged else { return }
        logged = true
        let row = reading.metrics(device: CameraController.deviceModel)
        Task { @MainActor in onMetrics(row) }
    }
}

// MARK: - Camera view

/// The lab reader's camera feed with the scan box and the torch.
struct LotLabCamera: View {
    let settings: ScanSettings
    let followUp: TimeInterval
    let onAccept: @MainActor (LotScan) -> Void
    let onFailure: @MainActor (CameraController.Failure) -> Void
    let onMetrics: @MainActor (LotScanMetrics) -> Void

    @State private var torch = false

    var body: some View {
        LotCameraPreview(settings: settings, torch: torch, followUp: followUp,
                         onAccept: onAccept, onFailure: onFailure, onMetrics: onMetrics)
            .overlay { ScanBoxOverlay(width: settings.scanBoxWidth, height: settings.scanBoxHeight) }
            .overlay(alignment: .top) {
                Button {
                    torch.toggle()
                } label: {
                    Image(systemName: torch ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                        .background(.ultraThinMaterial, in: .circle)
                }
                .foregroundStyle(torch ? .yellow : .white)
                .accessibilityLabel(torch ? "Apagar linterna" : "Encender linterna")
                .padding(.top, DS.Spacing.l)
            }
    }
}

private struct LotCameraPreview: UIViewRepresentable {
    let settings: ScanSettings
    let torch: Bool
    let followUp: TimeInterval
    let onAccept: @MainActor (LotScan) -> Void
    let onFailure: @MainActor (CameraController.Failure) -> Void
    let onMetrics: @MainActor (LotScanMetrics) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        let handler = LotFrameHandler(
            followUp: followUp,
            onAccept: { [weak coordinator = context.coordinator] scan in
                coordinator?.accepted = true
                coordinator?.onAccept(scan)
            },
            // Strong on purpose: the row arrives after the follow-up, once the sheet is gone.
            onMetrics: { [onMetrics] row in onMetrics(row) }
        )
        let camera = CameraController(
            settings: settings, handler: handler,
            onFailure: { [weak coordinator = context.coordinator] failure in coordinator?.onFailure(failure) },
            onConfigured: { [weak view] device in view?.configured(device) }
        )
        view.attach(camera, box: CGSize(width: settings.scanBoxWidth, height: settings.scanBoxHeight))
        camera.start()
        context.coordinator.followUp = followUp
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.camera?.setTorch(torch)
        context.coordinator.onAccept = onAccept
        context.coordinator.onFailure = onFailure
    }

    /// After a read the camera runs on for the follow-up (DEBUG data for "1 read or 2"),
    /// then stops and logs the row. A give-up stops at once: reading on with the sheet gone
    /// would log a read nobody saw (review dev-f8).
    static func dismantleUIView(_ view: PreviewView, coordinator: Coordinator) {
        guard let camera = view.camera else { return }
        guard coordinator.accepted else { return camera.stop() }
        DispatchQueue.main.asyncAfter(deadline: .now() + coordinator.followUp) { camera.stop() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onAccept: onAccept, onFailure: onFailure) }

    @MainActor final class Coordinator {
        var onAccept: @MainActor (LotScan) -> Void
        var onFailure: @MainActor (CameraController.Failure) -> Void
        var followUp: TimeInterval = 0
        /// A date was taken (the form was filled): the follow-up runs.
        var accepted = false

        init(onAccept: @escaping @MainActor (LotScan) -> Void,
             onFailure: @escaping @MainActor (CameraController.Failure) -> Void) {
            self.onAccept = onAccept
            self.onFailure = onFailure
        }
    }
}
