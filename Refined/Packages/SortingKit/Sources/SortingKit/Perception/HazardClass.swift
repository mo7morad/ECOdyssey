import Foundation

/// A kind of item that must not go in an ordinary bin.
///
/// An opaque string for the same reason `MaterialID` is: which classes exist is site
/// and jurisdiction policy. Indonesia's B3 stream (*Bahan Berbahaya dan Beracun*) is a
/// legally separate category covering batteries, electronics, lamps and household
/// chemicals, and a site elsewhere may split or merge those differently.
public struct HazardClass: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}
