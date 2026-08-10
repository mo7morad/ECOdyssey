import Foundation
import Testing
@testable import SortingKit

/// The shipped ruleset is configuration, so a typo in it is a runtime failure on a wall
/// somewhere. These tests move that failure to build time.
@Suite("Default ruleset")
struct RulesetDecodingTests {
    @Test("Shipped ruleset decodes and passes validation")
    func shippedRulesetIsValid() throws {
        let ruleset = try RulesetLoader.loadDefault()

        #expect(!ruleset.bins.isEmpty)
        #expect(!ruleset.rules.isEmpty)
        try ruleset.validate()
    }

    @Test("Every bin referenced anywhere in the ruleset is defined")
    func everyReferencedBinIsDefined() throws {
        let ruleset = try RulesetLoader.loadDefault()
        let referenced = ruleset.rules.map(\.binID)
            + ruleset.diversionBinIDs
            + ruleset.recyclingBinIDs
            + [ruleset.fallbackBinID]

        for binID in referenced {
            #expect(ruleset.bin(for: binID) != nil, "Undefined bin: \(binID.rawValue)")
        }
    }

    @Test("Keyword hints only name materials that a rule can act on")
    func keywordHintsMapToRuleMaterials() throws {
        // A hint for a material no rule covers can never change a decision, so it is
        // either a typo or dead configuration.
        let ruleset = try RulesetLoader.loadDefault()
        let actionable = ruleset.knownMaterials

        for material in ruleset.visionKeywordHints.keys {
            #expect(actionable.contains(MaterialID(rawValue: material)), "Unused hint material: \(material)")
        }
    }

    @Test("Bin identifiers carry no display text")
    func binIdentifiersAreStable() throws {
        // Identity and presentation were the same string in the original app, so
        // renaming a bin reclassified every historical record.
        let ruleset = try RulesetLoader.loadDefault()

        for bin in ruleset.bins {
            #expect(bin.id.rawValue.allSatisfy { $0.isLowercase || $0 == "_" || $0.isNumber })
        }
    }

    @Test("Malformed JSON is rejected rather than partially loaded")
    func malformedJSONThrows() {
        #expect(throws: DecodingError.self) {
            _ = try RulesetLoader.load(from: Data("not a ruleset".utf8))
        }
    }
}
