import Foundation
import Testing
@testable import SortingKit

@Suite("Sorting policy")
struct SortingPolicyTests {
    private func perception(
        materials: [MaterialObservation],
        isFoodSoiled: Bool = false,
        isComposite: Bool = false
    ) -> ItemPerception {
        ItemPerception(
            itemName: "item",
            materials: materials,
            isFoodSoiled: isFoodSoiled,
            isComposite: isComposite,
            printedDisposalHint: nil,
            tier: .foundationModel
        )
    }

    @Test("Confident material outranks a barely-visible one")
    func highestConfidenceMaterialWins() throws {
        // Regression: the original matcher scanned all twenty labels for organic before
        // considering plastic, so a rank-19 banana beat a rank-1 water bottle.
        let ruleset = try RulesetLoader.loadDefault()
        let decision = SortingPolicy.decide(
            perception(materials: [
                MaterialObservation(materialID: "pet_plastic", confidence: 0.92),
                MaterialObservation(materialID: "food_waste", confidence: 0.30),
            ]),
            using: ruleset
        )

        #expect(decision == .sorted(binID: "recyclable", matchedRule: "clean_plastic", confidence: 0.92))
    }

    @Test("Nothing seen confidently enough yields uncertain")
    func lowConfidenceYieldsUncertain() throws {
        let ruleset = try RulesetLoader.loadDefault()
        let decision = SortingPolicy.decide(
            perception(materials: [MaterialObservation(materialID: "pet_plastic", confidence: 0.05)]),
            using: ruleset
        )

        #expect(decision == .uncertain(candidates: [], reason: .belowConfidenceThreshold))
    }

    @Test("Material no rule covers yields uncertain rather than the fallback bin")
    func unknownMaterialYieldsUncertain() throws {
        let ruleset = try RulesetLoader.loadDefault()
        let decision = SortingPolicy.decide(
            perception(materials: [MaterialObservation(materialID: "moon_rock", confidence: 0.9)]),
            using: ruleset
        )

        #expect(decision == .uncertain(candidates: [], reason: .noMatchingRule))
    }

    @Test("Soiling redirects an otherwise recyclable material", arguments: [
        (true, BinID("residual"), RuleID("soiled_cardboard")),
        (false, BinID("recyclable"), RuleID("clean_cardboard")),
    ])
    func soilingChangesTheBin(isFoodSoiled: Bool, expectedBin: BinID, expectedRule: RuleID) throws {
        let ruleset = try RulesetLoader.loadDefault()
        let decision = SortingPolicy.decide(
            perception(
                materials: [MaterialObservation(materialID: "cardboard", confidence: 0.85)],
                isFoodSoiled: isFoodSoiled
            ),
            using: ruleset
        )

        #expect(decision == .sorted(binID: expectedBin, matchedRule: expectedRule, confidence: 0.85))
    }

    @Test("Equal-priority rules pointing at different bins surface as a conflict")
    func conflictingRulesYieldCandidates() {
        // Guessing between them would hide a ruleset mistake from whoever wrote it.
        let ruleset = SortingRuleset(
            schemaVersion: 1,
            bins: [
                Bin(id: "left", displayName: "Left", colorHex: "#000000", spokenPhrase: "Left", guidance: ""),
                Bin(id: "right", displayName: "Right", colorHex: "#FFFFFF", spokenPhrase: "Right", guidance: ""),
            ],
            fallbackBinID: "left",
            rules: [
                MaterialRule(id: "a", materials: ["mystery"], binID: "left", priority: 100),
                MaterialRule(id: "b", materials: ["mystery"], binID: "right", priority: 100),
            ],
            visionKeywordHints: [:],
            diversionBinIDs: [],
            recyclingBinIDs: []
        )

        let decision = SortingPolicy.decide(
            perception(materials: [MaterialObservation(materialID: "mystery", confidence: 0.9)]),
            using: ruleset
        )

        #expect(decision == .uncertain(candidates: ["left", "right"], reason: .conflictingRules))
    }
}
