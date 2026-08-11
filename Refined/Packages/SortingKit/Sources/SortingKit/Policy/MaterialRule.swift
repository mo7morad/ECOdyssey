import Foundation

/// One site-configurable sorting rule: "these materials, in this condition, go here".
public struct MaterialRule: Codable, Sendable, Equatable, Identifiable {
    public let id: RuleID
    /// Materials this rule covers. Omitted means *any* material, which is how a
    /// property-driven rule is written: a lined cup is disqualified by being bonded,
    /// whatever the model decided its primary material was. Never write `[]` — an empty
    /// list would be a rule that can never fire, and `validate()` rejects it.
    public let materials: [MaterialID]?
    public let binID: BinID
    /// Highest wins among rules matching the same material. Equal priorities pointing
    /// at different bins are treated as a ruleset conflict rather than a coin flip.
    public let priority: Int
    /// Extra conditions on the item's state. `nil` means the rule always applies.
    public let requires: RuleRequirements?
    /// What to do to the item before binning it — "empty and rinse", "cap back on".
    /// In practice this is what decides whether an item is really recycled, so a bin
    /// name on its own was never the whole answer.
    public let preparation: [String]?
    /// A qualification for what the camera cannot settle: whether a container is truly
    /// empty, whether clear plastic is actually glass. Shown alongside the bin so the
    /// station can stay decisive instead of falling back to "not sure".
    public let condition: String?
    /// Why this rule exists, for whoever edits the ruleset next.
    public let note: String?

    public init(
        id: RuleID,
        materials: [MaterialID]?,
        binID: BinID,
        priority: Int,
        requires: RuleRequirements? = nil,
        preparation: [String]? = nil,
        condition: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.materials = materials
        self.binID = binID
        self.priority = priority
        self.requires = requires
        self.preparation = preparation
        self.condition = condition
        self.note = note
    }

    public func covers(_ materialID: MaterialID) -> Bool {
        guard let materials else { return true }
        return materials.contains(materialID)
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
    /// Whether the container has been emptied. Unknown counts as unmet, so a rule
    /// requiring an empty bottle will not fire on an item nobody could see inside.
    public let isEmpty: Bool?

    public init(foodSoiled: Bool? = nil, isComposite: Bool? = nil, isEmpty: Bool? = nil) {
        self.foodSoiled = foodSoiled
        self.isComposite = isComposite
        self.isEmpty = isEmpty
    }
}
