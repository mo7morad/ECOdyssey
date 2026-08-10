import SwiftUI

struct AnalyticsView: View {
    @Bindable var analyticsStore = AnalyticsStore.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Stat Cards
                    HStack(spacing: 12) {
                        StatCard(title: "TOTAL SCANNED", value: "\(analyticsStore.totalCount)", icon: "number", color: .purple)
                        StatCard(title: "RECYCLING RATE", value: "\(analyticsStore.recyclingRatePercentage)%", icon: "leaf.fill", color: .green)
                    }
                    
                    // Bin Breakdown Progress Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("WASTE BREAKDOWN BY BIN")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        // Progress Bar
                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                if analyticsStore.totalCount > 0 {
                                    Rectangle()
                                        .fill(Color.green)
                                        .frame(width: geo.size.width * CGFloat(analyticsStore.organicCount) / CGFloat(analyticsStore.totalCount))
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: geo.size.width * CGFloat(analyticsStore.recyclableCount) / CGFloat(analyticsStore.totalCount))
                                    Rectangle()
                                        .fill(Color.gray)
                                        .frame(width: geo.size.width * CGFloat(analyticsStore.residualCount) / CGFloat(analyticsStore.totalCount))
                                } else {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.2))
                                }
                            }
                        }
                        .frame(height: 14)
                        .clipShape(Capsule())
                        
                        // Legend List
                        VStack(spacing: 8) {
                            LegendRow(color: .green, label: "Organic Bin (Food Scraps)", count: analyticsStore.organicCount, total: analyticsStore.totalCount)
                            LegendRow(color: .blue, label: "Recyclable Bin (Plastic, Metal, Paper)", count: analyticsStore.recyclableCount, total: analyticsStore.totalCount)
                            LegendRow(color: .gray, label: "Residual Bin (Trash)", count: analyticsStore.residualCount, total: analyticsStore.totalCount)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // Scanned History Log
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
                                HStack {
                                    Circle()
                                        .fill(recordColor(for: record.binCategory))
                                        .frame(width: 10, height: 10)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(record.objectName)
                                            .font(.body)
                                            .fontWeight(.bold)
                                        Text(record.material)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(record.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
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
    
    private func recordColor(for category: AnalysisResult.BinCategory) -> Color {
        switch category {
        case .organic: return .green
        case .nonOrganicRecyclable: return .blue
        case .residual: return .gray
        }
    }
}

// MARK: - Subviews
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title)
                .fontWeight(.heavy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct LegendRow: View {
    let color: Color
    let label: String
    let count: Int
    let total: Int
    
    private var percentage: Int {
        total > 0 ? Int((Double(count) / Double(total)) * 100.0) : 0
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text("\(count) (\(percentage)%)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    AnalyticsView()
}
