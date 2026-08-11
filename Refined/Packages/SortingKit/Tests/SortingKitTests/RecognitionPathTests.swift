import Foundation
import Testing
@testable import SortingKit

/// Walks a realistic Vision result all the way to a bin.
///
/// The unit suites cover the matcher and the policy separately, and both passed while
/// the station in front of a real bottle still answered "Not sure" — the failure lived
/// in the join between them, in a hint table that never matched Vision's actual labels
/// and a confidence bar set above Vision's actual scores. These cases are that join.
///
/// Confidences here are deliberately small, and that is the regression they guard.
/// `VNClassifyImageRequest` is a general taxonomy classifier over roughly a thousand
/// labels, not a waste classifier, and it scores a plainly visible item in the low
/// tenths. The label floor used to sit at 0.15 and the policy bar at 0.25, so the drink
/// can below — scored at 0.18, as a real one is — cleared neither and the whole frame
/// came back unrecognised. Lowering these numbers without re-checking these cases puts
/// the station back to answering "Not sure" to almost everything.
@Suite("Recognition path")
struct RecognitionPathTests {
    /// Mirrors what `VisionKeywordPerception` builds, hazard lookup included. The
    /// fallback tier is the one running on a device with Apple Intelligence switched
    /// off, so its hazard interception has to be exercised, not assumed.
    private func bin(for labels: [(identifier: String, confidence: Double)]) throws -> BinID? {
        let ruleset = try RulesetLoader.loadDefault()
        let perception = ItemPerception(
            itemName: labels.first?.identifier ?? "item",
            materials: KeywordMatcher.findMaterials(from: labels, using: ruleset.visionKeywordHints),
            isFoodSoiled: false,
            isComposite: false,
            hazardClass: KeywordMatcher.findHazard(from: labels, using: ruleset.hazardKeywordHints),
            isEmpty: nil,
            printedDisposalHint: nil,
            tier: .visionKeyword
        )

        return switch SortingPolicy.decide(perception, using: ruleset) {
        case let .sorted(placement): placement.binID
        case let .hazard(hazard): hazard.binID
        case .split, .uncertain: nil
        }
    }

    /// Named rather than a bare tuple: as a tuple literal this case table defeated the
    /// type checker outright.
    struct Case {
        let item: String
        let labels: [(identifier: String, confidence: Double)]
        let expected: BinID
    }

    @Test("Common items reach the right bin from labels Vision really emits", arguments: [
        Case(
            item: "plastic water bottle",
            labels: [("bottle", 0.31), ("drinking_vessel", 0.12), ("container", 0.08)],
            expected: "anorganik"
        ),
        Case(
            item: "drink can",
            labels: [("can", 0.18), ("beverage", 0.11), ("cylinder", 0.06)],
            expected: "anorganik"
        ),
        Case(
            item: "banana",
            labels: [("banana", 0.44), ("fruit", 0.29), ("food", 0.21)],
            expected: "organik"
        ),
        Case(
            item: "cardboard box",
            labels: [("box", 0.26), ("carton", 0.19), ("container", 0.09)],
            expected: "anorganik"
        ),
        Case(
            item: "newspaper",
            labels: [("newspaper", 0.37), ("paper", 0.22), ("text", 0.14)],
            expected: "anorganik"
        ),
        Case(
            item: "wine bottle",
            labels: [("wine_bottle", 0.33), ("bottle", 0.28), ("glass", 0.10)],
            expected: "anorganik"
        ),
        Case(
            item: "plastic carrier bag",
            labels: [("plastic_bag", 0.24), ("bag", 0.16)],
            expected: "residu"
        ),
        Case(
            item: "till receipt",
            labels: [("receipt", 0.29), ("paper", 0.21)],
            expected: "residu"
        ),
        Case(
            item: "drinking straw",
            labels: [("drinking_straw", 0.22), ("straw", 0.17)],
            expected: "residu"
        ),
    ])
    func commonItemsReachTheRightBin(_ testCase: Case) throws {
        #expect(try bin(for: testCase.labels) == testCase.expected, "\(testCase.item) went to the wrong bin")
    }

    @Test("The fallback tier still intercepts hazards", arguments: [
        Case(item: "battery", labels: [("battery", 0.28), ("cylinder", 0.11)], expected: "b3"),
        Case(item: "light bulb", labels: [("light_bulb", 0.33), ("glass", 0.14)], expected: "b3"),
        Case(item: "phone charger", labels: [("charger", 0.24), ("cable", 0.19)], expected: "b3"),
        Case(item: "spray can", labels: [("aerosol_can", 0.26), ("can", 0.20)], expected: "b3"),
    ])
    func hazardsAreCaughtWithoutTheLanguageModel(_ testCase: Case) throws {
        // Without `hazardKeywordHints` these all reach a material rule instead: a battery
        // reads as metal and a bulb as glass, so both would be filed as recyclable on any
        // device where Apple Intelligence is unavailable. Safety must not be the tier
        // that degrades first.
        #expect(try bin(for: testCase.labels) == testCase.expected, "\(testCase.item) was not intercepted")
    }

    @Test("Nonsense labels still refuse to name a bin")
    func unrelatedLabelsStayUncertain() throws {
        // Loosening the thresholds must not turn the matcher into a rubber stamp: a
        // frame with nothing sortable in it has to stay uncertain, so that the card
        // presents the fallback as a guess rather than asserting a bin.
        //
        // "toucan" also pins the substring trap the matcher is built to avoid — it must
        // not read as "can".
        #expect(try bin(for: [("toucan", 0.62), ("beak", 0.44), ("feather", 0.31)]) == nil)
    }
}
