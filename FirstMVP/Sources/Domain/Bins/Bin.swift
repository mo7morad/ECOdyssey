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
        .organik: Bin(
            id: .organik,
            displayName: "Organic (Green)",
            emoji: "🟢",
            colorName: "green",
            spokenText: "Organic waste. Put in Green Bin.",
            summary: "Food scraps, leaves, vegetables, and compostable organic matter."
        ),
        .anorganik: Bin(
            id: .anorganik,
            displayName: "Inorganic (Yellow)",
            emoji: "🟡",
            colorName: "yellow",
            spokenText: "Inorganic waste. Put in Yellow Bin.",
            summary: "Recyclable plastic bottles, metal cans, containers, and glass."
        ),
        .kertas: Bin(
            id: .kertas,
            displayName: "Paper (Blue)",
            emoji: "🔵",
            colorName: "blue",
            spokenText: "Paper waste. Put in Blue Bin.",
            summary: "Paper, cardboard, newspapers, and packaging."
        ),
        .b3: Bin(
            id: .b3,
            displayName: "Hazardous (Red)",
            emoji: "🔴",
            colorName: "red",
            spokenText: "Hazardous waste. Put in Red Bin.",
            summary: "Batteries, e-waste, chemicals, and sharp glass shards."
        ),
        .residu: Bin(
            id: .residu,
            displayName: "Residual (Gray)",
            emoji: "⚪️",
            colorName: "gray",
            spokenText: "Residual waste. Put in Gray Bin.",
            summary: "General non-recyclable trash and composite waste."
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
