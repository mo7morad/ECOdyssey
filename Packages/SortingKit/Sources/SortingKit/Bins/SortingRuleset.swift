import Foundation

public struct SortingRuleset: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let bins: [Bin]
    public let fallbackBinID: BinID
    public let rules: [MaterialRule]
    public let visionKeywordHints: [String: [String]]
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
        rules: [MaterialRule],
        visionKeywordHints: [String: [String]],
        diversionBinIDs: [BinID],
        recyclingBinIDs: [BinID]
    ) {
        self.schemaVersion = schemaVersion
        self.bins = bins
        self.fallbackBinID = fallbackBinID
        self.rules = rules
        self.visionKeywordHints = visionKeywordHints
        self.diversionBinIDs = diversionBinIDs
        self.recyclingBinIDs = recyclingBinIDs
    }
    
    public func bin(for id: BinID) -> Bin? {
        bins.first { $0.id == id }
    }

    /// Every material any rule can act on. Perception tiers use this as their
    /// vocabulary, so anything outside it is treated as unrecognised.
    public var knownMaterials: Set<MaterialID> {
        Set(rules.flatMap(\.materials))
    }
    
    public func validate() throws {
        if bin(for: fallbackBinID) == nil {
            throw RulesetValidationError.unresolvedFallbackBinID(fallbackBinID.rawValue)
        }
        
        for rule in rules {
            if bin(for: rule.binID) == nil {
                throw RulesetValidationError.unresolvedBinID(rule.binID.rawValue)
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
}
