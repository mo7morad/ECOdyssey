import Foundation

public struct Bin: Identifiable, Codable, Sendable, Equatable {
    public let id: BinID
    public let displayName: String
    public let colorHex: String
    public let spokenPhrase: String
    public let guidance: String
    
    public init(
        id: BinID,
        displayName: String,
        colorHex: String,
        spokenPhrase: String,
        guidance: String
    ) {
        self.id = id
        self.displayName = displayName
        self.colorHex = colorHex
        self.spokenPhrase = spokenPhrase
        self.guidance = guidance
    }
}
