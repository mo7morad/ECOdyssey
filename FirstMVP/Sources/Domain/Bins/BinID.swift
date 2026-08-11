import Foundation

public struct BinID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let organic = BinID(rawValue: "organic")
    public static let recyclable = BinID(rawValue: "recyclable")
    public static let residual = BinID(rawValue: "residual")
    public static let retired = BinID(rawValue: "retired")

    public var description: String {
        rawValue
    }
}
