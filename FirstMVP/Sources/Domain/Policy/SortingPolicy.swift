import Foundation

public struct SortingPolicy: Sendable {
    public static let organicKeywords: Set<String> = [
        "food", "fruit", "vegetable", "banana", "apple", "bread", "meat", "plant",
        "flower", "leaf", "compost", "produce", "citrus", "berry", "orange", "potato",
        "seed", "nut", "grape", "tomato", "salad"
    ]

    public static let plasticKeywords: Set<String> = [
        "plastic", "bottle", "water_bottle", "pop_bottle", "wrapper", "container",
        "tub", "bag", "polyester", "styrofoam", "drinking_straw", "shampoo_bottle"
    ]

    public static let metalKeywords: Set<String> = [
        "can", "tin", "aluminum", "foil", "metal", "beer_can", "soda_can",
        "brass", "steel", "aerosol"
    ]

    public static let paperKeywords: Set<String> = [
        "paper", "cardboard", "box", "carton", "newspaper", "envelope",
        "magazine", "paper_towel", "book"
    ]

    public static let glassKeywords: Set<String> = [
        "glass", "wine_bottle", "jar", "beer_bottle", "goblet", "flasket"
    ]

    public init() {}

    public func resolveBinID(for perception: ItemPerception) -> BinID {
        let labelLower = perception.classificationLabel.lowercased()
        let materialLower = perception.materialName.lowercased()

        if matches(label: labelLower, material: materialLower, keywords: Self.organicKeywords) {
            return .organic
        }
        if matches(label: labelLower, material: materialLower, keywords: Self.plasticKeywords)
            || matches(label: labelLower, material: materialLower, keywords: Self.metalKeywords)
            || matches(label: labelLower, material: materialLower, keywords: Self.paperKeywords)
            || matches(label: labelLower, material: materialLower, keywords: Self.glassKeywords) {
            return .recyclable
        }
        return .residual
    }

    private func matches(label: String, material: String, keywords: Set<String>) -> Bool {
        keywords.contains { keyword in
            label.contains(keyword) || material.contains(keyword)
        }
    }
}
