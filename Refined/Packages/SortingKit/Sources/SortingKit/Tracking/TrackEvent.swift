/// Lifecycle transitions emitted by `WasteTracker`.
public enum TrackEvent: Sendable, Equatable {
    /// A track has been seen often enough to be treated as a real item.
    ///
    /// Fires exactly once per `TrackID`. This is the only event that may lead to
    /// a `ScanEvent` being recorded.
    ///
    /// `confirmationFrame` is the best-quality detection observed *up to the moment of
    /// confirmation* — not the best across the track's whole life, which is not
    /// knowable yet. Perception runs on this crop, so raising `framesToConfirm` trades
    /// responsiveness for image quality.
    case confirmed(TrackID, confirmationFrame: Detection)

    /// The item has left the scene and its identity may be released.
    case retired(TrackID)
}
