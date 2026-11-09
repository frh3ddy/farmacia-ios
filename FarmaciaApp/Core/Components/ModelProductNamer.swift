import CoreGraphics
import FarmaciaKit
import Foundation
import FoundationModels
import os

/// Apple Intelligence's reading of a new product's photo: it sees the image
/// itself (iOS 27, vision-capable on-device model, e.g. iPhone 15 Pro with
/// Apple Intelligence on). Anywhere else it returns nil at once and the photo
/// is named by Vision (`ProductPhotoReader`).
enum ModelProductNamer {
    struct Result: Sendable {
        let name: String
        let presentation: String?
    }

    /// The model must answer within this, or Vision's reading is used.
    static let timeout: Duration = .seconds(5)

    static func name(photo: CGImage, labelText: [String]) async -> Result? {
        guard #available(iOS 27, *) else {
            log.notice("Apple Intelligence naming: skipped, iOS < 27")
            return nil
        }
        return await ask(photo: photo, labelText: labelText)
    }

    /// Loads the model when Nuevo producto opens: a cold load can take most of
    /// the timeout, and the first photo would always fall back to Vision.
    /// ponytail: a throwaway session warms the system model; keep the session
    /// for the first photo if the device timing log shows cold starts anyway.
    static func prewarm() {
        guard #available(iOS 27, *), let model = usableModel else { return }
        LanguageModelSession(model: model, instructions: instructions).prewarm()
    }

    @available(iOS 27, *)
    private static var usableModel: SystemLanguageModel? {
        let model = SystemLanguageModel.default
        guard model.availability == .available,
              model.capabilities.contains(.vision),
              model.supportsLocale(Locale(identifier: "es_MX"))
        else { return nil }
        return model
    }

    @available(iOS 27, *)
    private static func ask(photo: CGImage, labelText: [String]) async -> Result? {
        guard let model = usableModel else {
            log.notice("Apple Intelligence naming: skipped, model \(String(describing: SystemLanguageModel.default.availability), privacy: .public)")
            return nil
        }
        let session = LanguageModelSession(model: model, instructions: instructions)
        let text = labelText.prefix(20).joined(separator: "\n")
        let start = ContinuousClock.now
        let answer = await Deadline.within(timeout) {
            try? await session.respond(generating: PhotoProductName.self) {
                "Texto leído en la etiqueta (puede tener errores):\n\(text.isEmpty ? "ninguno" : text)"
                Attachment(photo)
            }.content
        }
        log.notice("Apple Intelligence naming: \(answer == nil ? "no answer" : "answer", privacy: .public) after \(ContinuousClock.now - start, privacy: .public)")
        guard let answer, let name = ModelName.clean(answer.nombre) else { return nil }
        return Result(name: name, presentation: ModelName.clean(answer.presentacion))
    }

    private static let log = Logger(subsystem: "com.farmacia.ios", category: "PhotoName")

    private static let instructions = """
        Eres el asistente de una farmacia en México. Mira la foto de un producto y da su nombre \
        en español, como se escribiría en el catálogo de la tienda. Si la etiqueta muestra la marca \
        o el nombre del producto, úsalo (por ejemplo «Genfar Ibuprofeno»). Si no hay un nombre \
        legible, di qué es el objeto y su color: el sustantivo y luego el color, en español. \
        Máximo 6 palabras, sin comillas ni punto final.
        """
}

@available(iOS 26, *)
@Generable
struct PhotoProductName {
    @Guide(description: "Nombre del producto en español, máximo 6 palabras")
    let nombre: String
    @Guide(description: "Contenido o presentación visible, como «100 ml» o «30 tabletas»; vacío si no se ve")
    let presentacion: String
}
