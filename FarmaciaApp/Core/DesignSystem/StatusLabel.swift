import SwiftUI
import FarmaciaKit

// MARK: - Status Label
//
// A status said three ways: words, an icon, and the tone's color — never by
// color alone (color-blind users, bright sunlight at the counter).

struct StatusLabel: View {
    let text: String
    let tone: Tone
    var systemImage: String?

    init(_ text: String, tone: Tone, systemImage: String? = nil) {
        self.text = text
        self.tone = tone
        self.systemImage = systemImage
    }

    var body: some View {
        Label(text, systemImage: systemImage ?? tone.systemImage)
            .foregroundStyle(tone.color)
    }
}

extension Tone {
    /// The default icon that goes with a tone's color.
    var systemImage: String {
        switch self {
        case .positive: "checkmark.circle.fill"
        case .caution: "clock.badge.exclamationmark"
        case .critical: "exclamationmark.triangle.fill"
        case .info: "info.circle"
        case .neutral: "calendar"
        }
    }
}
