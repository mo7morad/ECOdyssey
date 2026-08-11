import Foundation
import Testing
@testable import SortingKit

@Suite("Sorting policy")
struct SortingPolicyTests {
    private func perception(
        itemName: String = "item",
        materials: [MaterialObservation],
        isFoodSoiled: Bool = false,
        isComposite: Bool = false,
        hazardClass: HazardClass? = nil,
        isEmpty: Bool? = nil
    ) -> ItemPerception {
        ItemPerception(
            itemName: itemName,
            materials: materials,
            isFoodSoiled: isFoodSoiled,
            isComposite: isComposite,
            hazardClass: hazardClass,
            isEmpty: isEmpty,
            printedDisposalHint: nil,
            tier: .foundationModel
        )
    }

    /// Asserting on the whole `Placement` would make every test fail the moment someone
    /// edits a preparation string, which is ruleset content rather than policy.
    private func placement(_ decision: BinDecision) -> Placement? {
        guard case let .sorted(placement) = decision else { return nil }
        return placement
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

        #expect(placement(decision)?.binID == "anorganik")
        #expect(placement(decision)?.matchedRule == "clean_pet")
        #expect(placement(decision)?.confidence == 0.92)
    }

    @Test("Nothing seen confidently enough yields uncertain")
    func lowConfidenceYieldsUncertain() throws {
        let ruleset = try RulesetLoader.loadDefault()
        let decision = SortingPolicy.decide(
            perception(materials: [MaterialObservation(materialID: "pet_plastic", confidence: 0.005)]),
            using: ruleset
        )

        #expect(decision == .uncertain(candidates: [], reason: .belowConfidenceThreshold))
    }

    @Test("A weak but real reading is acted on rather than discarded")
    func modestConfidenceStillSorts() throws {
        // Vision's general classifier scores a correctly identified drink can at around
        // 0.1. The threshold used to sit at 0.25 and rejected the true answer far more
        // often than a false one, so the station said "Not sure" to almost everything.
        let ruleset = try RulesetLoader.loadDefault()
        let decision = SortingPolicy.decide(
            perception(materials: [MaterialObservation(materialID: "aluminium", confidence: 0.1)]),
            using: ruleset
        )

        #expect(placement(decision)?.binID == "anorganik")
        #expect(placement(decision)?.matchedRule == "clean_metal")
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
        (true, BinID("residu"), RuleID("soiled_cardboard")),
        (false, BinID("anorganik"), RuleID("clean_cardboard")),
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

        #expect(placement(decision)?.binID == expectedBin)
        #expect(placement(decision)?.matchedRule == expectedRule)
    }

    // MARK: - Bonded materials

    @Test("A bonded item overrides whatever material was named")
    func bondedItemOverridesItsPrimaryMaterial() throws {
        // Regression, and the reason `cmp_bonded_override` omits its materials list.
        // A PE-lined coffee cup is honestly reported as paper that happens to be bonded.
        // Before the fix, `isComposite` was only consulted by a rule whose materials list
        // was ["composite"], which "paper" is not — so the cup matched `clean_paper` and
        // was sent to recycling. Lined cups are the most common contaminant there is.
        let ruleset = try RulesetLoader.loadDefault()
        let decision = SortingPolicy.decide(
            perception(
                materials: [MaterialObservation(materialID: "paper", confidence: 0.88)],
                isFoodSoiled: false,
                isComposite: true
            ),
            using: ruleset
        )

        #expect(placement(decision)?.binID == "residu")
        #expect(placement(decision)?.matchedRule == "cmp_bonded_override")
    }

    @Test("An unbonded paper item is still recyclable")
    func plainPaperIsUnaffectedByTheOverride() throws {
        // Pins the other half: the override must not swallow ordinary paper.
        let ruleset = try RulesetLoader.loadDefault()
        let decision = SortingPolicy.decide(
            perception(materials: [MaterialObservation(materialID: "paper", confidence: 0.88)]),
            using: ruleset
        )

        #expect(placement(decision)?.binID == "anorganik")
        #expect(placement(decision)?.matchedRule == "clean_paper")
    }

    // MARK: - Hazards

    @Test("A hazard outranks the material rule that would otherwise have matched")
    func hazardPreemptsMaterialRules() throws {
        // A battery really is metal, and `clean_metal` would file it as recyclable.
        // Getting this wrong puts a lithium cell into a compactor.
        let ruleset = try RulesetLoader.loadDefault()
        let decision = SortingPolicy.decide(
            perception(
                materials: [MaterialObservation(materialID: "steel", confidence: 0.95)],
                hazardClass: "battery"
            ),
            using: ruleset
        )

        guard case let .hazard(hazard) = decision else {
            Issue.record("Expected a hazard decision, got \(decision)")
            return
        }
        #expect(hazard.binID == "b3")
        #expect(hazard.hazardClass == "battery")
        #expect(!hazard.instruction.isEmpty)
    }

    @Test("Every hazard class the ruleset knows routes somewhere with an instruction")
    func everyHazardClassIsActionable() throws {
        let ruleset = try RulesetLoader.loadDefault()

        for hazardClass in ruleset.knownHazardClasses {
            let decision = SortingPolicy.decide(
                perception(materials: [], hazardClass: hazardClass),
                using: ruleset
            )
            guard case let .hazard(hazard) = decision else {
                Issue.record("\(hazardClass.rawValue) produced \(decision) instead of a hazard")
                continue
            }
            #expect(!hazard.instruction.isEmpty, "\(hazardClass.rawValue) has no instruction")
        }
    }

