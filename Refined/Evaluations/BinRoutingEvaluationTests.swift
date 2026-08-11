import Evaluations
import Foundation
import SortingKit
import Testing
@testable import ECOdyssey

/// Runs the labelled photo set through the real pipeline and holds the result to a bar.
///
/// Not part of the unit suite and not for CI. Model output moves with the OS, the
/// hardware and Apple's own updates, so wiring this into a merge gate produces flaky
/// failures that teach people to ignore red builds. Run it deliberately, before and
/// after a prompt or ruleset change, and compare the numbers.
///
/// It is skipped rather than failed while `Evaluations/Photos/` is empty: a fresh
/// checkout has no dataset yet, and a red test nobody can fix is worse than no test.
@Suite("Bin routing evaluation")
struct BinRoutingEvaluationTests {
    static let evaluation = BinRoutingEvaluation(bundle: EvaluationPhotos.bundle)
    static var hasPhotos: Bool { !EvaluationPhotos.samples(in: EvaluationPhotos.bundle).isEmpty }

    @Test(
        "Photos of real waste reach the right bin",
        .enabled(if: hasPhotos, "Add labelled photos to Evaluations/Photos/ to run this."),
        .evaluates(evaluation, info: ["ruleset": "id-bali-v2"])
    )
    func photosReachTheRightBin() async throws {
        let evaluation = Self.evaluation
        let result = EvaluationContext.current.result

        // Not negotiable, and separated from overall accuracy on purpose: a station may
        // be 80% right about paper and still must never put a battery in a bin.
        #expect(
            result.aggregateValue(.mean(of: evaluation.hazardRecall)) == 1.0,
            "A hazardous item was routed to an ordinary bin."
        )

        // Starting bars, meant to be raised as the dataset and the ruleset improve.
        // Record the numbers before tuning anything, so a change can be shown to help.
        #expect(result.aggregateValue(.mean(of: evaluation.binAccuracy)) >= 0.80)
        #expect(result.aggregateValue(.mean(of: evaluation.falseHazard)) >= 0.95)
    }

    @Test("A photo file name states the bin it is labelled with")
    func fileNamesCarryTheirLabel() {
        // The dataset's whole labelling scheme is the file name, so a change to the
        // separator would silently drop every sample and score a perfect nothing.
        #expect(EvaluationPhotos.expectedBin(fromFileName: "residu__gelas-kopi.jpg") == "residu")
        #expect(EvaluationPhotos.expectedBin(fromFileName: "b3__baterai-aa.heic") == "b3")
        #expect(EvaluationPhotos.expectedBin(fromFileName: "no-label.jpg") == nil)
        #expect(EvaluationPhotos.expectedBin(fromFileName: "__leading.jpg") == nil)
    }

    @Test("Every labelled photo names a bin the ruleset defines")
    func labelsResolveToRealBins() throws {
        // Catches "recyclable__bottle.jpg" left over from the pre-Indonesian ruleset:
        // it would score as a permanent failure against a bin that no longer exists.
        let ruleset = try RulesetLoader.loadDefault()

        for sample in EvaluationPhotos.samples(in: EvaluationPhotos.bundle) {
            guard let expected = sample.expected else { continue }
            #expect(
                ruleset.bin(for: expected) != nil,
                "\(sample.input) is labelled '\(expected.rawValue)', which is not a bin"
            )
        }
    }
}
