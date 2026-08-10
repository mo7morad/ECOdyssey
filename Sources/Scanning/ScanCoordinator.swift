import CoreGraphics
import Foundation
import Observation
import SortingKit

/// Drives the scan pipeline and owns the count-once invariant.
///
/// Frames flow through three tiers running at three very different costs:
/// presence detection every frame (~milliseconds), perception once per confirmed
/// track (~seconds), and policy as a pure function. Counting is driven by track
/// lifecycle, never by frames — that distinction is what fixed the original defect
/// where a stationary item was logged repeatedly for as long as it stayed in view.
@Observable
@MainActor
public final class ScanCoordinator {
    /// Boxes to draw over the preview, in Vision's normalised coordinate space.
    public private(set) var trackedBoxes: [TrackedBox] = []
    public private(set) var latestDecision: PresentedDecision?
    /// True while a perception call is in flight, so the UI can say "reading…"
    /// rather than leave a stale answer on screen.
    public private(set) var isPerceiving = false

    private var tracker: WasteTracker
    /// The count-once guard. Membership is checked with `insert(_:).inserted`, so a
    /// second attempt for the same track cannot append a second event even if the
    /// pipeline re-delivers a confirmation.
    private var countedTrackIDs: Set<TrackID> = []

    private let presenceDetector: VisionPresenceDetector
    private let perceptionEngine: any PerceptionEngine
    private let ruleset: SortingRuleset
    private let eventStore: ScanEventStore
    private let announcer: BinAnnouncer
    private let frameBudget: FrameBudget
    private let stationID: String

    private var pendingConfirmations: AsyncStream<PendingConfirmation>.Continuation?

    public init(
        tracker: WasteTracker = WasteTracker(),
        presenceDetector: VisionPresenceDetector,
        perceptionEngine: any PerceptionEngine,
        ruleset: SortingRuleset,
        eventStore: ScanEventStore,
        announcer: BinAnnouncer,
        frameBudget: FrameBudget,
        stationID: String
    ) {
        self.tracker = tracker
        self.presenceDetector = presenceDetector
        self.perceptionEngine = perceptionEngine
        self.ruleset = ruleset
        self.eventStore = eventStore
        self.announcer = announcer
        self.frameBudget = frameBudget
        self.stationID = stationID
    }

    /// Consumes camera frames until the stream ends or the task is cancelled.
    public func run(frames: AsyncStream<CGImage>) async {
        let (confirmations, continuation) = AsyncStream.makeStream(
            of: PendingConfirmation.self,
            bufferingPolicy: .bufferingNewest(Self.maximumQueuedConfirmations)
        )
        pendingConfirmations = continuation
        defer {
            continuation.finish()
            pendingConfirmations = nil
        }

        // Perception is serialised deliberately: the on-device model is a
        // seconds-scale resource and running two calls at once would slow both.
        async let perceptionLoop: Void = resolve(confirmations)
        await trackPresence(in: frames)
        continuation.finish()
        await perceptionLoop
    }

    private func trackPresence(in frames: AsyncStream<CGImage>) async {
        for await frame in frames {
            guard !Task.isCancelled else { return }
            guard await frameBudget.shouldProcessFrame() else { continue }

            let detections: [Detection]
            do {
                detections = try await presenceDetector.detect(in: frame)
            } catch {
                // A single unreadable frame is not worth interrupting the session for;
                // the next frame is milliseconds away. Losing the whole stream would be.
                continue
            }

            let events = tracker.ingest(detections, at: Date().timeIntervalSinceReferenceDate)
            trackedBoxes = tracker.visibleTracks.map { TrackedBox(id: $0.id, boundingBox: $0.boundingBox) }

            for event in events {
                guard case let .confirmed(trackID, confirmationFrame) = event else { continue }
                pendingConfirmations?.yield(
                    PendingConfirmation(trackID: trackID, image: frame, boundingBox: confirmationFrame.boundingBox)
                )
            }
        }
    }

    private func resolve(_ confirmations: AsyncStream<PendingConfirmation>) async {
        for await confirmation in confirmations {
            guard countedTrackIDs.insert(confirmation.trackID).inserted else { continue }
            await count(confirmation)
        }
    }

    private func count(_ confirmation: PendingConfirmation) async {
        isPerceiving = true
        defer { isPerceiving = false }

        let perception: ItemPerception?
        let decision: BinDecision
        do {
            let observed = try await perceptionEngine.perceive(
                PerceptionFrame(image: confirmation.image, boundingBox: confirmation.boundingBox)
            )
            perception = observed
            decision = SortingPolicy.decide(observed, using: ruleset)
        } catch {
            perception = nil
            decision = .uncertain(candidates: [], reason: .perceptionUnavailable)
        }

        record(decision, perception: perception, for: confirmation)
    }

    private func record(_ decision: BinDecision, perception: ItemPerception?, for confirmation: PendingConfirmation) {
        let presented = PresentedDecision(decision: decision, perception: perception, ruleset: ruleset)
        latestDecision = presented

        if let phrase = presented.spokenPhrase {
            Task { await announcer.announce(phrase) }
        }

        let event = ScanEvent(
            trackID: confirmation.trackID,
            occurredAt: Date(),
            binID: presented.bin?.id ?? Self.unresolvedBinID,
            materialID: perception?.materials.first?.materialID ?? Self.unresolvedMaterialID,
            itemName: presented.itemName,
            confidence: presented.confidence,
            outcome: presented.bin == nil ? .uncertain : .sorted,
            perceptionTier: perceptionEngine.tier,
            stationID: stationID
        )

        Task { [eventStore] in
            do {
                try await eventStore.append(event)
            } catch {
                // Losing a count skews the operator's numbers, so it must be visible
                // rather than swallowed. Wire this to real logging when one exists.
                assertionFailure("Failed to persist scan event: \(error)")
            }
        }
    }

    /// Bounded so a burst of items cannot grow an unbounded backlog of slow model
    /// calls; the oldest are dropped and simply go uncounted rather than queueing
    /// behind minutes of work.
    private static let maximumQueuedConfirmations = 4
    private static let unresolvedBinID = BinID(rawValue: "unresolved")
    private static let unresolvedMaterialID = MaterialID(rawValue: "unresolved")
}

private struct PendingConfirmation: Sendable {
    let trackID: TrackID
    let image: CGImage
    let boundingBox: CGRect
}

/// One tracked item's box, for the overlay.
public struct TrackedBox: Identifiable, Equatable, Sendable {
    public let id: TrackID
    public let boundingBox: CGRect
}
