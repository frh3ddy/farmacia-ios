import SwiftUI
import FarmaciaKit

// MARK: - Month Year Picker
//
// An expiry as the box prints it: month and year, no day calendar to scroll
// (tasks/lot-expiry-capture-epic.md). A Form row "Vence · mar 2027" that opens
// two wheels in place. Starts empty: leaving it so means "no expiry", never a
// made-up default. Saved as the 1st of the month (`MonthYear.firstDay`).

struct MonthYearPicker: View {
    let title: String
    @Binding var value: MonthYear?
    var today = MonthYear(date: .now)
    @State private var isOpen = false

    private var years: ClosedRange<Int> { (today.year - 1)...(today.year + 10) }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: DS.Spacing.s) {
                Button(value?.display() ?? "Elegir", action: toggle)
                .foregroundStyle(value == nil || isOpen ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .monospacedDigit()

                if value != nil {
                    Button("Quitar caducidad", systemImage: "xmark.circle.fill") {
                        withAnimation {
                            value = nil
                            isOpen = false
                        }
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.borderless)
        }
        // The whole row opens it, like a DatePicker row; VoiceOver uses the button.
        .contentShape(.rect)
        .onTapGesture(perform: toggle)

        if isOpen, let current = value {
            HStack(spacing: 0) {
                Picker("Mes", selection: monthBinding(current)) {
                    ForEach(1...12, id: \.self) { month in
                        Text(MonthYear.monthNames[month - 1]).tag(month)
                    }
                }
                Picker("Año", selection: yearBinding(current)) {
                    ForEach(years, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
        }

        if let warning = value?.expiredWarning(today: today) {
            Label(warning, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(Tone.caution.color)
        }
    }

    private func toggle() {
        // Opening an empty one starts the wheels a year out, the usual shelf life.
        if value == nil { value = MonthYear(year: today.year + 1, month: today.month) }
        withAnimation { isOpen.toggle() }
    }

    private func monthBinding(_ current: MonthYear) -> Binding<Int> {
        Binding { current.month } set: { value = MonthYear(year: current.year, month: $0) }
    }

    private func yearBinding(_ current: MonthYear) -> Binding<Int> {
        Binding { current.year } set: { value = MonthYear(year: $0, month: current.month) }
    }
}

#Preview {
    @Previewable @State var expiry: MonthYear? = MonthYear(year: 2027, month: 3)
    @Previewable @State var empty: MonthYear?
    Form {
        MonthYearPicker(title: "Vence", value: $expiry)
        MonthYearPicker(title: "Vence", value: $empty)
    }
}
