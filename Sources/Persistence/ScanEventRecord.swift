import Foundation
import SwiftData
import SortingKit

/// SwiftData row for one counted item.
///
/// Identifiers are stored as their stable raw strings, never as display text. Renaming
/// a bin must never reclassify history — that was the defect in the original
/// `UserDefaults` store, where the bin's emoji-bearing label doubled as its key.
@Model
public final class ScanEventRecord {
    public var trackIDRaw: String
    public var occurredAt: Date
    public var binIDRaw: String
    public var materialIDRaw: String
    public var itemName: String
    public var confidence: Double
    public var outcomeRaw: String
    public var perceptionTierRaw: String
    public var stationID: String

    public init(event: ScanEvent) {
        self.trackIDRaw = event.trackID.rawValue
        self.occurredAt = event.occurredAt
        self.binIDRaw = event.binID.rawValue
        self.materialIDRaw = event.materialID.rawValue
        self.itemName = event.itemName
        self.confidence = event.confidence
        self.outcomeRaw = event.outcome.rawValue
        self.perceptionTierRaw = event.perceptionTier.rawValue
        self.stationID = event.stationID
    }

    /// Rows written by an older build may carry values this build no longer knows.
    /// Those resolve to explicit unknown markers so analytics can report them as
    /// retired rather than silently folding them into another bin.
    public var event: ScanEvent {
        ScanEvent(
            trackID: TrackID(rawValue: trackIDRaw),
            occurredAt: occurredAt,
            binID: BinID(rawValue: binIDRaw),
            materialID: MaterialID(rawValue: materialIDRaw),
            itemName: itemName,
            confidence: confidence,
            outcome: ScanOutcome(rawValue: outcomeRaw) ?? .uncertain,
            perceptionTier: PerceptionTier(rawValue: perceptionTierRaw) ?? .visionKeyword,
            stationID: stationID
        )
    }
}
