import Foundation

public struct ItemTracker: Sendable {
    private(set) public var trackedIDs: Set<String>

    public init(trackedIDs: Set<String> = []) {
        self.trackedIDs = trackedIDs
    }

    public mutating func track(id: String) -> Bool {
        let (inserted, _) = trackedIDs.insert(id)
        return inserted
    }

    public mutating func reset() {
        trackedIDs.removeAll()
    }
}
