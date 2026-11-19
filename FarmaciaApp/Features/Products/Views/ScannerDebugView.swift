#if DEBUG
import FarmaciaKit
import SwiftUI

// MARK: - Escáner (DEBUG)
//
// Benchmarking the barcode scanner on a device: switch old/new, tune the settings
// (applied the next time a scanner opens), and export one CSV row per scan.

struct ScannerDebugView: View {
    @Bindable private var lab = ScannerLab.shared
    @State private var target = 20

    var body: some View {
        Form {
            benchPlan

            Section {
                Toggle("Escáner anterior (CodeScanner)", isOn: $lab.useLegacy)
            } footer: {
                Text("La línea base para comparar. Los ajustes de abajo son del escáner nuevo.")
            }
            .disabled(lab.plan != nil)

            Section("Cámara") {
                Picker("Lente", selection: $lab.settings.camera) {
                    Text("Gran angular").tag(ScanSettings.Camera.wide)
                    Text("Dual (macro)").tag(ScanSettings.Camera.dualWide)
                    Text("Triple (macro)").tag(ScanSettings.Camera.triple)
                }
                Picker("Resolución", selection: $lab.settings.preset) {
                    Text("1080p").tag(ScanSettings.Preset.hd1080)
                    Text("4K").tag(ScanSettings.Preset.hd4K)
                }
            }
            .disabled(lab.plan != nil)

            Section("Lectura") {
                Stepper("Lecturas iguales: \(lab.settings.votesRequired)", value: $lab.settings.votesRequired, in: 2...3)
                Stepper("Espera tras leer: \(lab.settings.cooldown.formatted(.number.precision(.fractionLength(1)))) s",
                        value: $lab.settings.cooldown, in: 0.5...3, step: 0.5)
                VStack(alignment: .leading) {
                    Text("Confianza mínima: \(lab.settings.minConfidence.formatted(.number.precision(.fractionLength(2))))")
                    Slider(value: $lab.settings.minConfidence, in: 0.3...1, step: 0.05)
                }
                Button("Restablecer ajustes") { lab.settings = ScanSettings() }
            }

            Section {
                ForEach(Array(lab.metrics.suffix(20).reversed().enumerated()), id: \.offset) { _, scan in
                    LabeledContent(scan.code ?? "Sin lectura",
                                   value: "\(scan.msToRead.map { "\($0) ms" } ?? "–") · \(scan.frames) cuadros · \(scan.settingsTag)")
                }
                ShareLink(item: ScanMetrics.csv(lab.metrics), preview: SharePreview("scan-metrics.csv")) {
                    Label("Exportar CSV (\(lab.metrics.count))", systemImage: "square.and.arrow.up")
                }
                Button("Borrar métricas", role: .destructive) { lab.clearMetrics() }
                    .disabled(lab.metrics.isEmpty)
            } header: {
                Text("Métricas")
            } footer: {
                Text("Dispositivo \(CameraController.deviceModel) · ajustes \(lab.settings.tag)")
            }
        }
        .navigationTitle("Escáner (DEBUG)")
    }

    @ViewBuilder private var benchPlan: some View {
        Section {
            if let plan = lab.plan {
                ForEach(Array(plan.modes.enumerated()), id: \.offset) { index, mode in
                    LabeledContent {
                        Text(index < plan.index ? "Listo" : index == plan.index ? "\(plan.count)/\(plan.target)" : "Pendiente")
                    } label: {
                        Label(mode.name, systemImage: index < plan.index ? "checkmark.circle.fill"
                              : index == plan.index ? "record.circle" : "circle")
                    }
                }
                Button("Detener prueba", role: .destructive) { lab.stopPlan() }
            } else {
                Stepper("Escaneos por modo: \(target)", value: $target, in: 5...50, step: 5)
                Button("Iniciar prueba") { lab.startPlan(target: target) }
            }
        } header: {
            Text("Prueba automática")
        } footer: {
            Text("Cuenta cada apertura del escáner (lectura o no) y cambia de modo sola al llegar a la meta. Las métricas se guardan entre aperturas de la app.")
        }
    }
}
#endif
