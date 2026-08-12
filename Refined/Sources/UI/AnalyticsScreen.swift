import Charts
import SortingKit
import SwiftUI

/// Operator-facing numbers: what the station sorted, when, and how often it was unsure.
struct AnalyticsScreen: View {
    let eventStore: ScanEventStore
    let ruleset: SortingRuleset

    @Environment(\.dismiss) private var dismiss
    @State private var events: [ScanEvent] = []
    @State private var exportFile: URL?
    @State private var loadError: Error?

    private var summary: AnalyticsSummary {
        AnalyticsSummary(
            events: events,
            knownBinIDs: Set(ruleset.bins.map(\.id)),
            diversionBinIDs: Set(ruleset.diversionBinIDs),
            recyclingBinIDs: Set(ruleset.recyclingBinIDs)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if let loadError {
                    Text("Could not load history: \(String(describing: loadError))")
                        .foregroundStyle(.secondary)
                }

                headlineSection
                recognitionSection
                binBreakdownSection
                throughputSection
                historySection
            }
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    // Written once when history loads. Building it in the toolbar body
                    // would rewrite the file on every redraw.
                    if let exportFile {
                        ShareLink(item: exportFile) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task { await load() }
        }
    }

    /// A station running the keyword tier looks identical to a working one from across
    /// the room, and is markedly worse at its job. This is where an operator finds out
    /// which tier they are actually getting, and why.
    @ViewBuilder
    private var recognitionSection: some View {
        Section("Recognition") {
            if let reason = FoundationModelPerception.unavailabilityReason {
                LabeledContent("Tier", value: "Vision classifier")
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else {
                LabeledContent("Tier", value: "On-device model")
            }
        }
    }

    private var headlineSection: some View {
        Section("Overview") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                kpiCard(title: "Items Counted", value: "\(summary.totalCount)", icon: "tray.full.fill", color: .blue)
                kpiCard(title: "Diversion Rate", value: "\(summary.diversionRatePercent)%", icon: "leaf.fill", color: .green)
                kpiCard(title: "Recycling Rate", value: "\(summary.recyclingRatePercent)%", icon: "arrow.3.trianglepath", color: .yellow)
                kpiCard(title: "Unsure Rate", value: "\(summary.uncertaintyRatePercent)%", icon: "questionmark.circle.fill", color: .orange)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            .listRowBackground(Color.clear)
        }
    }

    private func kpiCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                Spacer()
            }
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }

    private var binBreakdownSection: some View {
        Section("By Bin") {
            ForEach(summary.binShares, id: \.binID) { share in
                let binColor = ruleset.bin(for: share.binID).map { Color(hex: $0.colorHex) } ?? .secondary
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle()
                            .fill(binColor)
                            .frame(width: 10, height: 10)
                        
                        Text(ruleset.bin(for: share.binID)?.displayName ?? "Retired bin")
                            .font(.subheadline.weight(.medium))
                        
                        Spacer()
                        
                        Text("\(share.count) items (\(share.percentage)%)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(binColor)
                                .frame(width: max(0, geo.size.width * CGFloat(share.percentage) / 100.0), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var throughputSection: some View {
        Section("Items per hour") {
            ThroughputChart(series: ThroughputSeries(events: events))
                .frame(height: 180)
        }
    }

    private var historySection: some View {
        Section("Recent items") {
            if events.isEmpty {
                Text("Nothing counted yet.").foregroundStyle(.secondary)
            } else {
                ForEach(events.prefix(50), id: \.trackID) { event in
                    LabeledContent {
                        Text(event.occurredAt, style: .time).foregroundStyle(.secondary)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(event.itemName)
                            Text(ruleset.bin(for: event.binID)?.displayName ?? "Unsure")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func load() async {
        do {
            let loaded = try await eventStore.allEvents()
            events = loaded
            exportFile = loaded.isEmpty ? nil : CSVExport.makeFile(from: loaded)
        } catch {
            loadError = error
        }
    }
}
