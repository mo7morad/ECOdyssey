import CoreGraphics
import Observation
import SortingKit

/// Reads one picked picture with the same perception tier and ruleset the live station
/// uses, so a decision can be checked without holding the item up to the camera.
///
/// Deliberately appends no `ScanEvent`. A picture from the photo library is not an item
/// that passed the station, and counting it would put items in the operator's waste
/// numbers that never went into a bin.
@Observable
@MainActor
public final class StillImageScanner {
    public private(set) var decision: PresentedDecision?
    public private(set) var isPerceiving = false
    /// Surfaced rather than swallowed: a person who picked a photo and got nothing back
    /// needs to know whether the model failed or the item was simply unrecognised.
    public private(set) var failure: Error?

    private let perceptionEngine: any PerceptionEngine
    private let ruleset: SortingRuleset

    public init(perceptionEngine: any PerceptionEngine, ruleset: SortingRuleset) {
        self.perceptionEngine = perceptionEngine
        self.ruleset = ruleset
    }

    /// - Parameter image: the framing the person chose is the framing perception gets,
    ///   which is now also what the live station does with the photograph it takes.
    public func scan(_ image: CGImage) async {
        decision = nil
        failure = nil
        isPerceiving = true
        defer { isPerceiving = false }

        do {
            let perceived = try await perceptionEngine.perceive(PerceptionFrame(image: image))
            decision = PresentedDecision(
                decision: SortingPolicy.decide(perceived, using: ruleset),
                perception: perceived,
                ruleset: ruleset
            )
        } catch {
            failure = error
        }
    }
}
