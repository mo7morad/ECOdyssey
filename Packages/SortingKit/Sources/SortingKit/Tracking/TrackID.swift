import Foundation

/// Identity of one tracked physical item, from the frame it is first detected in
/// until it leaves the scene.
///
/// This is the deduplication key for the count-once invariant: exactly one
/// `ScanEvent` is ever appended per `TrackID`. It is therefore generated from a
/// UUID rather than a shared counter — a process-wide counter would need
/// synchronisation, and an unsynchronised one could mint colliding IDs across
/// tracker instances and silently merge two items into one count.
public struct TrackID: Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init() {
        self.rawValue = UUID().uuidString
    }
}
