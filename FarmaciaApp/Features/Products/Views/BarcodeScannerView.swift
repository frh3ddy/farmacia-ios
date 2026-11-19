import AVFoundation
import AudioToolbox
import CodeScanner
import FarmaciaKit
import SwiftUI

// MARK: - Product barcode scanner
//
// What every product scan button opens. It shows the new camera scanner
// (BarcodeScannerView: Vision + multi-frame voting) or, while it's being benchmarked,
// the old CodeScanner (AVCaptureMetadataOutput) as the baseline. Release builds use
// the old one until the benchmark passes (tasks/barcode-scanner-epic.md).

struct ProductBarcodeScanner: View {
    /// What the simulator "scans" when tapped (it has no camera).
    var simulatedData = ""
    let completion: (Result<String, Error>) -> Void

    @State private var openedAt = Date()
    // Fixed when the scanner opens: a bench-plan mode switch after this scan must not
    // swap the scanner under the lookup that follows it.
    @State private var useLegacy = ScannerLab.shared.useLegacy
    @State private var settings = ScannerLab.shared.settings
    @State private var finished = false
    private var lab: ScannerLab { .shared }

    var body: some View {
        scanner
            .overlay(alignment: .top) { benchBadge }
            .alert(lab.announcement ?? "", isPresented: Binding(
                get: { lab.announcement != nil },
                set: { if !$0 { lab.announcement = nil } }
            )) {
                Button("OK") {}
            }
    }

