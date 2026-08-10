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
    case sorted(binID: BinID, matchedRule: RuleID, confidence: Double)
    /// `candidates` is populated only when the ambiguity is between known bins.
    case uncertain(candidates: [BinID], reason: UncertaintyReason)
}
