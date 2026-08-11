import Foundation
import CoreGraphics

public struct TrackedItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let boundingBox: CGRect
    public let perception: ItemPerception
    public let assignedBinID: BinID

    public init(
        id: String,
        boundingBox: CGRect,
        perception: ItemPerception,
        assignedBinID: BinID
    ) {
        self.id = id
        self.boundingBox = boundingBox
        self.perception = perception
        self.assignedBinID = assignedBinID
    }
}
