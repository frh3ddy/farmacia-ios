import SwiftUI

// MARK: - Date Range Picker

struct DateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onApply: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Desde")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Hasta")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }

            Button("Aplicar") {
                onApply()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Report Header Card

struct ReportHeaderCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let color: Color

    init(title: String, value: String, subtitle: String? = nil, color: Color = .blue) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Currency Formatter

func formatCurrency(_ value: String) -> String {
    guard let doubleValue = Double(value) else { return "$\(value)" }
    return formatCurrency(doubleValue)
}

func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "MXN"
    return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
}

func formatPercent(_ value: String) -> String {
    guard let doubleValue = Double(value) else { return "\(value)%" }
    return String(format: "%.1f%%", doubleValue)
}
