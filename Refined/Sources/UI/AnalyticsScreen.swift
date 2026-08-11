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
            LabeledContent("Items counted", value: "\(summary.totalCount)")
            LabeledContent("Diversion rate", value: "\(summary.diversionRatePercent)%")
            LabeledContent("Recycling rate", value: "\(summary.recyclingRatePercent)%")
            // How often the station declined to answer. High values mean the waste
            // stream contains things the rules or the model do not cover yet, which is
            // the most actionable number on this screen.
            LabeledContent("Unsure", value: "\(summary.uncertaintyRatePercent)%")
        }
    }

    private var binBreakdownSection: some View {
        Section("By bin") {
            ForEach(summary.binShares, id: \.binID) { share in
                LabeledContent {
                    Text("\(share.count) · \(share.percentage)%")
                        .foregroundStyle(.secondary)
                } label: {
                    Label {
                        Text(ruleset.bin(for: share.binID)?.displayName ?? "Retired bin")
                    } icon: {
                        Circle()
                            .fill(ruleset.bin(for: share.binID).map { Color(hex: $0.colorHex) } ?? .secondary)
                            .frame(width: 10, height: 10)
                    }
                }
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
