import SwiftUI

public struct AnalyticsView: View {
    @Bindable var analyticsStore = AnalyticsStore.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCardsSection
                    breakdownCardSection
                    historyLogSection
                }
                .padding()
            }
            .navigationTitle("Analytics & History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var summaryCardsSection: some View {
        HStack(spacing: 12) {
            StatCardView(
                titleText: "TOTAL SCANNED",
                valueText: "\(analyticsStore.totalCount)",
                systemIconName: "number",
                accentColor: .purple
            )
            StatCardView(
                titleText: "DIVERSION RATE",
                valueText: "\(analyticsStore.diversionRatePercentage)%",
                systemIconName: "leaf.fill",
                accentColor: .green
            )
            StatCardView(
                titleText: "CARBON SAVED",
                valueText: "\(analyticsStore.totalCarbonSavedGrams)g",
                systemIconName: "leaf.arrow.circlepath",
                accentColor: .blue
            )
        }
    }

    private var breakdownCardSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WASTE BREAKDOWN BY BIN")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            progressBar

            VStack(spacing: 8) {
                LegendRowView(
                    bulletColor: .green,
                    labelText: "Organic (Food Scraps)",
                    itemCount: analyticsStore.count(for: .organik),
                    totalCount: analyticsStore.totalCount
                )
                LegendRowView(
                    bulletColor: .yellow,
                    labelText: "Inorganic (Plastic, Metal, Glass)",
                    itemCount: analyticsStore.count(for: .anorganik),
                    totalCount: analyticsStore.totalCount
                )
                LegendRowView(
                    bulletColor: .blue,
                    labelText: "Paper (Cardboard, Paper)",
                    itemCount: analyticsStore.count(for: .kertas),
                    totalCount: analyticsStore.totalCount
                )
                LegendRowView(
                    bulletColor: .red,
                    labelText: "Hazardous (Batteries, E-Waste)",
                    itemCount: analyticsStore.count(for: .b3),
                    totalCount: analyticsStore.totalCount
                )
                LegendRowView(
                    bulletColor: .gray,
                    labelText: "Residual (General Trash)",
                    itemCount: analyticsStore.count(for: .residu),
                    totalCount: analyticsStore.totalCount
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let total = CGFloat(max(analyticsStore.totalCount, 1))
            let organikW = geo.size.width * CGFloat(analyticsStore.count(for: .organik)) / total
            let anorganikW = geo.size.width * CGFloat(analyticsStore.count(for: .anorganik)) / total
            let kertasW = geo.size.width * CGFloat(analyticsStore.count(for: .kertas)) / total
            let b3W = geo.size.width * CGFloat(analyticsStore.count(for: .b3)) / total
            let residuW = geo.size.width * CGFloat(analyticsStore.count(for: .residu)) / total

            HStack(spacing: 2) {
                if analyticsStore.totalCount > 0 {
                    Rectangle().fill(Color.green).frame(width: organikW)
                    Rectangle().fill(Color.yellow).frame(width: anorganikW)
                    Rectangle().fill(Color.blue).frame(width: kertasW)
                    Rectangle().fill(Color.red).frame(width: b3W)
                    Rectangle().fill(Color.gray).frame(width: residuW)
                } else {
                    Rectangle().fill(Color.secondary.opacity(0.2))
                }
            }
        }
        .frame(height: 14)
        .clipShape(Capsule())
    }

    private var historyLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SCANNED HISTORY LOG")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
                if analyticsStore.totalCount > 0 {
                    Button("Clear") {
                        analyticsStore.clearHistory()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }

            if analyticsStore.records.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.fill")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No items scanned yet in this session.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(analyticsStore.records) { record in
                    let bin = Bin.resolve(record.binID)
                    HStack {
                        Circle()
                            .fill(color(for: bin.colorName))
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.objectName)
                                .font(.body)
                                .fontWeight(.bold)
                            Text(record.materialName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if record.carbonSavedGrams > 0 {
                                Text("-\(record.carbonSavedGrams)g CO₂")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            Text(record.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func color(for name: String) -> Color {
        switch name {
        case "green": return .green
        case "yellow": return .yellow
        case "blue": return .blue
        case "red": return .red
        default: return .gray
        }
    }
}
