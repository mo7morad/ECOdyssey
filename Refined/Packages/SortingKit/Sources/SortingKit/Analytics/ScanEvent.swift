import Foundation

public enum ScanOutcome: String, Sendable, Codable, Equatable {
    case sorted
    case uncertain
    case overridden
}

public struct ScanEvent: Sendable, Equatable {
    public let trackID: TrackID
    public let occurredAt: Date
    public let binID: BinID
    public let materialID: MaterialID
    public let itemName: String
    public let confidence: Double
    public let outcome: ScanOutcome
    public let perceptionTier: PerceptionTier
    public let stationID: String

    public init(
        trackID: TrackID,
        occurredAt: Date,
        binID: BinID,
        materialID: MaterialID,
        itemName: String,
        confidence: Double,
        outcome: ScanOutcome,
        perceptionTier: PerceptionTier,
        stationID: String
    ) {
        self.trackID = trackID
        self.occurredAt = occurredAt
        self.binID = binID
        self.materialID = materialID
        self.itemName = itemName
        self.confidence = confidence
        self.outcome = outcome
        self.perceptionTier = perceptionTier
        self.stationID = stationID
    }
}
