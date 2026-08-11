import Foundation

/// Why the policy declined to name a bin.
public enum UncertaintyReason: String, Sendable, Equatable, Codable {
    /// Nothing was seen confidently enough to act on.
    case belowConfidenceThreshold
    /// Materials were recognised, but no rule covers them.
    case noMatchingRule
    /// Equal-priority rules point at different bins — a ruleset conflict.
    case conflictingRules
    /// The perception tier could not run at all.
    case perceptionUnavailable
}

/// Where the policy says an item goes, or why it will not say.
///
/// Uncertainty is a first-class outcome, not an error. It is recorded and reported:
/// how often the system punts is one of the more useful things an operator can know
/// about their waste stream.
public enum BinDecision: Sendable, Equatable {
    case sorted(Placement)
    /// The item must not go in an ordinary bin at all.
    case hazard(HazardPlacement)
    /// One object, more than one destination.
    case split(parts: [ComponentPlacement], matchedRule: RuleID)
    /// `candidates` is populated only when the ambiguity is between known bins.
    case uncertain(candidates: [BinID], reason: UncertaintyReason)
}

/// An ordinary sorting outcome and everything needed to act on it.
///
/// Grouped into a struct rather than spread across the enum case because the bin was
/// never the whole answer — the preparation step is often what decides whether the
/// item is actually recycled.
public struct Placement: Sendable, Equatable {
    public let binID: BinID
    public let matchedRule: RuleID
    public let confidence: Double
    public let preparation: [String]
    public let condition: String?

    public init(
        binID: BinID,
        matchedRule: RuleID,
        confidence: Double,
        preparation: [String] = [],
        condition: String? = nil
    ) {
        self.binID = binID
        self.matchedRule = matchedRule
        self.confidence = confidence
        self.preparation = preparation
        self.condition = condition
    }
}

/// A hazardous outcome. Carries an instruction because the bin name alone is not
/// enough advice for something that needs handling.
public struct HazardPlacement: Sendable, Equatable {
    public let hazardClass: HazardClass
    public let binID: BinID
    public let matchedRule: RuleID
    public let instruction: String

    public init(hazardClass: HazardClass, binID: BinID, matchedRule: RuleID, instruction: String) {
        self.hazardClass = hazardClass
        self.binID = binID
        self.matchedRule = matchedRule
        self.instruction = instruction
    }
}
