import CoreGraphics
import Evaluations
import Foundation
import SortingKit
@testable import ECOdyssey

/// Grades the whole station — perception tier, ruleset and policy — against photos of
/// real waste whose correct bin is already known.
///
/// This is the only thing in the project that can answer "is it accurate?" with a
/// number. Unit tests pin the logic given a perception; they cannot tell you whether
/// the model recognises a Balinese takeaway box, and every prompt or ruleset change is
/// otherwise a guess about something nobody measured.
///
/// Deliberately no `ModelJudgeEvaluator`: for sorting, the right answer is a known
/// `BinID`, so every metric here is an exact comparison. That is cheaper, reproducible,
/// and needs no Private Cloud Compute entitlement to run.
struct BinRoutingEvaluation: Evaluation {
    /// Did the item reach the bin it actually belongs in.
    let binAccuracy = Metric("BinAccuracy")
    /// Of the items that are hazardous, how many were caught. Held at 1.0 — a missed
    /// battery is a fire, not a rounding error.
    let hazardRecall = Metric("HazardRecall")
    /// Ordinary waste wrongly sent to B3. Cheap to get wrong compared with the above,
    /// but a station that calls everything hazardous teaches people to ignore it.
    let falseHazard = Metric("FalseHazard")
    /// How often the station declined to name a bin at all.
    let unresolvedRate = Metric("UnresolvedRate")

    let bundle: Bundle
    let ruleset: SortingRuleset?
    private let engine: (any PerceptionEngine)?

    enum SetupError: Error {
        /// The shipped ruleset would not load. `RulesetDecodingTests` in SortingKit
        /// reports the underlying decoding error; this only has to stop the evaluation
        /// from scoring a pipeline it never built.
        case rulesetUnavailable
    }

    /// Non-throwing because `.evaluates` takes the evaluation as a macro argument,
    /// where `try` is not available. A failed load is carried as `nil` and thrown from
    /// `subject(from:)`, which is the first place an error can actually propagate.
    init(bundle: Bundle) {
        self.bundle = bundle
        let ruleset = try? RulesetLoader.loadDefault()
        self.ruleset = ruleset
        // The same selection the app makes, so the score describes the shipping
        // pipeline rather than one that only exists under test.
        self.engine = ruleset.map(AppEnvironment.makePerceptionEngine)
    }

    var dataset: ArrayLoader<WastePhotoSample> {
        ArrayLoader(samples: EvaluationPhotos.samples(in: bundle))
    }

    func subject(from sample: WastePhotoSample) async throws -> ModelSubject<BinID> {
        guard let ruleset, let engine else { throw SetupError.rulesetUnavailable }

        let image = try EvaluationPhotos.image(named: sample.input, in: bundle)
        let perception = try await engine.perceive(PerceptionFrame(image: image))
        let decision = SortingPolicy.decide(perception, using: ruleset)

        return ModelSubject(value: Self.bin(of: decision))
    }

    /// A split counts as its first component, matching what the station records for it.
    private static func bin(of decision: BinDecision) -> BinID {
        switch decision {
        case let .sorted(placement): placement.binID
        case let .hazard(hazard): hazard.binID
        case let .split(parts, _): parts.first?.binID ?? .unresolved
        case .uncertain: .unresolved
        }
    }

    private var hazardBinID: BinID? {
        ruleset?.hazardRules.first?.binID
    }

    @EvaluatorsBuilder<WastePhotoSample, ModelSubject<BinID>>
    var evaluators: Evaluators {
        Evaluator { sample, subject in
            guard let expected = sample.expected else {
                return binAccuracy.ignore(rationale: "unlabelled")
            }
            return subject.value == expected
                ? binAccuracy.passing(rationale: expected.rawValue)
                : binAccuracy.failing(rationale: "got \(subject.value.rawValue), expected \(expected.rawValue)")
        }

        Evaluator { sample, subject in
            // `.ignore` rather than `.passing` for non-hazard photos: counting them as
            // passes would dilute recall toward 1.0 with samples that never tested it.
            guard let hazardBin = hazardBinID, sample.expected == hazardBin else {
                return hazardRecall.ignore(rationale: "not a hazard")
            }
            return subject.value == hazardBin
                ? hazardRecall.passing()
                : hazardRecall.failing(rationale: "hazard sent to \(subject.value.rawValue)")
        }

        Evaluator { sample, subject in
            guard let hazardBin = hazardBinID, sample.expected != hazardBin else {
                return falseHazard.ignore(rationale: "genuinely hazardous")
            }
            return subject.value == hazardBin
                ? falseHazard.failing(rationale: "ordinary waste called hazardous")
                : falseHazard.passing()
        }

        Evaluator { _, subject in
            subject.value == .unresolved
                ? unresolvedRate.failing(rationale: "no bin named")
                : unresolvedRate.passing()
        }
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.computeMean(of: binAccuracy)
        aggregator.computeMean(of: hazardRecall)
        aggregator.computeMean(of: falseHazard)
        aggregator.computeMean(of: unresolvedRate)
    }
}
