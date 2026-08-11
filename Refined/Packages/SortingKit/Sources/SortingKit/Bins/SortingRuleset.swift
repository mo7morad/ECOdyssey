import Foundation

public struct SortingRuleset: Codable, Sendable, Equatable {
    /// Bumped when the shape changes in a way an older ruleset cannot satisfy.
    /// `validate()` rejects anything else, so an operator editing a stale file gets a
    /// sentence naming the problem instead of a decoding error halfway down the JSON.
    public static let supportedSchemaVersion = 2

    public let schemaVersion: Int
    public let bins: [Bin]
    public let fallbackBinID: BinID
    /// Checked before `rules` and winning outright — see `SortingPolicy.decide`.
    public let hazardRules: [HazardRule]
    /// Items that are really several items. Checked before `rules`.
    public let componentRules: [ComponentRule]
    public let rules: [MaterialRule]
    public let visionKeywordHints: [String: [String]]
    /// Keyword route to a hazard class for tiers that cannot reason about one.
    ///
    /// Without this the Vision fallback would drop hazard interception entirely, so a
    /// device with Apple Intelligence switched off would cheerfully file a battery as
    /// recyclable metal. Safety cannot be the tier that degrades first.
    public let hazardKeywordHints: [String: [String]]
    /// BCP-47 tag for the spoken output, so a site's bin names and the voice reading
    /// them stay in the same language. The bin names are ruleset data, so this belongs
    /// with them rather than in the app's own settings.
    public let spokenLocale: String
    /// Bins that count as diverted from landfill. Stated rather than inferred, because
    /// which streams count as diversion is a reporting decision an operator may be
    /// audited on.
    public let diversionBinIDs: [BinID]
    /// Bins that count specifically as recycling — a subset of diversion, and a
    /// different number from it.
    public let recyclingBinIDs: [BinID]

    public init(
        schemaVersion: Int,
        bins: [Bin],
        fallbackBinID: BinID,
        hazardRules: [HazardRule],
        componentRules: [ComponentRule],
        rules: [MaterialRule],
        visionKeywordHints: [String: [String]],
        hazardKeywordHints: [String: [String]],
        spokenLocale: String,
        diversionBinIDs: [BinID],
        recyclingBinIDs: [BinID]
    ) {
        self.schemaVersion = schemaVersion
        self.bins = bins
        self.fallbackBinID = fallbackBinID
        self.hazardRules = hazardRules
        self.componentRules = componentRules
        self.rules = rules
        self.visionKeywordHints = visionKeywordHints
        self.hazardKeywordHints = hazardKeywordHints
        self.spokenLocale = spokenLocale
        self.diversionBinIDs = diversionBinIDs
        self.recyclingBinIDs = recyclingBinIDs
    }

    public func bin(for id: BinID) -> Bin? {
        bins.first { $0.id == id }
    }

    /// Every material any rule can act on. Perception tiers use this as their
    /// vocabulary, so anything outside it is treated as unrecognised.
    public var knownMaterials: Set<MaterialID> {
        Set(rules.compactMap(\.materials).flatMap { $0 })
    }

    /// Every hazard class the ruleset can act on. Used the same way `knownMaterials`
    /// is: a class the model invents that no rule handles is discarded rather than
    /// treated as a hazard nobody has instructions for.
    public var knownHazardClasses: Set<HazardClass> {
        Set(hazardRules.map(\.hazardClass))
    }

    public func validate() throws {
        guard schemaVersion == Self.supportedSchemaVersion else {
            throw RulesetValidationError.unsupportedSchemaVersion(
                found: schemaVersion,
                supported: Self.supportedSchemaVersion
            )
        }

        if bin(for: fallbackBinID) == nil {
            throw RulesetValidationError.unresolvedFallbackBinID(fallbackBinID.rawValue)
        }

        for rule in rules {
            if bin(for: rule.binID) == nil {
                throw RulesetValidationError.unresolvedBinID(rule.binID.rawValue)
            }
            // An empty list would read like "no materials" but behave like "any", and
            // the difference is a rule that silently swallows everything.
            if let materials = rule.materials, materials.isEmpty {
                throw RulesetValidationError.emptyMaterialList(rule.id.rawValue)
            }
        }

        for rule in hazardRules where bin(for: rule.binID) == nil {
            throw RulesetValidationError.unresolvedBinID(rule.binID.rawValue)
        }

        for rule in componentRules {
            for part in rule.parts where bin(for: part.binID) == nil {
                throw RulesetValidationError.unresolvedBinID(part.binID.rawValue)
            }
            if rule.parts.count < 2 {
                throw RulesetValidationError.componentRuleNeedsTwoParts(rule.id.rawValue)
            }
        }

        for binID in diversionBinIDs + recyclingBinIDs where bin(for: binID) == nil {
            throw RulesetValidationError.unresolvedBinID(binID.rawValue)
        }
    }
}

public enum RulesetValidationError: Error, Equatable {
    case unresolvedBinID(String)
    case unresolvedFallbackBinID(String)
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case emptyMaterialList(String)
    case componentRuleNeedsTwoParts(String)
}
