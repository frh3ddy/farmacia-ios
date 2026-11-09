import Testing
@testable import FarmaciaKit

/// After a photo in Nuevo producto: an empty Nombre is filled, a typed one is
/// never overwritten (a chip offers the suggestion instead).
struct PhotoNameSuggestionTests {
    @Test("given an empty Nombre and the suggestion Botella verde, should fill it")
    func emptyFills() {
        #expect(PhotoNameSuggestion.action(currentName: "", suggestion: "Botella verde") == .fill("Botella verde"))
    }

    @Test("given a typed Nombre, should offer it as a suggestion")
    func typedSuggests() {
        #expect(PhotoNameSuggestion.action(currentName: "Paracetamol", suggestion: "Botella verde") == .suggest("Botella verde"))
    }

    @Test("given a suggestion equal to the typed name ignoring case and spaces, should do nothing")
    func sameDoesNothing() {
        #expect(PhotoNameSuggestion.action(currentName: " botella  VERDE ", suggestion: "Botella verde") == .none)
    }

    @Test("given only whitespace typed, should fill")
    func whitespaceFills() {
        #expect(PhotoNameSuggestion.action(currentName: "  \n", suggestion: "Botella verde") == .fill("Botella verde"))
    }

    // MARK: A new photo replaces the previous photo's own guess, never what was typed

    @Test("given Nombre still holding the last photo's guess, should fill with the new one")
    func replacesOwnGuess() {
        #expect(PhotoNameSuggestion.action(currentName: "Botella verde", suggestion: "Acne Patch",
                                           autoFilled: "Botella verde") == .fill("Acne Patch"))
    }

    @Test("given Nombre edited after the photo filled it, should only suggest")
    func editedGuessIsTyped() {
        #expect(PhotoNameSuggestion.action(currentName: "Botella verde grande", suggestion: "Acne Patch",
                                           autoFilled: "Botella verde") == .suggest("Acne Patch"))
    }

    @Test("given Descripción still holding the last photo's presentation, should replace it")
    func replacesOwnPresentation() {
        #expect(PhotoNameSuggestion.description(current: "100 ml", presentation: "30 tabletas", autoFilled: "100 ml") == "30 tabletas")
        #expect(PhotoNameSuggestion.description(current: "100 ml frasco", presentation: "30 tabletas", autoFilled: "100 ml") == nil)
    }

    // MARK: Presentation → Descripción, only when it's empty

    @Test("given an empty Descripción and 100 ml read, should fill it")
    func descriptionFills() {
        #expect(PhotoNameSuggestion.description(current: " \n", presentation: "100 ml") == "100 ml")
    }

    @Test("given a typed Descripción or no presentation, should leave it alone",
          arguments: [("Para dolor de cabeza", String?.some("100 ml")), ("", nil)])
    func descriptionKept(current: String, presentation: String?) {
        #expect(PhotoNameSuggestion.description(current: current, presentation: presentation) == nil)
    }

    @Test("given both Vision and the model read a presentation, should prefer Vision's printed text")
    func presentationPrefersVision() {
        #expect(PhotoNameSuggestion.presentation(vision: "100 ml", model: "30 tabletas") == "100 ml")
        #expect(PhotoNameSuggestion.presentation(vision: nil, model: "30 tabletas") == "30 tabletas")
    }

    // MARK: Which source wins: the model, then the label's text, then object + color

    @Test("given a model name and a label name, should prefer the model's")
    func modelFirst() {
        #expect(PhotoNameSuggestion.best(model: "Parches para acné", label: "Acne Patch", object: "Caja morada") == "Parches para acné")
    }

    @Test("given no model name, should use the label's, then the object's, then nothing",
          arguments: [
            (String?.none, String?.some("Acne Patch"), String?.some("Caja morada"), String?.some("Acne Patch")),
            (nil, nil, "Caja morada", "Caja morada"),
            (nil, nil, nil, nil),
          ])
    func fallsThrough(model: String?, label: String?, object: String?, expected: String?) {
        #expect(PhotoNameSuggestion.best(model: model, label: label, object: object) == expected)
    }
}
