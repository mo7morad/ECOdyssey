import Foundation

/// One material the perception tier believes it saw, with how sure it is.
public struct MaterialObservation: Sendable, Equatable, Codable {
    public let materialID: MaterialID
    /// 0…1. Compared against the policy's confidence floor, so a tier that cannot
    /// estimate confidence must not report 1.0 — that would disable the floor.
    public let confidence: Double

    public init(materialID: MaterialID, confidence: Double) {
        self.materialID = materialID
        self.confidence = confidence
    }
}
