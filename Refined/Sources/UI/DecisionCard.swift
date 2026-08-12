import SortingKit
import SwiftUI

/// Tells the person in front of the bin what to do with what they are holding.
struct DecisionCard: View {
    let decision: PresentedDecision?
    let isPerceiving: Bool

    @State private var isPulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let decision {
                header(for: decision)
                
                Text(decision.itemName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                if decision.isSplit {
                    components(of: decision)
                } else {
                    advice(for: decision)
                }

                footer(for: decision)
            } else if isPerceiving {
                analyzingState
            } else {
                idleState
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    cardBorderGradient(for: decision),
                    lineWidth: decision?.isHazard == true ? 2.5 : 1
                )
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: decision)
    }

    private var analyzingState: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .scaleEffect(isPulsing ? 1.2 : 0.9)
                    .opacity(isPulsing ? 0.4 : 0.8)
                
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Analyzing Item...")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Reading focus & material features with AI")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            ProgressView()
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private var idleState: some View {
        HStack(spacing: 14) {
            Image(systemName: "viewfinder.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Ready to Scan")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Hold waste item steady in front of camera")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func cardBorderGradient(for decision: PresentedDecision?) -> AnyShapeStyle {
        guard let decision else {
            return AnyShapeStyle(Color.white.opacity(0.15))
        }
        if decision.isHazard {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        if let binColorHex = decision.suggestedBin?.colorHex {
            return AnyShapeStyle(Color(hex: binColorHex).opacity(0.6))
        }
        return AnyShapeStyle(Color.white.opacity(0.2))
    }

    private func header(for decision: PresentedDecision) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if decision.isHazard {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("HAZARDOUS WASTE — B3")
                }
                .font(.caption.weight(.heavy))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2), in: Capsule())
                .foregroundStyle(Color.orange)
            } else if decision.isUncertain {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.diamond.fill")
                    Text("UNCERTAIN CLASSIFICATION")
                }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15), in: Capsule())
                .foregroundStyle(.orange)
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(decision.suggestedBin.map { Color(hex: $0.colorHex) } ?? .gray)
                        .frame(width: 20, height: 20)
                    
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        .frame(width: 20, height: 20)
                }

                Text(decision.headline)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(decision.isUncertain ? .orange : .primary)

                Spacer()

                if isPerceiving {
                    ProgressView().controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private func advice(for decision: PresentedDecision) -> some View {
        if !decision.detail.isEmpty {
            Text(decision.detail)
                .font(decision.isHazard ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(decision.isHazard ? .primary : .secondary)
        }

        if !decision.preparation.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(decision.preparation, id: \.self) { step in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.green)
                            .font(.caption)
                        Text(step)
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }

        if let condition = decision.condition {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                Text(condition)
                    .font(.footnote)
            }
            .foregroundStyle(.orange)
        }
    }

    private func components(of decision: PresentedDecision) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Separate Parts before Disposal:")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            ForEach(decision.components) { component in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(component.bin.map { Color(hex: $0.colorHex) } ?? .gray)
                        .frame(width: 14, height: 14)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(component.name)
                            .font(.headline)
                        
                        Text(component.bin?.displayName ?? "—")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(component.bin.map { Color(hex: $0.colorHex) } ?? .secondary)

                        ForEach(component.preparation, id: \.self) { step in
                            Text("• \(step)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let condition = component.condition {
                            Text("⚠️ \(condition)")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func footer(for decision: PresentedDecision) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: decision.tier == .foundationModel ? "sparkles" : "eye.fill")
                Text(decision.tier == .foundationModel ? "On-device AI" : "Vision AI")
            }
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.08), in: Capsule())

            if !decision.isUncertain && !decision.isHazard && !decision.isSplit {
                Text("• \(Int(decision.confidence * 100))% confidence")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("Bali Regulations Compliant")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
    }
}

