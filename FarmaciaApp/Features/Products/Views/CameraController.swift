import AVFoundation
import FarmaciaKit
import FarmaciaScan
import os

// MARK: - Camera controller
//
// The barcode scanner's camera: device choice, close-up focus, the one-time startup
// zoom (StartupZoom), and frames → VisionBarcodeDetector → ResultAggregator.
//
// Queues: the session is configured/started/stopped on `sessionQueue`; frames arrive on
// `frameQueue` and are handed to `processingQueue`, skipping any frame that arrives
// while the previous one is still being decoded (plus alwaysDiscardsLateVideoFrames).
// The aggregator and per-scan counters are only touched on `processingQueue`; the ROI
// and busy flag cross queues behind a lock. Accepts hop to the main actor.
//
// Focus and exposure stay in the system's continuous auto modes with a fixed point at
// the scan-box center; nothing here reacts to a detection (see LEGAL_REVIEW.md).

final class CameraController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    enum Failure: Error { case noCamera, denied }

    let session = AVCaptureSession()
    private let settings: ScanSettings
    private let detector: VisionBarcodeDetector
    private let onAccept: @MainActor @Sendable (String) -> Void
    private let onFailure: @MainActor @Sendable (Failure) -> Void
    private let onConfigured: @MainActor @Sendable (AVCaptureDevice) -> Void
    private let onMetrics: @MainActor @Sendable (ScanMetrics) -> Void

    private let sessionQueue = DispatchQueue(label: "scanner.session")
    private let frameQueue = DispatchQueue(label: "scanner.frames")
    private let processingQueue = DispatchQueue(label: "scanner.processing")

    private struct Shared { var busy = false; var roi = CGRect(x: 0, y: 0, width: 1, height: 1) }
    private let shared = OSAllocatedUnfairLock(initialState: Shared())

    // processingQueue only
    private var aggregator: ResultAggregator
    private var frames = 0
    private var countingFrom = Date()
    private var clock: SightingClock
    private var acceptedAny = false

    // sessionQueue only
    private var configured = false
    /// Set by stop(). A start that lands after it (the permission prompt answered after
    /// the scanner closed, or a dismantle racing start) must not turn the camera back on.
    private var stopped = false

    init(settings: ScanSettings,
         onAccept: @escaping @MainActor @Sendable (String) -> Void,
         onFailure: @escaping @MainActor @Sendable (Failure) -> Void,
         onConfigured: @escaping @MainActor @Sendable (AVCaptureDevice) -> Void,
         onMetrics: @escaping @MainActor @Sendable (ScanMetrics) -> Void) {
        self.settings = settings
        detector = VisionBarcodeDetector(symbologies: settings.symbologies)
        aggregator = ResultAggregator(settings: settings)
        clock = SightingClock(gapFrames: settings.voteWindow)
        self.onAccept = onAccept
        self.onFailure = onFailure
        self.onConfigured = onConfigured
        self.onMetrics = onMetrics
    }

    /// The scan box in Vision's coordinates (`ScanROI.visionRect`), from the main thread.
    func setROI(_ roi: CGRect) {
        shared.withLock { $0.roi = roi }
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { self.startSession() } else { self.fail(.denied) }
            }
        default:
            fail(.denied)
        }
    }

    /// Stops the camera for good: the output's delegate is cleared so this controller
    /// (and its session) can be freed once the scanner closes. A camera that ran without
    /// reading anything reports a give-up row (read rates need the misses).
    func stop() {
        sessionQueue.async {
            self.stopped = true
            self.session.stopRunning()
            for case let output as AVCaptureVideoDataOutput in self.session.outputs {
                output.setSampleBufferDelegate(nil, queue: nil)
            }
            guard self.configured else { return }
            self.processingQueue.async { self.reportGiveUp() }
        }
    }

    private func reportGiveUp() {
        guard !acceptedAny else { return }
        let now = Date()
        let metrics = ScanMetrics(date: now, device: Self.deviceModel, detector: .vision, code: nil, msToRead: nil,
                                  msSinceOpen: Int(now.timeIntervalSince(countingFrom) * 1000),
                                  frames: frames, misreads: aggregator.misreads,
                                  topConfidence: clock.topConfidence, settingsTag: settings.tag)
        Task { @MainActor in onMetrics(metrics) }
    }

    private func startSession() {
        sessionQueue.async {
            guard !self.stopped else { return }
            if !self.configured {
                guard let device = self.configure() else { return self.fail(.noCamera) }
                self.configured = true
                Task { @MainActor in self.onConfigured(device) }
            }
            self.processingQueue.async { self.countingFrom = Date() }
            self.session.startRunning()
        }
    }

    private func fail(_ failure: Failure) {
        Task { @MainActor in onFailure(failure) }
    }

    // MARK: Configuration (sessionQueue)

    /// The configured device, or nil when there's no usable camera.
    private func configure() -> AVCaptureDevice? {
        guard let device = Self.device(for: settings.camera),
              let input = try? AVCaptureDeviceInput(device: device) else { return nil }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: frameQueue)

        session.beginConfiguration()
        let preset: AVCaptureSession.Preset = settings.preset == .hd4K ? .hd4K3840x2160 : .hd1920x1080
        session.sessionPreset = session.canSetSessionPreset(preset) ? preset : .high
        guard session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            return nil
        }
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()

        configureFocusAndZoom(device)
        return device
    }

    /// The first available back camera for the setting; virtual devices fall back to wide.
    private static func device(for camera: ScanSettings.Camera) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = switch camera {
        case .wide: [.builtInWideAngleCamera]
        case .dualWide: [.builtInDualWideCamera, .builtInWideAngleCamera]
        case .triple: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera]
        }
        return types.lazy.compactMap { AVCaptureDevice.default($0, for: .video, position: .back) }.first
    }

    private func configureFocusAndZoom(_ device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(settings.fps))
        if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= Double(settings.fps) }) {
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration
        }
        if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
        if device.isSmoothAutoFocusSupported { device.isSmoothAutoFocusEnabled = false }
        // The scan box is centered, so its center is the frame's center.
        let center = CGPoint(x: 0.5, y: 0.5)
        if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = center }
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = center }
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }

        // Startup zoom, set once. A virtual device's 1× is its ultra-wide lens; never go
        // wider than its wide lens (the first switch-over factor).
        let wideZoom = device.virtualDeviceSwitchOverVideoZoomFactors.first.map { CGFloat(truncating: $0) } ?? 1
        let zoom = StartupZoom.factor(minFocusMM: Double(device.minimumFocusDistance),
                                      fovDegrees: Self.shortSideFOV(device.activeFormat),
                                      codeWidthMM: settings.targetCodeWidthMM,
                                      boxWidthFraction: settings.scanBoxWidth,
                                      maxZoom: Double(device.maxAvailableVideoZoomFactor))
        device.videoZoomFactor = min(max(CGFloat(zoom), wideZoom), device.maxAvailableVideoZoomFactor)
    }

    /// `videoFieldOfView` is across the sensor's long side; held in portrait, the scan box's
    /// width runs along the short side.
    // ponytail: portrait only; landscape would use videoFieldOfView directly.
    private static func shortSideFOV(_ format: AVCaptureDevice.Format) -> Double {
        let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let halfLong = Double(format.videoFieldOfView) / 2 * .pi / 180
        return 2 * atan(tan(halfLong) * Double(min(dims.width, dims.height)) / Double(max(dims.width, dims.height))) * 180 / .pi
    }

    // MARK: Frames

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let roi: CGRect? = shared.withLock { state in
            guard !state.busy else { return nil }
            state.busy = true
            return state.roi
        }
        guard let roi else { return } // still decoding the previous frame: skip this one
        nonisolated(unsafe) let frame = buffer
        processingQueue.async { self.process(frame, roi: roi) }
    }

    /// One accept per opening (the scanner closes on it): the accept's row goes to
    /// onMetrics, which outlives the view, so a read landing as the scanner closes still
    /// logs; then frames are dropped, so later codes can't add rows.
    private func process(_ buffer: CVPixelBuffer, roi: CGRect) {
        defer { shared.withLock { $0.busy = false } }
        guard !acceptedAny else { return }
        let reads = (try? detector.detect(in: buffer, roi: roi)) ?? []
        frames += 1
        let now = Date()
        clock.frame(reads, now: now)
        guard let code = aggregator.ingest(reads, now: now) else { return }

        let metrics = ScanMetrics(date: now, device: Self.deviceModel, detector: .vision, code: code,
                                  msToRead: clock.since.map { Int(now.timeIntervalSince($0) * 1000) },
                                  msSinceOpen: Int(now.timeIntervalSince(countingFrom) * 1000),
                                  frames: frames, misreads: aggregator.misreads,
                                  topConfidence: clock.topConfidence, settingsTag: settings.tag)
        acceptedAny = true
        Task { @MainActor in
            onMetrics(metrics)
            onAccept(code)
        }
    }

    /// The hardware model, e.g. "iPhone16,1".
    static let deviceModel: String = {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }()
}
