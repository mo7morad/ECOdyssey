import Foundation
import SortingKit

/// One part of a split item, resolved for display.
public struct PresentedComponent: Equatable, Sendable, Identifiable {
    public let name: String
    public let bin: Bin?
    public let preparation: [String]
    public let condition: String?

    public var id: String { name }
}

/// A sorting decision resolved against the ruleset and ready to show a person.
///
/// The domain deliberately returns identifiers rather than display text so that bins
/// can be renamed without touching history. This is where those identifiers become
/// words on a screen.
public struct PresentedDecision: Equatable, Sendable {
    /// The bin the policy will actually assert, and `nil` when it declined to name one.
    /// This is what analytics records — a guess must never inflate the sorted count.
    ///
    /// For a split item this is the *first* component's bin. Parts are listed in the
    /// order the person should deal with them, and counting the first one keeps the
    /// one-item-one-count invariant intact. It is approximate by nature — a two-material
    /// object counted once always is — so the rulesets put the part carrying the
    /// contamination first, which keeps the diversion figure conservative.
    public let bin: Bin?
    /// The bin to put on screen and say aloud. Equal to `bin` when the policy was sure,
    /// and the ruleset's fallback when it was not.
    ///
    /// Refusing to answer is the wrong behaviour at a bin: someone is standing there
    /// holding an item and "Not sure" leaves them to guess unaided, which is how
    /// recyclables end up in landfill. The fallback bin exists in the ruleset precisely
    /// so the site can say where unrecognised waste should go, and the card marks the
    /// answer as a guess rather than passing it off as a confident reading.
    public let suggestedBin: Bin?
    public let itemName: String
    public let headline: String
    public let detail: String
    public let confidence: Double
    public let tier: PerceptionTier
    /// What to do to the item before binning it. Often the difference between an item
    /// that is really recycled and one that contaminates a load.
    public let preparation: [String]
    /// A qualification for what the camera could not settle.
    public let condition: String?
    /// Populated only for a split item; empty otherwise.
    public let components: [PresentedComponent]
    /// Drives a distinct, louder presentation — this is the one case where the answer
    /// is "not in a bin at all".
    public let isHazard: Bool

    public var isUncertain: Bool { bin == nil }
    public var isSplit: Bool { !components.isEmpty }

    /// What to say aloud, or `nil` when there is nothing useful to announce.
    ///
    /// Parts are joined with punctuation rather than connecting words, so this builds a
    /// sentence in whatever language the ruleset is written in without the code knowing
    /// which one that is.
    public var spokenPhrase: String? {
        if isHazard { return "\(itemName). \(detail)" }

        if isSplit {
            let parts = components.compactMap { component -> String? in
                guard let phrase = component.bin?.spokenPhrase else { return nil }
                return "\(component.name): \(phrase)"
            }
            return parts.isEmpty ? nil : "\(itemName). \(parts.joined(separator: ". "))."
        }

        guard let spoken = (bin ?? suggestedBin)?.spokenPhrase else { return nil }
        // Only the first preparation step is spoken. The card lists them all; reading
        // four instructions aloud outlasts the person's patience for standing there.
        guard let firstStep = preparation.first else { return "\(itemName). \(spoken)." }
        return "\(itemName). \(spoken). \(firstStep)."
    }

    public init(decision: BinDecision, perception: ItemPerception?, ruleset: SortingRuleset) {
        self.itemName = perception?.itemName ?? "Unrecognised item"
        self.tier = perception?.tier ?? .visionKeyword

        switch decision {
        case let .sorted(placement):
            let resolved = ruleset.bin(for: placement.binID)
            self.bin = resolved
            self.suggestedBin = resolved
            self.confidence = placement.confidence
            self.headline = resolved?.displayName ?? placement.binID.rawValue
            self.detail = resolved?.guidance ?? ""
            self.preparation = placement.preparation
            self.condition = placement.condition
            self.components = []
            self.isHazard = false

        case let .hazard(hazard):
            let resolved = ruleset.bin(for: hazard.binID)
            self.bin = resolved
            self.suggestedBin = resolved
            // Not a probability the way a material confidence is: the hazard rule either
            // matched or it did not, and hedging it on screen would undercut the one
            // instruction that most needs to be believed.
            self.confidence = 1
            self.headline = resolved?.displayName ?? hazard.binID.rawValue
            self.detail = hazard.instruction
            self.preparation = []
            self.condition = nil
            self.components = []
            self.isHazard = true

        case let .split(parts, _):
            let resolved = parts.map {
                PresentedComponent(
                    name: $0.name,
                    bin: ruleset.bin(for: $0.binID),
                    preparation: $0.preparation ?? [],
                    condition: $0.condition
                )
            }
            self.bin = resolved.first?.bin
            self.suggestedBin = resolved.first?.bin
            self.confidence = perception?.materials.first?.confidence ?? 0
            self.headline = "Separate first"
            self.detail = ""
            self.preparation = []
            self.condition = nil
            self.components = resolved
            self.isHazard = false

        case let .uncertain(candidates, reason):
            let fallback = ruleset.bin(for: ruleset.fallbackBinID)
            self.bin = nil
            self.suggestedBin = fallback
            self.confidence = perception?.materials.first?.confidence ?? 0
            self.headline = fallback?.displayName ?? "Not sure"
            self.detail = Self.explain(reason, candidates: candidates, ruleset: ruleset)
            self.preparation = []
            self.condition = nil
            self.components = []
            self.isHazard = false
        }
    }

    private static func explain(
        _ reason: UncertaintyReason,
        candidates: [BinID],
        ruleset: SortingRuleset
    ) -> String {
        // The headline now carries the fallback bin, so these read as the reason it is
        // only a suggestion rather than as a refusal to answer.
        switch reason {
        case .belowConfidenceThreshold:
            return "Not clearly visible — using default bin. Check packaging label if available."
        case .noMatchingRule:
            return "No matching rule yet, using default bin."
        case .conflictingRules:
            let names = candidates.compactMap { ruleset.bin(for: $0)?.displayName }
            return names.isEmpty
                ? "Sorting rules conflict for this item."
                : "Could be \(names.joined(separator: " or ")). Check packaging label."
        case .perceptionUnavailable:
            return "Item recognition is currently unavailable — using default bin."
        }
    }
}
