import SwiftUI

// MARK: - More Details Label
//
// The label of a form's "Más detalles" disclosure (the optional fields).
// Progressive disclosure mustn't hide entered data unnoticed: while closed but
// holding something, the row says "Con datos".

struct MoreDetailsLabel: View {
    /// Closed, with something entered inside (`…Draft.hasDetails`).
    let hasHiddenDetails: Bool

    var body: some View {
        LabeledContent("Más detalles") {
            if hasHiddenDetails {
                Text("Con datos")
            }
        }
    }
}
