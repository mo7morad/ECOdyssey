import Foundation

/// Maps what was perceived onto this site's bins.
///
/// Pure and stateless: the same perception and ruleset always produce the same
/// decision. All site-specific judgement lives in the ruleset, never here — adding a
/// bin or changing where soiled cardboard goes is a JSON edit, not a code change.
public enum SortingPolicy {
    /// Confidence below which a material is not trusted enough to act on.
    ///
    /// Telling someone the wrong bin is worse than admitting uncertainty, so this sits
    /// well above noise. Vision's generic classifier routinely emits sub-0.2 matches
    /// for objects it has not really recognised. Calibrate against the soak test.
    public static let defaultMinConfidence: Double = 0.25

    public static func decide(
        _ perception: ItemPerception,
        using ruleset: SortingRuleset,
        minConfidence: Double = defaultMinConfidence
    ) -> BinDecision {
        let trustedMaterials = perception.materials.filter { $0.confidence >= minConfidence }

        guard !trustedMaterials.isEmpty else {
            return .uncertain(candidates: [], reason: .belowConfidenceThreshold)
        }

        // Materials arrive ranked, so the first one that any rule applies to wins.
        // Scanning every material for one bin before considering the next would let a
        // barely-visible banana outvote an obvious plastic bottle.
        for material in trustedMaterials {
            let applicable = ruleset.rules.filter {
                $0.materials.contains(material.materialID) && satisfies($0.requires, perception)
            }
            guard let topPriority = applicable.map(\.priority).max() else { continue }

            let winners = applicable.filter { $0.priority == topPriority }
            let targetBins = Set(winners.map(\.binID))

            guard targetBins.count == 1, let winner = winners.first else {
                // Equal-priority rules disagree on the bin. That is a ruleset conflict,
                // and guessing would hide it — surface the options instead.
                return .uncertain(
                    candidates: winners.map(\.binID).sorted { $0.rawValue < $1.rawValue },
                    reason: .conflictingRules
                )
            }

            return .sorted(binID: winner.binID, matchedRule: winner.id, confidence: material.confidence)
        }

        return .uncertain(candidates: [], reason: .noMatchingRule)
    }

    private static func satisfies(_ requirements: RuleRequirements?, _ perception: ItemPerception) -> Bool {
        guard let requirements else { return true }

        if let requiredFoodSoiled = requirements.foodSoiled, requiredFoodSoiled != perception.isFoodSoiled {
            return false
        }
        if let requiredComposite = requirements.isComposite, requiredComposite != perception.isComposite {
            return false
        }
        return true
    }
}
