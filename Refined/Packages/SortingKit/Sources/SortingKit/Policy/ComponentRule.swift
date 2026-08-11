import Foundation

/// An item that is really several items, each belonging somewhere different.
///
/// A pizza box is the everyday case: the greasy base contaminates the paper stream but
/// the clean lid does not, and telling someone "residual" throws away a recyclable half.
/// The same shape covers a yoghurt pot with a foil lid and a bottle with its cap.
///
/// Matched on the perceived item name rather than on materials, because the split is a
/// property of the object, not of what it is made of — two cardboard boxes split
/// differently depending on whether one held a pizza.
public struct ComponentRule: Codable, Sendable, Equatable, Identifiable {
    public let id: RuleID
    /// Keywords matched against the item name, whole tokens only — see `KeywordMatcher`.
    public let whenItemMatches: [String]
    public let parts: [ComponentPlacement]
    /// Why this rule exists, for whoever edits the ruleset next.
    public let note: String?

    public init(
        id: RuleID,
        whenItemMatches: [String],
        parts: [ComponentPlacement],
        note: String? = nil
    ) {
        self.id = id
        self.whenItemMatches = whenItemMatches
        self.parts = parts
        self.note = note
    }

    public func matches(itemName: String) -> Bool {
        KeywordMatcher.matchesAnyKeyword(itemName, among: whenItemMatches)
    }
}

/// One part of a split item and where it goes.
///
/// Doubles as ruleset data and as decision output: the policy selects a rule and passes
/// its parts through unchanged, so a second near-identical type would only be a place
/// for the two to drift apart.
public struct ComponentPlacement: Codable, Sendable, Equatable {
    /// What to call this part on screen, in the ruleset's language.
    public let name: String
    public let binID: BinID
    /// What to do to the part before binning it.
    public let preparation: [String]?
    /// A qualification the camera cannot resolve on its own.
    public let condition: String?

    public init(
        name: String,
        binID: BinID,
        preparation: [String]? = nil,
        condition: String? = nil
    ) {
        self.name = name
        self.binID = binID
        self.preparation = preparation
        self.condition = condition
    }
}
