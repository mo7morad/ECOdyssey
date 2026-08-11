import Foundation

/// Where a hazardous item goes, and what the person has to be told.
///
/// Hazard rules are checked before material rules and win outright. A lithium battery
/// is a battery whether or not it is also metal, and the cost of getting it wrong is
/// not a contaminated load — it is a fire in the collection truck.
///
/// `instruction` is mandatory rather than optional because a bin name alone is not
/// enough advice here: the person is holding something that needs handling, and
/// "B3" on its own does not tell them what to do with it.
public struct HazardRule: Codable, Sendable, Equatable, Identifiable {
    public let id: RuleID
    public let hazardClass: HazardClass
    /// The stream this hazard goes to. A site without a dedicated hazardous bin can
    /// point this at any bin it does have and say so in `instruction`.
    public let binID: BinID
    public let instruction: String
    /// Why this rule exists, for whoever edits the ruleset next.
    public let note: String?

    public init(
        id: RuleID,
        hazardClass: HazardClass,
        binID: BinID,
        instruction: String,
        note: String? = nil
    ) {
        self.id = id
        self.hazardClass = hazardClass
        self.binID = binID
        self.instruction = instruction
        self.note = note
    }
}
