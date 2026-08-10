import SortingKit
import SwiftUI

/// Tells the person in front of the bin what to do with what they are holding.
struct DecisionCard: View {
    let decision: PresentedDecision?
    let isPerceiving: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let decision {
                header(for: decision)
                Text(decision.itemName)
                    .font(.title3.weight(.semibold))
                Text(decision.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                footer(for: decision)
            } else if isPerceiving {
                Label("Reading item…", systemImage: "sparkles")
                    .font(.title3.weight(.semibold))
            } else {
                Label("Hold an item up to the camera", systemImage: "camera.viewfinder")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .animation(.snappy, value: decision)
    }

    private func header(for decision: PresentedDecision) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(decision.bin.map { Color(hex: $0.colorHex) } ?? .orange)
                .frame(width: 16, height: 16)

            Text(decision.headline)
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(decision.isUncertain ? .orange : .primary)

            if isPerceiving {
                ProgressView().controlSize(.small)
            }
        }
    }

    /// Which tier produced this answer, so an operator can tell a model-backed reading
    /// from a degraded keyword guess without digging through logs.
    private func footer(for decision: PresentedDecision) -> some View {
        HStack(spacing: 6) {
            Image(systemName: decision.tier == .foundationModel ? "sparkles" : "eye")
            Text(decision.tier == .foundationModel ? "On-device model" : "Vision classifier")
            if !decision.isUncertain {
                Text("· \(Int(decision.confidence * 100))% confident")
            }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
}
