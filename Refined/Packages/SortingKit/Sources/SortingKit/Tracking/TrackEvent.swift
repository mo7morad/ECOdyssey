/// Lifecycle transitions emitted by `WasteTracker`.
public enum TrackEvent: Sendable, Equatable {
    /// A track has been seen often enough to be treated as a real item.
    ///
    /// Fires exactly once per `TrackID`. This is the only event that may lead to
    /// a `ScanEvent` being recorded.
    ///
    /// Carries no detection. It used to hand out the best-quality box seen so far,
    /// because perception ran on a crop of the video frame; perception now photographs
    /// the scene instead, so confirmation says only *when* to take that photograph.
    case confirmed(TrackID)

    /// The item has left the scene and its identity may be released.
    case retired(TrackID)
}