    @Test("A hazard class no rule handles falls through to the material rules")
    func unknownHazardClassIsIgnored() throws {
        // The perception tiers filter against `knownHazardClasses`, but a ruleset edit
        // can still orphan one. Falling through beats refusing to answer.
        let ruleset = try RulesetLoader.loadDefault()
        let decision = SortingPolicy.decide(
            perception(
                materials: [MaterialObservation(materialID: "paper", confidence: 0.9)],
                hazardClass: "antimatter"
            ),
            using: ruleset
        )

        #expect(placement(decision)?.binID == "anorganik")
    }

    // MARK: - Splits

    @Test("A pizza box comes apart into two bins rather than collapsing to one")
    func pizzaBoxSplitsIntoComponents() throws {
        // Sorting the whole box as residual is defensible and still throws away the
        // clean half, which is the entire point of the component rules.
        let ruleset = try RulesetLoader.loadDefault()
        let decision = SortingPolicy.decide(
            perception(
                itemName: "pizza box",
                materials: [MaterialObservation(materialID: "cardboard", confidence: 0.9)],
                isFoodSoiled: true
            ),
            using: ruleset
        )

        guard case let .split(parts, matchedRule) = decision else {
            Issue.record("Expected a split decision, got \(decision)")
            return
        }
        #expect(matchedRule == "cp_pizza_box")
        #expect(Set(parts.map(\.binID)) == ["anorganik", "residu"])
    }

    @Test("A hazard still wins over a component rule")
    func hazardOutranksSplit() throws {
        let ruleset = try RulesetLoader.loadDefault()
        let decision = SortingPolicy.decide(
            perception(
                itemName: "pizza box",
                materials: [MaterialObservation(materialID: "cardboard", confidence: 0.9)],
                hazardClass: "battery"
            ),
            using: ruleset
        )

        guard case .hazard = decision else {
            Issue.record("Expected hazard to outrank the split, got \(decision)")
            return
        }
    }

    @Test("An item name that matches no component rule sorts normally")
    func unsplittableItemUsesMaterialRules() throws {
        let ruleset = try RulesetLoader.loadDefault()
        let decision = SortingPolicy.decide(
            perception(
                itemName: "cardboard box",
                materials: [MaterialObservation(materialID: "cardboard", confidence: 0.9)]
            ),
            using: ruleset
        )

        #expect(placement(decision)?.matchedRule == "clean_cardboard")
    }

    // MARK: - Preparation and conditions

    @Test("A rule's preparation steps reach the decision")
    func preparationStepsAreCarried() throws {
        // The bin alone was never the whole answer — rinsing is what decides whether
        // the item is actually recycled.
        let ruleset = try RulesetLoader.loadDefault()
        let decision = SortingPolicy.decide(
            perception(materials: [MaterialObservation(materialID: "pet_plastic", confidence: 0.9)]),
            using: ruleset
        )

        #expect(placement(decision)?.preparation.isEmpty == false)
    }

    @Test("An unseen interior fails a rule that demands an emptied container")
    func unknownEmptinessDoesNotSatisfyAnEmptyRequirement() {
        // "Could not tell" must not be read as "empty" — that would invent a fact.
        let requirements = RuleRequirements(isEmpty: true)
        let ruleset = SortingRuleset(
            schemaVersion: SortingRuleset.supportedSchemaVersion,
            bins: [Bin(id: "only", displayName: "Only", colorHex: "#000000", spokenPhrase: "only", guidance: "")],
            fallbackBinID: "only",
            hazardRules: [],
            componentRules: [],
            rules: [MaterialRule(id: "needs_empty", materials: ["mystery"], binID: "only", priority: 100, requires: requirements)],
            visionKeywordHints: [:],
            hazardKeywordHints: [:],
            spokenLocale: "en-US",
            diversionBinIDs: [],
            recyclingBinIDs: []
        )

        let decision = SortingPolicy.decide(
            perception(materials: [MaterialObservation(materialID: "mystery", confidence: 0.9)], isEmpty: nil),
            using: ruleset
        )

        #expect(decision == .uncertain(candidates: [], reason: .noMatchingRule))
    }

    @Test("Equal-priority rules pointing at different bins surface as a conflict")
    func conflictingRulesYieldCandidates() {
        // Guessing between them would hide a ruleset mistake from whoever wrote it.
        let ruleset = SortingRuleset(
            schemaVersion: SortingRuleset.supportedSchemaVersion,
            bins: [
                Bin(id: "left", displayName: "Left", colorHex: "#000000", spokenPhrase: "Left", guidance: ""),
                Bin(id: "right", displayName: "Right", colorHex: "#FFFFFF", spokenPhrase: "Right", guidance: ""),
            ],
            fallbackBinID: "left",
            hazardRules: [],
            componentRules: [],
            rules: [
                MaterialRule(id: "a", materials: ["mystery"], binID: "left", priority: 100),
                MaterialRule(id: "b", materials: ["mystery"], binID: "right", priority: 100),
            ],
            visionKeywordHints: [:],
            hazardKeywordHints: [:],
            spokenLocale: "en-US",
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
