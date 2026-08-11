import CoreGraphics

enum TrackState: Sendable, Equatable {
    /// Seen, but not yet often enough to be trusted as a real item.
    case pending
    /// Counted. Never counted again.
    case confirmed
    /// Missing, but still eligible to be reclaimed by a reappearing item.
    case retiring
}

struct Track: Sendable, Equatable {
    let id: TrackID
    var state: TrackState
    var lastDetection: Detection
    /// Cumulative, not consecutive — an item that flickers in and out still
    /// accumulates towards confirmation as long as it is re-associated in time.
    var framesSeen: Int
    var framesMissing: Int
    var lastSeenTimestamp: Double

    init(detection: Detection, timestamp: Double) {
        self.id = TrackID()
        self.state = .pending
        self.lastDetection = detection
        self.framesSeen = 1
        self.framesMissing = 0
        self.lastSeenTimestamp = timestamp
    }
}
