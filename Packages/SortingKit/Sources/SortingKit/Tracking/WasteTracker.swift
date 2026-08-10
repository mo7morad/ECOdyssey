import CoreGraphics

/// Follows physical items across frames so that each one is counted exactly once.
///
/// The tracker is a pure state machine: it reads no clock, touches no framework and
/// performs no I/O. Timestamps arrive as parameters. That is what makes the
/// count-once invariant testable without a camera.
///
/// Frame-driven counting was the original defect in this app — a stationary item was
/// logged every few seconds for as long as it stayed in view. Counting is now driven
/// by track lifecycle: `.confirmed` fires once per `TrackID`, and never again.
public struct WasteTracker: Sendable {
    private var tracks: [Track] = []
    private let configuration: TrackerConfiguration

    public init(configuration: TrackerConfiguration = .init()) {
        self.configuration = configuration
    }

    /// Advances the tracker by one frame.
    ///
    /// - Parameters:
    ///   - detections: every item the presence detector found in this frame.
    ///   - timestamp: seconds on any monotonic timeline; only differences are used.
    /// - Returns: lifecycle transitions caused by this frame.
    public mutating func ingest(_ detections: [Detection], at timestamp: Double) -> [TrackEvent] {
        var events: [TrackEvent] = []
        var unclaimedDetections = detections

        for index in tracks.indices {
            if let matchIndex = indexOfBestMatch(for: tracks[index].lastDetection.boundingBox, in: unclaimedDetections) {
                let matched = unclaimedDetections.remove(at: matchIndex)
                advanceSeenTrack(at: index, with: matched, timestamp: timestamp, events: &events)
            } else {
                advanceMissingTrack(at: index, timestamp: timestamp, events: &events)
            }
        }

        tracks.append(contentsOf: unclaimedDetections.map { Track(detection: $0, timestamp: timestamp) })

        let configuration = self.configuration
        tracks.removeAll { Self.isExpired($0, at: timestamp, configuration: configuration) }

        return events
    }

    /// Tracks currently believed to be on screen, for drawing the overlay.
    public var visibleTracks: [(id: TrackID, boundingBox: CGRect)] {
        tracks
            .filter { $0.framesMissing == 0 }
            .map { ($0.id, $0.lastDetection.boundingBox) }
    }

    private func indexOfBestMatch(for boundingBox: CGRect, in detections: [Detection]) -> Int? {
        var bestIndex: Int?
        var bestOverlap = configuration.associationIoUThreshold

        for (index, detection) in detections.enumerated() {
            let overlap = intersectionOverUnion(boundingBox, detection.boundingBox)
            if overlap > bestOverlap {
                bestOverlap = overlap
                bestIndex = index
            }
        }
        return bestIndex
    }

    private mutating func advanceSeenTrack(
        at index: Int,
        with detection: Detection,
        timestamp: Double,
        events: inout [TrackEvent]
    ) {
        tracks[index].framesSeen += 1
        tracks[index].framesMissing = 0
        tracks[index].lastDetection = detection
        tracks[index].lastSeenTimestamp = timestamp

        if detection.quality > tracks[index].bestQualityDetection.quality {
            tracks[index].bestQualityDetection = detection
        }

        switch tracks[index].state {
        case .pending where tracks[index].framesSeen >= configuration.framesToConfirm:
            tracks[index].state = .confirmed
            events.append(.confirmed(tracks[index].id, confirmationFrame: tracks[index].bestQualityDetection))
        case .retiring:
            // The same item reappearing inside the grace window. Deliberately silent:
            // re-confirming here would double-count an item that was merely occluded.
            tracks[index].state = .confirmed
        case .pending, .confirmed:
            break
        }
    }

    private mutating func advanceMissingTrack(at index: Int, timestamp: Double, events: inout [TrackEvent]) {
        tracks[index].framesMissing += 1

        switch tracks[index].state {
        case .confirmed where tracks[index].framesMissing > configuration.framesToRetire:
            tracks[index].state = .retiring
        case .retiring where hasOutlivedGrace(tracks[index], at: timestamp):
            events.append(.retired(tracks[index].id))
        case .pending, .confirmed, .retiring:
            break
        }
    }

    private static func isExpired(
        _ track: Track,
        at timestamp: Double,
        configuration: TrackerConfiguration
    ) -> Bool {
        switch track.state {
        case .pending: track.framesMissing > configuration.framesToRetire
        case .retiring: timestamp - track.lastSeenTimestamp > configuration.reentryGraceSeconds
        case .confirmed: false
        }
    }

    private func hasOutlivedGrace(_ track: Track, at timestamp: Double) -> Bool {
        timestamp - track.lastSeenTimestamp > configuration.reentryGraceSeconds
    }

    private func intersectionOverUnion(_ lhs: CGRect, _ rhs: CGRect) -> Double {
        let overlap = lhs.intersection(rhs)
        guard !overlap.isNull, !overlap.isEmpty else { return 0 }

        let overlapArea = overlap.width * overlap.height
        let unionArea = (lhs.width * lhs.height) + (rhs.width * rhs.height) - overlapArea
        guard unionArea > 0 else { return 0 }

        return overlapArea / unionArea
    }
}
