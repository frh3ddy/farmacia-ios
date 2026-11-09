import Foundation

// MARK: - Photo Name Suggestion
//
// After a photo in Nuevo producto, the name read from it (Apple Intelligence,
// the label's text, or object + color) fills an empty Nombre. A typed name is
// never overwritten: the form offers the suggestion as a chip instead.

public enum PhotoNameSuggestion {
    public enum Action: Equatable, Sendable {
        case fill(String)
        case suggest(String)
        case none
    }

    /// `autoFilled` is the name an earlier photo put in Nombre: while Nombre
    /// still holds exactly that, a new photo may replace it.
    public static func action(currentName: String, suggestion: String, autoFilled: String? = nil) -> Action {
        let typed = normalized(currentName)
        if typed.isEmpty || isUntouched(currentName, autoFilled) { return .fill(suggestion) }
        return typed == normalized(suggestion) ? .none : .suggest(suggestion)
    }

    /// The presentation read off the label ("100 ml") for Descripción, only
    /// when nothing is typed there yet. Nil means leave the field alone.
    public static func description(current: String, presentation: String?, autoFilled: String? = nil) -> String? {
        normalized(current).isEmpty || isUntouched(current, autoFilled) ? presentation : nil
    }

    /// The field still holds exactly what a photo put there.
    private static func isUntouched(_ current: String, _ autoFilled: String?) -> Bool {
        autoFilled.map { normalized($0) == normalized(current) } ?? false
    }

    /// Vision's reading is text actually printed on the box; the model may
    /// invent a count, so it only fills in when Vision found nothing.
    public static func presentation(vision: String?, model: String?) -> String? {
        vision ?? model
    }

    /// Apple Intelligence sees the whole photo, so it wins; then the label's own
    /// words; object + color ("Botella verde") is the last resort.
    public static func best(model: String?, label: String?, object: String?) -> String? {
        model ?? label ?? object
    }

    /// Lowercased, with runs of whitespace collapsed to one space.
    private static func normalized(_ s: String) -> String {
        s.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
