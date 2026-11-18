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
    private var lab: ScannerLab { .shared }

    var body: some View {
        if lab.useLegacy {
            CodeScannerView(
                codeTypes: [.ean13, .ean8, .upce, .code128, .code39, .code93, .itf14],
                scanMode: .once,
                showViewfinder: true,
                simulatedData: simulatedData,
                shouldVibrateOnSuccess: true
            ) { result in
                switch result {
                case .success(let scan):
                    lab.log(ScanMetrics(date: .now, device: CameraController.deviceModel, detector: .legacy,
                                        code: scan.string, msToRead: Int(Date.now.timeIntervalSince(openedAt) * 1000),
                                        frames: 0, misreads: 0, settingsTag: "legacy"))
                    completion(.success(scan.string))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            BarcodeScannerView(settings: lab.settings, simulatedData: simulatedData) { result in
                if let metrics = result.metrics { lab.log(metrics) }
                completion(result.code)
            }
        }
    }
}

/// The scanner's tunable settings and the metrics log. Settings live in memory; the
/// DEBUG Escáner screen edits them.
// ponytail: settings reset on relaunch; persist them if benchmarking spans launches.
@MainActor @Observable
final class ScannerLab {
    static let shared = ScannerLab()

    var settings = ScanSettings()
    #if DEBUG
    var useLegacy = false
    #else
    let useLegacy = true
    #endif
    private(set) var metrics: [ScanMetrics] = []

    func log(_ scan: ScanMetrics) { metrics.append(scan) }
    func clearMetrics() { metrics.removeAll() }
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

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        let camera = CameraController(
            settings: settings,
            onAccept: { [weak coordinator = context.coordinator] code, metrics in coordinator?.onAccept(code, metrics) },
            onFailure: { [weak coordinator = context.coordinator] failure in coordinator?.onFailure(failure) },
            onConfigured: { [weak view] device in view?.configured(device) }
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
