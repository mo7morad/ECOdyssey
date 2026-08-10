import Foundation
import SortingKit
import SwiftData

/// Composition root: builds the object graph once, at launch.
///
/// Everything the app needs is assembled here rather than reached for through
/// singletons, so a screen can be driven by a different ruleset or store in a test or a
/// preview without touching global state.
@MainActor
public final class AppEnvironment {
    public let ruleset: SortingRuleset
    public let eventStore: ScanEventStore
    public let coordinator: ScanCoordinator
    public let cameraSession: CameraSession

    public init() throws {
        let ruleset = try RulesetLoader.loadDefault()
        let container = try ModelContainer(for: ScanEventRecord.self)
        let eventStore = ScanEventStore(modelContainer: container)

        self.ruleset = ruleset
        self.eventStore = eventStore
        self.cameraSession = CameraSession()
        self.coordinator = ScanCoordinator(
            presenceDetector: VisionPresenceDetector(),
            perceptionEngine: Self.makePerceptionEngine(for: ruleset),
            ruleset: ruleset,
            eventStore: eventStore,
            announcer: BinAnnouncer(),
            frameBudget: FrameBudget(),
            stationID: StationIdentity.current
        )
    }

    /// Picks the best perception tier this device can actually run.
    ///
    /// Image input needs iOS 27 *and* Apple Intelligence hardware with the feature
    /// switched on, so both paths ship and both are real. On iOS 26 — the likely
    /// deployment for a while yet — the Vision tier is the product, not a placeholder.
    private static func makePerceptionEngine(for ruleset: SortingRuleset) -> any PerceptionEngine {
        if #available(iOS 27, *), FoundationModelPerception.isAvailable {
            let engine = FoundationModelPerception(knownMaterials: ruleset.knownMaterials)
            engine.prewarm()
            return engine
        }
        return VisionKeywordPerception(keywordHints: ruleset.visionKeywordHints)
    }
}
