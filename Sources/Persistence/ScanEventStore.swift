import Foundation
import SwiftData
import SortingKit

public enum ScanEventStoreError: Error {
    case saveFailed(underlying: Error)
}

/// Append-only store for counted items.
///
/// Every write is one insert. The previous implementation re-encoded the whole
/// history into `UserDefaults` on each event, which is O(n) per item and stalls a
/// kiosk within days.
@ModelActor
public actor ScanEventStore {
    public func append(_ event: ScanEvent) throws {
        modelContext.insert(ScanEventRecord(event: event))
        do {
            try modelContext.save()
        } catch {
            // A dropped save is a lost count, which silently corrupts the operator's
            // numbers. Surface it so the caller can log or retry.
            throw ScanEventStoreError.saveFailed(underlying: error)
        }
    }

    public func allEvents() throws -> [ScanEvent] {
        let descriptor = FetchDescriptor<ScanEventRecord>(
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.event)
    }
}
