import Foundation

/// What a perception tier saw — facts about the item, never a bin.
///
/// Which bin an item belongs in is site policy, not perception: food-soiled cardboard
/// is residual here and organic elsewhere. `SortingPolicy` makes that call from these
/// facts, so bins can be reconfigured without touching prompts or models.
public struct ItemPerception: Sendable, Equatable {
    public let itemName: String
    /// Ranked most confident first.
    public let materials: [MaterialObservation]
    public let isFoodSoiled: Bool
    /// Multiple bonded materials that cannot be separated by hand, such as a paper
    /// cup with a plastic liner.
    public let isComposite: Bool
    /// Disposal wording read off the packaging, when the tier can read text.
    public let printedDisposalHint: String?
    public let tier: PerceptionTier

    public init(
        itemName: String,
        materials: [MaterialObservation],
        isFoodSoiled: Bool,
        isComposite: Bool,
        printedDisposalHint: String?,
        tier: PerceptionTier
    ) {
        self.itemName = itemName
        self.materials = materials
        self.isFoodSoiled = isFoodSoiled
        self.isComposite = isComposite
        self.printedDisposalHint = printedDisposalHint
        self.tier = tier
    }
}
