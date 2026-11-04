import SwiftUI
import VisionKit
import FarmaciaKit

// MARK: - Lot Scanner
//
// Point the camera at the box: reads the lot and the expiry from the printed
// text, or exactly from a GS1 DataMatrix when the box has one (`LotScan`).
// Once it has both it fills them in and closes; the user checks them in the
// form. With only one found, "Usar" takes what it has.

struct LotScannerView: View {
    /// What was found; called once, then the sheet closes.
    let onUse: (LotScan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scan = LotScan(lines: [], barcodes: [], today: MonthYear(date: .now))
    /// The scanner keeps reporting until the sheet is gone: use it once.
    @State private var used = false

    /// DataScannerViewController needs an A12 chip or later; the form hides the button otherwise.
    static var isSupported: Bool { DataScannerViewController.isSupported }

    var body: some View {
        NavigationStack {
            LiveTextScanner { lines, barcodes in
                scan = LotScan(lines: lines, barcodes: barcodes, today: MonthYear(date: .now))
                if scan.isComplete { use() }
            }
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .bottom) { foundCard }
            .navigationTitle("Escanear lote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .sensoryFeedback(.success, trigger: scan.isComplete) { _, done in done }
    }

    private var foundCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            LabeledContent("Lote", value: scan.lot ?? "Buscando…")
            LabeledContent("Vence", value: scan.expiry?.display() ?? "Buscando…")
            Button("Usar", action: use)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .disabled(scan.lot == nil && scan.expiry == nil)
        }
        .monospacedDigit()
        .padding(DS.Spacing.l)
        .background(.regularMaterial, in: .rect(cornerRadius: DS.Radius.l))
        .padding(DS.Spacing.l)
    }

    private func use() {
        guard !used else { return }
        used = true
        onUse(scan)
        dismiss()
    }
}

// MARK: - Live Text Scanner (VisionKit bridge)

/// Text and DataMatrix codes in view, reported every time they change.
private struct LiveTextScanner: UIViewControllerRepresentable {
    let onChange: (_ lines: [String], _ barcodes: [String]) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(), .barcode(symbologies: [.dataMatrix])],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onChange = onChange
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onChange: ([String], [String]) -> Void

        init(onChange: @escaping ([String], [String]) -> Void) {
            self.onChange = onChange
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd added: [RecognizedItem], allItems: [RecognizedItem]) {
            report(allItems)
        }

        func dataScanner(_ scanner: DataScannerViewController, didUpdate updated: [RecognizedItem], allItems: [RecognizedItem]) {
            report(allItems)
        }

        func dataScanner(_ scanner: DataScannerViewController, didRemove removed: [RecognizedItem], allItems: [RecognizedItem]) {
            report(allItems)
        }

        private func report(_ items: [RecognizedItem]) {
            var lines: [String] = []
            var barcodes: [String] = []
            for item in items {
                switch item {
                case .text(let text): lines += text.transcript.components(separatedBy: .newlines)
                case .barcode(let code): if let payload = code.payloadStringValue { barcodes.append(payload) }
                @unknown default: break
                }
            }
            onChange(lines, barcodes)
        }
    }
}