    @ViewBuilder private var scanner: some View {
        if useLegacy {
            CodeScannerView(
                codeTypes: [.ean13, .ean8, .upce, .code128, .code39, .code93, .itf14],
                scanMode: .once,
                showViewfinder: true,
                simulatedData: simulatedData,
                shouldVibrateOnSuccess: true
            ) { result in
                switch result {
                case .success(let scan):
                    finished = true
                    lab.log(legacyMetrics(code: scan.string))
                    completion(.success(scan.string))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            .onDisappear {
                // Closed without reading: a give-up row, so read rates count the misses.
                if !finished { lab.log(legacyMetrics(code: nil)) }
            }
        } else {
            BarcodeScannerView(settings: settings, simulatedData: simulatedData) { result in
                if let metrics = result.metrics { lab.log(metrics) }
                completion(result.code)
            } onGiveUp: { lab.log($0) }
        }
    }

    private func legacyMetrics(code: String?) -> ScanMetrics {
        ScanMetrics(date: .now, device: CameraController.deviceModel, detector: .legacy, code: code, msToRead: nil,
                    msSinceOpen: Int(Date.now.timeIntervalSince(openedAt) * 1000), frames: 0, misreads: 0,
                    topConfidence: nil, settingsTag: "legacy")
    }

    /// Which bench-plan mode this is, so nobody loses track mid-test.
    @ViewBuilder private var benchBadge: some View {
        if let plan = lab.plan, let mode = plan.current {
            Text("Prueba · \(mode.name) · \(plan.count)/\(plan.target)")
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.yellow, in: .capsule)
                .foregroundStyle(.black)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
    }
}

/// The scanner's tunable settings, the metrics log and (DEBUG) the bench plan. The
/// DEBUG Escáner screen edits them; DEBUG builds keep metrics and the plan across
/// launches so a benchmark can span them.
// ponytail: hand-tuned settings outside a plan still reset on relaunch.
@MainActor @Observable
final class ScannerLab {
    static let shared = ScannerLab()

    var settings = ScanSettings()
    /// Shown once by the next scanner on screen (bench plan mode changes).
    var announcement: String?
    private(set) var metrics: [ScanMetrics] = []
    private(set) var plan: BenchPlan?

    #if DEBUG
    var useLegacy = false

    private init() {
        let defaults = UserDefaults.standard
        metrics = defaults.data(forKey: Keys.metrics).flatMap { try? JSONDecoder().decode([ScanMetrics].self, from: $0) } ?? []
        plan = defaults.data(forKey: Keys.plan).flatMap { try? JSONDecoder().decode(BenchPlan.self, from: $0) }
        if let mode = plan?.current { apply(mode) }
    }
    #else
    let useLegacy = true
    private init() {}
    #endif

    func log(_ scan: ScanMetrics) {
        metrics.append(scan)
        #if DEBUG
        if var plan {
            let finishedMode = plan.current
            let event = plan.record()
            self.plan = plan
            switch event {
            case .next(let mode):
                apply(mode)
                announcement = "\(finishedMode?.name ?? "") listo (\(plan.target) escaneos). Ahora: \(mode.name)."
            case .finished:
                announcement = "Prueba completa. Exporta el CSV en Ajustes › Escáner (DEBUG)."
            case nil:
                break
            }
        }
        save()
        #endif
    }

    func clearMetrics() {
        metrics.removeAll()
        #if DEBUG
        save()
        #endif
    }

    #if DEBUG
    /// Starts the standard plan: `target` openings per mode, switching by itself.
    func startPlan(target: Int) {
        let plan = BenchPlan(target: target)
        self.plan = plan
        if let mode = plan.current { apply(mode) }
        save()
    }

    func stopPlan() {
        plan = nil
        save()
    }

    private func apply(_ mode: BenchPlan.Mode) {
        useLegacy = mode.legacy
        settings.camera = mode.camera
        settings.preset = mode.preset
    }

    private enum Keys {
        static let metrics = "scanner.lab.metrics"
        static let plan = "scanner.lab.plan"
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(try? JSONEncoder().encode(metrics), forKey: Keys.metrics)
        defaults.set(plan.flatMap { try? JSONEncoder().encode($0) }, forKey: Keys.plan)
    }
    #endif
}

// MARK: - Vision camera scanner

struct BarcodeScannerView: View {
    struct Result {
        var code: Swift.Result<String, Error>
        var metrics: ScanMetrics?
    }

    let settings: ScanSettings
    var simulatedData = ""
    let completion: (Result) -> Void
    /// The camera closed without reading anything (its give-up metrics row).
    var onGiveUp: @MainActor (ScanMetrics) -> Void = { _ in }

    @State private var accepted = 0

    var body: some View {
        content
            .sensoryFeedback(.success, trigger: accepted)
    }

    @ViewBuilder private var content: some View {
        #if targetEnvironment(simulator)
        Button {
            completion(Result(code: .success(simulatedData)))
        } label: {
            ContentUnavailableView("Simulador sin cámara", systemImage: "barcode.viewfinder",
                                   description: Text("Toca para enviar el código simulado."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        #else
        CameraPreview(settings: settings) { code, metrics in
            guard accepted == 0 else { return } // one scan per opening, like CodeScanner's .once
            accepted += 1
            AudioServicesPlaySystemSound(1057)
            completion(Result(code: .success(code), metrics: metrics))
        } onFailure: { failure in
            completion(Result(code: .failure(failure)))
        } onGiveUp: { metrics in
            onGiveUp(metrics)
        }
        .overlay { ScanBoxOverlay(width: settings.scanBoxWidth, height: settings.scanBoxHeight) }
        #endif
    }
}

/// Dims everything but the centered scan box.
private struct ScanBoxOverlay: View {
    let width: Double
    let height: Double

    var body: some View {
        GeometryReader { geo in
            let box = CGRect(x: geo.size.width * (1 - width) / 2, y: geo.size.height * (1 - height) / 2,
                             width: geo.size.width * width, height: geo.size.height * height)
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geo.size))
                path.addRoundedRect(in: box, cornerSize: CGSize(width: 12, height: 12))
            }
            .fill(.black.opacity(0.45), style: FillStyle(eoFill: true))
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white, lineWidth: 2)
                .frame(width: box.width, height: box.height)
                .position(x: box.midX, y: box.midY)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The camera feed. The scan box (same fractions as the overlay) becomes the decoder's
/// region of interest once the camera is configured and whenever the layout changes.
private struct CameraPreview: UIViewRepresentable {
    let settings: ScanSettings
    let onAccept: @MainActor (String, ScanMetrics) -> Void
    let onFailure: @MainActor (CameraController.Failure) -> Void
    let onGiveUp: @MainActor (ScanMetrics) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        let camera = CameraController(
            settings: settings,
            onAccept: { [weak coordinator = context.coordinator] code, metrics in coordinator?.onAccept(code, metrics) },
            onFailure: { [weak coordinator = context.coordinator] failure in coordinator?.onFailure(failure) },
            onConfigured: { [weak view] device in view?.configured(device) },
            // Strong on purpose: the give-up arrives after the view is dismantled.
            onGiveUp: { [onGiveUp] metrics in onGiveUp(metrics) }
        )
        view.attach(camera, box: CGSize(width: settings.scanBoxWidth, height: settings.scanBoxHeight))
        camera.start()
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        context.coordinator.onAccept = onAccept
        context.coordinator.onFailure = onFailure
    }

    static func dismantleUIView(_ view: PreviewView, coordinator: Coordinator) {
        view.camera?.stop()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onAccept: onAccept, onFailure: onFailure) }

    @MainActor final class Coordinator {
        var onAccept: @MainActor (String, ScanMetrics) -> Void
        var onFailure: @MainActor (CameraController.Failure) -> Void

        init(onAccept: @escaping @MainActor (String, ScanMetrics) -> Void,
             onFailure: @escaping @MainActor (CameraController.Failure) -> Void) {
            self.onAccept = onAccept
            self.onFailure = onFailure
        }
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    private var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    private(set) var camera: CameraController?
    private var box = CGSize(width: 1, height: 1)
    private var rotation: AVCaptureDevice.RotationCoordinator?

    func attach(_ camera: CameraController, box: CGSize) {
        self.camera = camera
        self.box = box
        previewLayer.session = camera.session
        previewLayer.videoGravity = .resizeAspectFill
    }

    /// The session has its input (so the preview has a connection): rotate and set the ROI.
    func configured(_ device: AVCaptureDevice) {
        rotation = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let angle = rotation?.videoRotationAngleForHorizonLevelPreview,
           previewLayer.connection?.isVideoRotationAngleSupported(angle) == true {
            previewLayer.connection?.videoRotationAngle = angle
        }
        updateROI()
    }

    /// The box in the layer → metadata (buffer) coordinates → Vision's.
    private func updateROI() {
        // Before the camera is configured there's no connection; configured(_:) relayouts.
        guard previewLayer.connection != nil, bounds.width > 0 else { return }
        let boxRect = CGRect(x: bounds.width * (1 - box.width) / 2, y: bounds.height * (1 - box.height) / 2,
                             width: bounds.width * box.width, height: bounds.height * box.height)
        let metadataRect = previewLayer.metadataOutputRectConverted(fromLayerRect: boxRect)
        camera?.setROI(ScanROI.visionRect(fromMetadataRect: metadataRect))
    }
}
