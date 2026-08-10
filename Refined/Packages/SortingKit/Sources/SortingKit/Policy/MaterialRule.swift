import Foundation

/// One site-configurable sorting rule: "these materials, in this condition, go here".
public struct MaterialRule: Codable, Sendable, Equatable, Identifiable {
    public let id: RuleID
    public let materials: [MaterialID]
    public let binID: BinID
    /// Highest wins among rules matching the same material. Equal priorities pointing
    /// at different bins are treated as a ruleset conflict rather than a coin flip.
    public let priority: Int
    /// Extra conditions on the item's state. `nil` means the rule always applies.
    public let requires: RuleRequirements?
    /// Why this rule exists, for whoever edits the ruleset next.
    public let note: String?

    public init(
        id: RuleID,
        materials: [MaterialID],
        binID: BinID,
        priority: Int,
        requires: RuleRequirements? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.materials = materials
        self.binID = binID
        self.priority = priority
        self.requires = requires
        self.note = note
    }
}

/// Conditions a rule places on the item's state.
///
/// Each field is tri-state: `nil` means "don't care", otherwise the item must match.
/// A rule for clean cardboard sets `foodSoiled: false`; one for greasy cardboard sets
/// `foodSoiled: true`.
public struct RuleRequirements: Codable, Sendable, Equatable {
    public let foodSoiled: Bool?
    public let isComposite: Bool?

    public init(foodSoiled: Bool? = nil, isComposite: Bool? = nil) {
        self.foodSoiled = foodSoiled
        self.isComposite = isComposite
    }
}
