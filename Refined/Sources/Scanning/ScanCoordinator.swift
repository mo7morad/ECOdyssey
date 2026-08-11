import CoreGraphics
import Foundation
import Observation
import SortingKit

/// Drives the scan pipeline and owns the count-once invariant.
///
/// The station watches, then photographs. Video frames are used only to answer "is
/// something there, and is it holding still" — presence detection and tracking, both
/// cheap and both per-frame. The moment an item holds still long enough to be treated as
/// real, the camera takes one proper photograph and *that* is what perception reads.
///
/// Reading a photograph rather than a video frame is the single largest accuracy change
/// this pipeline has had. A video buffer is unfocused, motion-blurred, sensor-oriented
/// and was additionally being cropped to a coarse presence box before the model saw it;
/// the same items photographed whole were identified reliably all along, which is why the
/// gallery screen always outperformed the live camera on identical objects.
///
/// Two things are deliberately kept apart here, because conflating them is what made the
/// station feel broken. *Counting* is driven by track lifecycle and happens exactly once
/// per item — that is what fixed the original defect where a stationary item was logged
/// repeatedly for as long as it stayed in view. *Answering* must never stall: if
/// something is in view and the card is still blank, a photograph is taken anyway, shown
/// and not counted.
@Observable
@MainActor
public final class ScanCoordinator {
    /// Boxes to draw over the preview, in Vision's normalised coordinate space.
    public private(set) var trackedBoxes: [TrackedBox] = []
    public private(set) var latestDecision: PresentedDecision?
    /// True while a photograph is being taken or read, so the UI can say "reading…"
    /// rather than leave a stale answer on screen.
    public private(set) var isPerceiving = false

    private var tracker: WasteTracker
    /// The count-once guard. Membership is checked with `insert(_:).inserted`, so a
    /// second attempt for the same track cannot append a second event even if the
    /// pipeline re-delivers a confirmation.
    private var countedTrackIDs: Set<TrackID> = []

    private let presenceDetector: VisionPresenceDetector
    private let camera: CameraSession
    private let perceptionEngine: any PerceptionEngine
    private let ruleset: SortingRuleset
    private let eventStore: ScanEventStore
    private let announcer: BinAnnouncer
    private let frameBudget: FrameBudget
    private let stationID: String

    private var perceptionRequests: AsyncStream<PerceptionRequest>.Continuation?
    /// When a read was last either queued or completed. Both count, so that frames
    /// arriving while a slow read is still queued cannot stack duplicates behind it.
    private var lastReadCheckpoint = Date.distantPast
    /// The tracks the answer on screen was about, so it can be cleared when they leave
    /// rather than on a timer that cannot tell one person's item from the next person's.
    private var answeredTrackIDs: Set<TrackID> = []
    private var answerPresentedAt = Date.distantPast
    private var lastAnnouncedPhrase: String?

    public init(
        tracker: WasteTracker = WasteTracker(),
        presenceDetector: VisionPresenceDetector,
        camera: CameraSession,
        perceptionEngine: any PerceptionEngine,
        ruleset: SortingRuleset,
        eventStore: ScanEventStore,
        announcer: BinAnnouncer,
        frameBudget: FrameBudget,
        stationID: String
    ) {
        self.tracker = tracker
        self.presenceDetector = presenceDetector
        self.camera = camera
        self.perceptionEngine = perceptionEngine
        self.ruleset = ruleset
        self.eventStore = eventStore
        self.announcer = announcer
        self.frameBudget = frameBudget
        self.stationID = stationID
    }

