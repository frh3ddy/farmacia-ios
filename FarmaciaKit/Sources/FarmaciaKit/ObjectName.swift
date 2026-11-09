import Foundation

// MARK: - Object Name
//
// The last resort when a photo's label has no readable name: what the object
// is (Vision's classification labels, best first) plus its color, in Spanish
// with the adjective agreeing ("Botella blanca", "Lentes de sol negros").
// The table covers what the stores stock (checked against the Square
// catalog, Nov 2026), by the real
// VNClassifyImageRequest identifiers; anything else gives no name.

public enum ObjectName {
    private struct Noun {
        let word: String
        var feminine = false
        var plural = false
    }

    private static let nouns: [String: Noun] = [
        // Packaging
        "bottle": Noun(word: "Botella", feminine: true),
        "wine_bottle": Noun(word: "Botella", feminine: true),
        "jar": Noun(word: "Frasco"),
        "carton": Noun(word: "Caja", feminine: true),
        "cardboard_box": Noun(word: "Caja", feminine: true),
        "paper_bag": Noun(word: "Bolsa", feminine: true),
        "bag": Noun(word: "Bolsa", feminine: true),
        "thermos": Noun(word: "Termo"),
        // Health and personal care
        "medicine": Noun(word: "Medicamento"),
        "thermometer": Noun(word: "Termómetro"),
        "syringe": Noun(word: "Jeringa", feminine: true),
        "mask": Noun(word: "Cubrebocas"),
        "glove": Noun(word: "Guante"),
        "glove_other": Noun(word: "Guante"),
        "cosmetic_tool": Noun(word: "Brocha de maquillaje", feminine: true),
        "eyeglasses": Noun(word: "Lentes", plural: true),
        "sunglasses": Noun(word: "Lentes de sol", plural: true),
        // Baby
        "pacifier": Noun(word: "Chupón"),
        "diaper": Noun(word: "Pañal"),
        // Snacks and drinks
        "candy": Noun(word: "Dulce"),
        "chewing_gum": Noun(word: "Chicle"),
        "chocolate": Noun(word: "Chocolate"),
        "cookie": Noun(word: "Galleta", feminine: true),
        "drink": Noun(word: "Bebida", feminine: true),
        "juice": Noun(word: "Jugo"),
        "tea_drink": Noun(word: "Té"),
        "lollipop": Noun(word: "Paleta", feminine: true),
        // Toys and gifts
        "stuffed_animals": Noun(word: "Peluche"),
        "figurine": Noun(word: "Figura", feminine: true),
        "play_card": Noun(word: "Baraja", feminine: true),
        "piggybank": Noun(word: "Alcancía", feminine: true),
        "jewelry": Noun(word: "Bisutería", feminine: true),
        // Stationery
        "pen": Noun(word: "Pluma", feminine: true),
        // Household and misc
        "cup": Noun(word: "Vaso"),
        "drinking_glass": Noun(word: "Vaso"),
        "candle": Noun(word: "Vela", feminine: true),
        "lighter": Noun(word: "Encendedor"),
        "scissors": Noun(word: "Tijeras", feminine: true, plural: true),
        "umbrella": Noun(word: "Paraguas"),
        "sock": Noun(word: "Calcetín"),
        "headphones": Noun(word: "Audífonos", plural: true),
        "pillow": Noun(word: "Almohada", feminine: true),
        "gift": Noun(word: "Regalo"),
        "gift_card": Noun(word: "Tarjeta de regalo", feminine: true),
        "balloon": Noun(word: "Globo"),
        // Generic: only used when nothing more specific was recognized.
        "container": Noun(word: "Envase"),
        "basket_container": Noun(word: "Canasta", feminine: true),
        "toy": Noun(word: "Juguete"),
        "candy_other": Noun(word: "Dulce"),
    ]

    private static let generic: Set<String> = ["container", "basket_container", "toy", "candy_other"]

    public static func spanish(labels: [String], color: ColorName?) -> String? {
        let known = labels.filter { nouns[$0] != nil }
        guard let label = known.first(where: { !generic.contains($0) }) ?? known.first,
              let noun = nouns[label] else { return nil }
        guard let color else { return noun.word }
        let adjective = noun.feminine ? color.feminine : color.masculine
        return "\(noun.word) \(noun.plural ? pluralized(adjective) : adjective)"
    }

    /// Spanish color adjectives: vowel → +s ("blancos"), consonant → +es ("grises").
    private static func pluralized(_ word: String) -> String {
        "aeiouáéíóú".contains(word.last ?? " ") ? word + "s" : word + "es"
    }
}
