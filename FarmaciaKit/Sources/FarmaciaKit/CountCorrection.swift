import Foundation

// MARK: - Count Correction
//
// The form shows the change a count will make against freshly loaded stock;
// the API derives the real change from its own stock when it saves.

public enum CountCorrection {
    /// The change `counted` makes to `current`, or nil when there's nothing to save.
    public static func preview(counted: Int?, current: Int?) -> Int? {
        guard let counted, let current, counted != current else { return nil }
        return counted - current
    }

    /// The count agrees with the loaded stock: nothing to save, but in a counting
    /// run "it matched" is an answer, so the form can close on it.
    public static func matches(counted: Int?, current: Int?) -> Bool {
        counted != nil && counted == current
    }
}