    /// Consumes camera frames until the stream ends or the task is cancelled.
    public func run(frames: AsyncStream<CGImage>) async {
        let (requests, continuation) = AsyncStream.makeStream(
            of: PerceptionRequest.self,
            bufferingPolicy: .bufferingNewest(Self.maximumQueuedRequests)
        )
        perceptionRequests = continuation
        defer {
            continuation.finish()
            perceptionRequests = nil
        }

        // Reads are serialised deliberately: taking a photograph reconfigures the capture
        // pipeline briefly and the on-device model is a seconds-scale resource, so two at
        // once would slow both and compete for the same camera.
        async let readLoop: Void = resolve(requests)
        await trackPresence(in: frames)
        continuation.finish()
        await readLoop
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

            queuePhotograph(for: events)
            clearAnswerOnceItsItemHasGone()
        }
    }

    /// Queues whatever this frame earned: a countable photograph per newly confirmed
    /// track, or failing that a photograph to break a stall.
    private func queuePhotograph(for events: [TrackEvent]) {
        let confirmedTrackIDs = events.compactMap { event -> TrackID? in
            guard case let .confirmed(trackID) = event else { return nil }
            return trackID
        }

        guard confirmedTrackIDs.isEmpty else {
            for trackID in confirmedTrackIDs {
                perceptionRequests?.yield(PerceptionRequest(purpose: .count(trackID)))
            }
            return
        }
        requestStallBreakingPhotograph()
    }

    /// Keeps the station from sitting there showing nothing while somebody holds an item
    /// up to it.
    ///
    /// Confirmation needs several frames of a stably tracked box, which a hand-held item
    /// or a coarse presence box may never produce — and without this the screen simply
    /// stays empty however long someone waits. Deliberately *not* a repeating refresh:
    /// once an answer is on the card it stays until the item leaves, because re-reading
    /// the same item would fire the shutter every couple of seconds for as long as anyone
    /// stood there. These readings are shown, never counted.
    private func requestStallBreakingPhotograph() {
        guard latestDecision == nil, !isPerceiving, !trackedBoxes.isEmpty else { return }
        // Checkpointed on the way in, not just on completion. A queued request has not
        // set `isPerceiving` yet, so without this the next frame — milliseconds later —
        // would queue another photograph of the same scene.
        guard Date().timeIntervalSince(lastReadCheckpoint) >= Self.stallBreakingInterval else { return }

        lastReadCheckpoint = Date()
        perceptionRequests?.yield(PerceptionRequest(purpose: .answerOnly))
    }

    /// Clears the card once the item it describes has gone.
    ///
    /// Keyed on the tracks the answer was about rather than on a timer, because a timer
    /// cannot tell "the same person still holding the same bottle" from "the next person
    /// holding something else" — and both matter here. The next person must not walk up
    /// to the previous person's answer, and `requestStallBreakingPhotograph` reads exactly
    /// this state to tell "nothing answered yet" from "already answered".
    ///
    /// The linger is what stops the answer vanishing the instant an item is lowered
    /// towards the bin, which is the moment somebody is still reading it.
    private func clearAnswerOnceItsItemHasGone() {
        guard latestDecision != nil else { return }
        guard Set(trackedBoxes.map(\.id)).isDisjoint(with: answeredTrackIDs) else { return }
        guard Date().timeIntervalSince(answerPresentedAt) >= Self.answerLingerSeconds else { return }

        latestDecision = nil
        answeredTrackIDs = []
        lastAnnouncedPhrase = nil
    }

    private func resolve(_ requests: AsyncStream<PerceptionRequest>) async {
        for await request in requests {
            if case let .count(trackID) = request.purpose {
                guard countedTrackIDs.insert(trackID).inserted else { continue }
            }
            await photographAndRead(request)
        }
    }

    private func photographAndRead(_ request: PerceptionRequest) async {
        isPerceiving = true
        defer {
            isPerceiving = false
            lastReadCheckpoint = Date()
        }

        let perception: ItemPerception?
        let decision: BinDecision
        do {
            let photograph = try await camera.captureStill()
            let observed = try await perceptionEngine.perceive(PerceptionFrame(image: photograph))
            perception = observed
            decision = SortingPolicy.decide(observed, using: ruleset)
        } catch {
            // A camera that will not photograph and a model that will not read are the
            // same thing to the person standing there: the station could not identify
            // what they are holding, and the card falls back to the site's default bin.
            perception = nil
            decision = .uncertain(candidates: [], reason: .perceptionUnavailable)
        }

        present(decision, perception: perception, for: request)
    }

    private func present(_ decision: BinDecision, perception: ItemPerception?, for request: PerceptionRequest) {
        let presented = PresentedDecision(decision: decision, perception: perception, ruleset: ruleset)
        latestDecision = presented
        answerPresentedAt = Date()
        // Whatever is on screen now, plus the track this answer was counted against. That
        // track may already have been lost during the seconds the photograph and the model
        // took, and without it the answer would read as being about nothing and clear
        // itself the moment the linger expired.
        answeredTrackIDs = Set(trackedBoxes.map(\.id)).union(request.purpose.countedTrackID.map { [$0] } ?? [])

        switch request.purpose {
        case let .count(trackID):
            speak(presented)
            record(presented, perception: perception, trackID: trackID)
        case .answerOnly:
            speakIfAnswerChanged(presented)
        }
    }

    /// A newly confirmed item is always worth announcing. A stall-breaking read might be
    /// repeating an answer the station has already given, so it only speaks when the
    /// answer actually changed.
    private func speakIfAnswerChanged(_ presented: PresentedDecision) {
        guard presented.spokenPhrase != lastAnnouncedPhrase else { return }
        speak(presented)
    }

    private func speak(_ presented: PresentedDecision) {
        guard let phrase = presented.spokenPhrase else { return }

        lastAnnouncedPhrase = phrase
        Task { await announcer.announce(phrase) }
    }

    private func record(_ presented: PresentedDecision, perception: ItemPerception?, trackID: TrackID) {
        let event = ScanEvent(
            trackID: trackID,
            occurredAt: Date(),
            binID: presented.bin?.id ?? Self.unresolvedBinID,
            materialID: perception?.materials.first?.materialID ?? Self.unresolvedMaterialID,
            itemName: presented.itemName,
            confidence: presented.confidence,
            // Recorded against the bin the policy would assert, not the suggestion shown
            // on the card. A hedged guess must not inflate the operator's sorted count.
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

    /// Bounded so a burst of items cannot grow an unbounded backlog of photographs; the
    /// oldest are dropped and simply go uncounted rather than queueing behind minutes of
    /// work.
    private static let maximumQueuedRequests = 4
    /// How long to let something sit in view unanswered before photographing it anyway.
    /// Long enough that a track which is going to confirm has confirmed, short enough
    /// that nobody decides the station is broken.
    private static let stallBreakingInterval: TimeInterval = 3.0
    /// How long an answer stays up at minimum, so it survives the item being lowered
    /// towards the bin.
    private static let answerLingerSeconds: TimeInterval = 5.0
    private static let unresolvedBinID = BinID(rawValue: "unresolved")
    private static let unresolvedMaterialID = MaterialID(rawValue: "unresolved")
}

/// Why a photograph was queued — and with it, whether the answer may be counted.
///
/// An enum rather than an optional track plus a boolean, because those two fields could
/// contradict each other: a countable request with no track, or a track that counts for
/// nothing, were both constructible and neither means anything. Here the track ID exists
/// exactly when counting applies.
private enum PerceptionPurpose: Sendable {
    /// A freshly confirmed track. The one reading allowed to append a `ScanEvent`.
    case count(TrackID)
    /// Breaks a stall so the card is not left blank. Shown, never persisted.
    case answerOnly

    /// The track this reading counts against, when it counts against one at all.
    var countedTrackID: TrackID? {
        guard case let .count(trackID) = self else { return nil }
        return trackID
    }
}

/// One photograph waiting to be taken and read.
private struct PerceptionRequest: Sendable {
    let purpose: PerceptionPurpose
}

/// One tracked item's box, for the overlay.
public struct TrackedBox: Identifiable, Equatable, Sendable {
    public let id: TrackID
    public let boundingBox: CGRect
}
