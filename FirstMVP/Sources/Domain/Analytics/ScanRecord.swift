import Foundation

public struct ScanRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let objectName: String
    public let materialName: String
    public let binIDRaw: String

    public var binID: BinID {
        BinID(rawValue: binIDRaw)
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        objectName: String,
        materialName: String,
        binID: BinID
    ) {
        self.id = id
        self.timestamp = timestamp
        self.objectName = objectName
        self.materialName = materialName
        self.binIDRaw = binID.rawValue
    }
}
