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
    public let stillImageScanner: StillImageScanner

    public init() throws {
        let ruleset = try RulesetLoader.loadDefault()
        let container = try ModelContainer(for: ScanEventRecord.self)
        let eventStore = ScanEventStore(modelContainer: container)
        // Shared with the live pipeline rather than built twice: the on-device model is
        // expensive to warm and a second session would compete with the station's.
        let perceptionEngine = Self.makePerceptionEngine(for: ruleset)
        let frameBudget = FrameBudget()
        // One session, shared: the coordinator both watches its video stream and asks it
        // for the photograph each reading is made from, so they must be the same camera.
        let cameraSession = CameraSession()

        self.ruleset = ruleset
        self.eventStore = eventStore
        self.cameraSession = cameraSession
        self.stillImageScanner = StillImageScanner(perceptionEngine: perceptionEngine, ruleset: ruleset)
        self.coordinator = ScanCoordinator(
            presenceDetector: VisionPresenceDetector(),
            camera: cameraSession,
            perceptionEngine: perceptionEngine,
            ruleset: ruleset,
            eventStore: eventStore,
            announcer: BinAnnouncer(localeIdentifier: ruleset.spokenLocale),
            frameBudget: frameBudget,
            stationID: StationIdentity.current
        )

        // The budget only steps the frame rate down as the device heats up if something
        // starts it; without this the thermal backoff was dead code.
        Task { await frameBudget.startMonitoringThermalState() }
    }

    /// Picks the best perception tier this device can actually run.
    ///
    /// The app deploys to iOS 27, so image input is always in the framework — but Apple
    /// Intelligence still has to be supported by the hardware and switched on. Both
    /// paths ship and both are real: on a device without it, the Vision tier is the
    /// product, not a placeholder.
    /// Internal rather than private so the evaluation harness measures the same tier
    /// selection the station runs. A second copy of this choice in the tests would let
    /// the numbers describe a pipeline nobody ships.
    /// `nonisolated` because it is a pure factory — it reads its argument and builds an
    /// engine, touching no main-actor state — and the evaluation harness needs to build
    /// the same tier off the main actor.
    nonisolated static func makePerceptionEngine(for ruleset: SortingRuleset) -> any PerceptionEngine {
        guard FoundationModelPerception.isAvailable else {
            return VisionKeywordPerception(
                keywordHints: ruleset.visionKeywordHints,
                hazardHints: ruleset.hazardKeywordHints
            )
        }
        let engine = FoundationModelPerception(
            knownMaterials: ruleset.knownMaterials,
            knownHazardClasses: ruleset.knownHazardClasses
        )
        engine.prewarm()
        return engine
    }
}
