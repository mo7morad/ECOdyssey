import Foundation

public struct SortingPolicy: Sendable {
    public static let organicKeywords: Set<String> = [
        "food", "fruit", "vegetable", "banana", "apple", "bread", "meat", "plant",
        "flower", "leaf", "compost", "produce", "citrus", "berry", "orange", "potato",
        "seed", "nut", "grape", "tomato", "salad", "wood"
    ]

    public static let anorganicKeywords: Set<String> = [
        "plastic", "bottle", "water_bottle", "pop_bottle", "wrapper", "container",
        "tub", "bag", "polyester", "styrofoam", "drinking_straw", "shampoo_bottle",
        "can", "tin", "aluminum", "foil", "metal", "beer_can", "soda_can",
        "brass", "steel", "glass", "wine_bottle", "jar", "beer_bottle", "goblet"
    ]

    public static let paperKeywords: Set<String> = [
        "paper", "cardboard", "box", "carton", "newspaper", "envelope",
        "magazine", "paper_towel", "book"
    ]

    public static let b3Keywords: Set<String> = [
        "battery", "electronic", "phone", "circuit", "bulb", "lamp", "chemical",
        "syringe", "medicine", "pill", "paint", "aerosol"
    ]

    public init() {}

    public func resolveBinID(for perception: ItemPerception) -> BinID {
        let labelLower = perception.classificationLabel.lowercased()
        let materialLower = perception.materialName.lowercased()

        if matches(label: labelLower, material: materialLower, keywords: Self.organicKeywords) {
            return .organik
        }
        if matches(label: labelLower, material: materialLower, keywords: Self.b3Keywords) {
            return .b3
        }
        if matches(label: labelLower, material: materialLower, keywords: Self.paperKeywords) {
            return .kertas
        }
        if matches(label: labelLower, material: materialLower, keywords: Self.anorganicKeywords) {
            return .anorganik
        }
        
        return .residu
    }

    private func matches(label: String, material: String, keywords: Set<String>) -> Bool {
        keywords.contains { keyword in
            label.contains(keyword) || material.contains(keyword)
        }
    }
}
