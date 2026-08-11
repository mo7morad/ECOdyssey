import Foundation

public struct BinID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let organik = BinID(rawValue: "organik")
    public static let anorganik = BinID(rawValue: "anorganik")
    public static let kertas = BinID(rawValue: "kertas")
    public static let b3 = BinID(rawValue: "b3")
    public static let residu = BinID(rawValue: "residu")
    
    public static let retired = BinID(rawValue: "retired")

    public var description: String {
        rawValue
    }
}
