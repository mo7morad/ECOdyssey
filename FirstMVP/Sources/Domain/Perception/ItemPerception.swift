import Foundation

public struct ItemPerception: Equatable, Sendable {
    public let classificationLabel: String
    public let materialName: String
    public let confidenceScore: Float
    public let detailSummary: String

    public init(
        classificationLabel: String,
        materialName: String,
        confidenceScore: Float,
        detailSummary: String
    ) {
        self.classificationLabel = classificationLabel
        self.materialName = materialName
        self.confidenceScore = confidenceScore
        self.detailSummary = detailSummary
    }
}
