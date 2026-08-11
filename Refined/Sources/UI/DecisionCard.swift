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

                if decision.isSplit {
                    components(of: decision)
                } else {
                    advice(for: decision)
                }

                footer(for: decision)
            } else if isPerceiving {
                Label("Analyzing…", systemImage: "sparkles")
                    .font(.title3.weight(.semibold))
            } else {
                Label("Hold item up to the camera", systemImage: "camera.viewfinder")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            // Only a hazard gets a border. It is the one answer that is not "put it in
            // that bin", so it should not look like the others at a glance.
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(hazardTint(for: decision) ?? .clear, lineWidth: 3)
        )
        .animation(.snappy, value: decision)
    }

    private func hazardTint(for decision: PresentedDecision?) -> Color? {
        guard let decision, decision.isHazard else { return nil }
        return decision.bin.map { Color(hex: $0.colorHex) } ?? .orange
    }

    private func header(for decision: PresentedDecision) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Said plainly above the bin name rather than left to colour alone, so a
            // guess cannot be mistaken for a confident reading at a glance.
            if decision.isHazard {
                Label("HAZARDOUS WASTE — DO NOT DISPOSE IN REGULAR BINS", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(hazardTint(for: decision) ?? .orange)
            } else if decision.isUncertain {
                Text("UNCERTAIN")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 10) {
                Circle()
                    .fill(decision.suggestedBin.map { Color(hex: $0.colorHex) } ?? .orange)
                    .frame(width: 16, height: 16)

                Text(decision.headline)
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(decision.isUncertain ? .orange : .primary)

                if isPerceiving {
                    ProgressView().controlSize(.small)
                }
            }
        }
    }

    /// Guidance, then what to do to the item, then whatever the camera could not settle.
    @ViewBuilder
    private func advice(for decision: PresentedDecision) -> some View {
        if !decision.detail.isEmpty {
            Text(decision.detail)
                .font(decision.isHazard ? .headline : .subheadline)
                .foregroundStyle(decision.isHazard ? .primary : .secondary)
        }

        ForEach(decision.preparation, id: \.self) { step in
            Label(step, systemImage: "checkmark.circle")
                .font(.subheadline.weight(.medium))
        }

        if let condition = decision.condition {
            Label(condition, systemImage: "questionmark.circle")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
    }

    /// One row per part, each with its own bin colour, so a split reads as two
    /// instructions rather than one confusing one.
    private func components(of decision: PresentedDecision) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(decision.components) { component in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(component.bin.map { Color(hex: $0.colorHex) } ?? .gray)
                        .frame(width: 12, height: 12)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(component.name)
                            .font(.headline)
                        Text(component.bin?.displayName ?? "—")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(component.bin.map { Color(hex: $0.colorHex) } ?? .secondary)
                        ForEach(component.preparation, id: \.self) { step in
                            Text(step)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let condition = component.condition {
                            Text(condition)
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }

    /// Which tier produced this answer, so an operator can tell a model-backed reading
    /// from a degraded keyword guess without digging through logs.
    private func footer(for decision: PresentedDecision) -> some View {
        HStack(spacing: 6) {
            Image(systemName: decision.tier == .foundationModel ? "sparkles" : "eye")
            Text(decision.tier == .foundationModel ? "On-device model" : "Vision classifier")
            if !decision.isUncertain && !decision.isHazard && !decision.isSplit {
                Text("· \(Int(decision.confidence * 100))% confident")
            }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
}
