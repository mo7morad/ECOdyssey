import Foundation
import SortingKit

/// A sorting decision resolved against the ruleset and ready to show a person.
///
/// The domain deliberately returns identifiers rather than display text so that bins
/// can be renamed without touching history. This is where those identifiers become
/// words on a screen.
public struct PresentedDecision: Equatable, Sendable {
    /// `nil` when the system declined to name a bin.
    public let bin: Bin?
    public let itemName: String
    public let headline: String
    public let detail: String
    public let confidence: Double
    public let tier: PerceptionTier

    public var isUncertain: Bool { bin == nil }

    /// What to say aloud, or `nil` when there is nothing useful to announce.
    public var spokenPhrase: String? {
        guard let bin else { return nil }
        return "\(itemName). \(bin.spokenPhrase)."
    }

    public init(decision: BinDecision, perception: ItemPerception?, ruleset: SortingRuleset) {
        self.itemName = perception?.itemName ?? "Unrecognised item"
        self.tier = perception?.tier ?? .visionKeyword

        switch decision {
        case let .sorted(binID, _, confidence):
            let resolved = ruleset.bin(for: binID)
            self.bin = resolved
            self.confidence = confidence
            self.headline = resolved?.displayName ?? binID.rawValue
            self.detail = resolved?.guidance ?? ""

        case let .uncertain(candidates, reason):
            self.bin = nil
            self.confidence = perception?.materials.first?.confidence ?? 0
            self.headline = "Not sure"
            self.detail = Self.explain(reason, candidates: candidates, ruleset: ruleset)
        }
    }

    private static func explain(
        _ reason: UncertaintyReason,
        candidates: [BinID],
        ruleset: SortingRuleset
    ) -> String {
        switch reason {
        case .belowConfidenceThreshold:
            "Could not identify this clearly. Please check the packaging label."
        case .noMatchingRule:
            "This item is not covered by the sorting rules yet."
        case .conflictingRules:
            let names = candidates.compactMap { ruleset.bin(for: $0)?.displayName }
            return names.isEmpty
                ? "The sorting rules disagree about this item."
                : "Could be \(names.joined(separator: " or ")). Please check the packaging label."
        case .perceptionUnavailable:
            "Item recognition is unavailable right now."
        }
    }
}
