import Foundation

public struct Bin: Identifiable, Hashable, Sendable {
    public let id: BinID
    public let displayName: String
    public let emoji: String
    public let colorName: String
    public let spokenText: String
    public let summary: String

    public init(
        id: BinID,
        displayName: String,
        emoji: String,
        colorName: String,
        spokenText: String,
        summary: String
    ) {
        self.id = id
        self.displayName = displayName
        self.emoji = emoji
        self.colorName = colorName
        self.spokenText = spokenText
        self.summary = summary
    }

    public static let predefinedBins: [BinID: Bin] = [
        .organic: Bin(
            id: .organic,
            displayName: "Organic Waste",
            emoji: "🟢",
            colorName: "green",
            spokenText: "Organic waste. Put in Green Bin.",
            summary: "Compostable organic matter (food scraps, fruit, vegetables, plants)."
        ),
        .recyclable: Bin(
            id: .recyclable,
            displayName: "Recyclable Waste",
            emoji: "🔵",
            colorName: "blue",
            spokenText: "Recyclable. Put in Blue Bin.",
            summary: "Clean recyclable materials (plastic bottles, aluminum cans, cardboard, paper, glass)."
        ),
        .residual: Bin(
            id: .residual,
            displayName: "Residual Waste",
            emoji: "⬛",
            colorName: "gray",
            spokenText: "Residual waste. Put in Black Bin.",
            summary: "Non-recyclable items, composite materials, or general residual trash."
        ),
        .retired: Bin(
            id: .retired,
            displayName: "Retired Category",
            emoji: "⚪",
            colorName: "secondary",
            spokenText: "Unassigned bin category.",
            summary: "Unrecognized or retired bin category."
        )
    ]

    public static func resolve(_ binID: BinID) -> Bin {
        predefinedBins[binID] ?? predefinedBins[.retired]!
    }
}
