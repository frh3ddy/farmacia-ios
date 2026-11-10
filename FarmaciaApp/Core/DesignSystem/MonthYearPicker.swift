import SwiftUI
import FarmaciaKit

// MARK: - Month Year Picker
//
// An expiry as the box prints it: month and year, no day calendar to scroll
// (tasks/lot-expiry-capture-epic.md). A Form row "Vence · mar 2027" that opens
// two wheels. Starts empty: leaving it so means "no expiry", never a
// made-up default. Saved as the 1st of the month (`MonthYear.firstDay`).
// The wheels open in a bottom sheet, so they're never cut off below the row
// (tasks/expiry-picker-styles-epic.md).

struct MonthYearPicker: View {
    let title: String
    @Binding var value: MonthYear?
    var today = MonthYear(date: .now)
    @State private var isOpen = false
    /// The expiry before the sheet opened: a swipe-away puts it back.
    @State private var before: MonthYear?
    /// Listo or Quitar closed it (vs. a swipe-away, which cancels).
    @State private var confirmed = false

    private var years: ClosedRange<Int> { (today.year - 1)...(today.year + 10) }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: DS.Spacing.s) {
                Button(value?.display() ?? "Elegir", action: open)
                .foregroundStyle(value == nil || isOpen ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .monospacedDigit()

                if value != nil {
                    Button("Quitar caducidad", systemImage: "xmark.circle.fill", action: clear)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.borderless)
        }
        // The whole row opens it, like a DatePicker row; VoiceOver uses the button.
        .contentShape(.rect)
        .onTapGesture(perform: open)
        .sheet(isPresented: $isOpen, onDismiss: closed) {
            panel
                // Medium, not a fixed height: wheels + title + Quitar fit with
                // larger text too; drag up for the full height.
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }

        if let warning = value?.expiredWarning(today: today) {
            Label(warning, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(Tone.caution.color)
        }
    }

    /// The bottom sheet: always fully on screen, wherever the row is in the form.
    private var panel: some View {
        VStack(spacing: DS.Spacing.m) {
            HStack {
                Text("Caducidad").font(.headline)
                Spacer()
                Button("Listo") {
                    confirmed = true
                    isOpen = false
                }
                .bold()
            }
            if let current = value {
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
            Button("Quitar caducidad", role: .destructive, action: clear)
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func open() {
        before = value
        confirmed = false
        value = MonthYear.openingValue(current: value, today: today)
        isOpen = true
    }

    /// Quitar: from the row (sheet closed) or from the sheet.
    private func clear() {
        confirmed = true
        withAnimation {
            value = nil
            isOpen = false
        }
    }

    private func closed() {
        value = MonthYear.closingValue(before: before, current: value, confirmed: confirmed)
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
