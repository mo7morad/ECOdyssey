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
            + ruleset.hazardRules.map(\.binID)
            + ruleset.componentRules.flatMap { $0.parts.map(\.binID) }
            + ruleset.diversionBinIDs
            + ruleset.recyclingBinIDs
            + [ruleset.fallbackBinID]

        for binID in referenced {
            #expect(ruleset.bin(for: binID) != nil, "Undefined bin: \(binID.rawValue)")
        }
    }

    @Test("Hazard hints only name classes a hazard rule can act on")
    func hazardHintsMapToHazardRules() throws {
        // A hint for a class no rule handles routes nowhere, so the Vision tier would
        // detect the battery and then hand the policy something it silently drops.
        let ruleset = try RulesetLoader.loadDefault()

        for hazardClass in ruleset.hazardKeywordHints.keys {
            #expect(
                ruleset.knownHazardClasses.contains(HazardClass(rawValue: hazardClass)),
                "Unhandled hint class: \(hazardClass)"
            )
        }
    }

    @Test("Every hazard rule is reachable by the fallback tier")
    func everyHazardRuleHasKeywords() throws {
        // The other direction: a hazard rule with no hints only ever fires when the
        // language model is available, which is exactly when it is least needed.
        let ruleset = try RulesetLoader.loadDefault()

        for rule in ruleset.hazardRules {
            let hints = ruleset.hazardKeywordHints[rule.hazardClass.rawValue] ?? []
            #expect(!hints.isEmpty, "\(rule.hazardClass.rawValue) has no keyword route")
        }
    }

    @Test("A ruleset from an older schema is rejected with a reason")
    func staleSchemaVersionIsRejected() throws {
        // Adding hazard rules changed what a valid ruleset must contain. An operator
        // editing a stale copy should get a sentence, not a decoding error.
        let ruleset = try RulesetLoader.loadDefault()
        let stale = SortingRuleset(
            schemaVersion: 1,
            bins: ruleset.bins,
            fallbackBinID: ruleset.fallbackBinID,
            hazardRules: ruleset.hazardRules,
            componentRules: ruleset.componentRules,
            rules: ruleset.rules,
            visionKeywordHints: [:],
            hazardKeywordHints: [:],
            spokenLocale: ruleset.spokenLocale,
            diversionBinIDs: [],
            recyclingBinIDs: []
        )

        #expect(throws: RulesetValidationError.unsupportedSchemaVersion(found: 1, supported: 2)) {
            try stale.validate()
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
