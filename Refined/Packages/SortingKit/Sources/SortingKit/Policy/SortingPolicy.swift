import Foundation

/// Maps what was perceived onto this site's bins.
///
/// Pure and stateless: the same perception and ruleset always produce the same
/// decision. All site-specific judgement lives in the ruleset, never here — adding a
/// bin or changing where soiled cardboard goes is a JSON edit, not a code change.
public enum SortingPolicy {
    /// Confidence below which a material is not trusted enough to act on.
    ///
    /// This is a noise floor, not a certainty bar. It was set at 0.25 to keep the system
    /// from asserting a bin it had not really recognised, but that reads Vision's scores
    /// as probabilities when they are not: its general classifier scores a correctly
    /// identified drink can at roughly 0.1, so the threshold rejected the true answer
    /// far more often than a false one and the station said "Not sure" to almost
    /// everything. Confidence still ranks materials against each other, and a weak
    /// reading now surfaces as a hedged suggestion rather than a refusal — see
    /// `PresentedDecision`. Calibrate against the soak test.
    public static let defaultMinConfidence: Double = 0.05

    /// Three passes, in this order, and the order is the policy:
    ///
    /// 1. **Hazards win outright.** A battery is still metal, and a material rule would
    ///    happily file it as recyclable. Getting this wrong starts a fire in a truck,
    ///    so it is settled before anything else gets a say.
    /// 2. **Splits beat a single bin.** A greasy pizza box sorts correctly as residual,
    ///    but answering "residual" throws away the clean lid. When the ruleset knows an
    ///    item comes apart, the better answer is both halves.
    /// 3. **Materials**, as before.
    public static func decide(
        _ perception: ItemPerception,
        using ruleset: SortingRuleset,
        minConfidence: Double = defaultMinConfidence
    ) -> BinDecision {
        if let hazard = hazardDecision(for: perception, using: ruleset) { return hazard }
        if let split = splitDecision(for: perception, using: ruleset) { return split }
        return materialDecision(for: perception, using: ruleset, minConfidence: minConfidence)
    }

    private static func hazardDecision(
        for perception: ItemPerception,
        using ruleset: SortingRuleset
    ) -> BinDecision? {
        guard let hazardClass = perception.hazardClass,
              let rule = ruleset.hazardRules.first(where: { $0.hazardClass == hazardClass })
        else { return nil }

        return .hazard(HazardPlacement(
            hazardClass: hazardClass,
            binID: rule.binID,
            matchedRule: rule.id,
            instruction: rule.instruction
        ))
    }

    private static func splitDecision(
        for perception: ItemPerception,
        using ruleset: SortingRuleset
    ) -> BinDecision? {
        guard let rule = ruleset.componentRules.first(where: { $0.matches(itemName: perception.itemName) })
        else { return nil }

        return .split(parts: rule.parts, matchedRule: rule.id)
    }

    private static func materialDecision(
        for perception: ItemPerception,
        using ruleset: SortingRuleset,
        minConfidence: Double
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
                $0.covers(material.materialID) && satisfies($0.requires, perception)
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

            return .sorted(Placement(
                binID: winner.binID,
                matchedRule: winner.id,
                confidence: material.confidence,
                preparation: winner.preparation ?? [],
                condition: winner.condition
            ))
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
        // An unseen interior is not an empty one: comparing against the optional makes
        // "could not tell" fail a rule that demands an emptied container.
        if let requiredEmpty = requirements.isEmpty, requiredEmpty != perception.isEmpty {
            return false
        }
        return true
    }
}
