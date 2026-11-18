import CoreGraphics
import CoreVideo
import FarmaciaKit
import Vision

// MARK: - Vision barcode detector
//
// Apple Vision's barcode reader on one frame, limited to the scan box (`roi`, Vision's
// normalized bottom-left coordinates; see `ScanROI`) and to the enabled symbologies.
// Frames go in as the sensor delivers them (orientation .up): the reader handles any
// rotation, and the ROI stays in the buffer's own space. Returns raw reads; validation
// and voting are `ResultAggregator`'s.
//
// ponytail: no BarcodeDetector protocol yet; add it with stage 2's second detector.

public struct VisionBarcodeDetector: Sendable {
    public let symbologies: Set<Symbology>

    public init(symbologies: Set<Symbology>) {
        self.symbologies = symbologies
    }

    public func detect(in buffer: CVPixelBuffer, roi: CGRect) throws -> [BarcodeCandidate] {
        try run(VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up), roi: roi)
    }

    public func detect(in image: CGImage, roi: CGRect) throws -> [BarcodeCandidate] {
        try run(VNImageRequestHandler(cgImage: image, orientation: .up), roi: roi)
    }

    private func run(_ handler: VNImageRequestHandler, roi: CGRect) throws -> [BarcodeCandidate] {
        let request = VNDetectBarcodesRequest()
        request.revision = VNDetectBarcodesRequestRevision4
        request.symbologies = symbologies.flatMap(Self.vision)
        request.regionOfInterest = roi
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let payload = observation.payloadStringValue,
                  let symbology = Self.symbology(observation.symbology) else { return nil }
            return BarcodeCandidate(symbology: symbology, payload: payload, confidence: observation.confidence)
        }
    }

    private static func vision(_ s: Symbology) -> [VNBarcodeSymbology] {
        switch s {
        case .ean13: [.ean13]
        case .ean8: [.ean8]
        case .upce: [.upce]
        case .code128: [.code128]
        case .code39: [.code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum]
        case .code93: [.code93, .code93i]
        case .itf14: [.itf14]
        }
    }

    private static func symbology(_ v: VNBarcodeSymbology) -> Symbology? {
        Symbology.allCases.first { vision($0).contains(v) }
    }
}
