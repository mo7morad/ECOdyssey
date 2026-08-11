import Testing
@testable import FirstMVP

struct SortingPolicyTests {
    private let policy = SortingPolicy()

    @Test
    func organicKeywordsMapToOrganikBin() {
        let perception = ItemPerception(
            classificationLabel: "Banana Peel",
            materialName: "Organic / Food Scraps 🍌",
            confidenceScore: 0.95,
            detailSummary: "Food scrap"
        )
        let binID = policy.resolveBinID(for: perception)
        #expect(binID == .organik)
    }

    @Test
    func plasticKeywordsMapToAnorganikBin() {
        let perception = ItemPerception(
            classificationLabel: "Water Bottle",
            materialName: "Inorganic / Recyclable 🧴",
            confidenceScore: 0.90,
            detailSummary: "Plastic bottle"
        )
        let binID = policy.resolveBinID(for: perception)
        #expect(binID == .anorganik)
    }

    @Test
    func paperKeywordsMapToKertasBin() {
        let perception = ItemPerception(
            classificationLabel: "Cardboard Box",
            materialName: "Paper / Cardboard 📦",
            confidenceScore: 0.90,
            detailSummary: "Cardboard"
        )
        let binID = policy.resolveBinID(for: perception)
        #expect(binID == .kertas)
    }

    @Test
    func b3KeywordsMapToB3Bin() {
        let perception = ItemPerception(
            classificationLabel: "AA Battery",
            materialName: "Hazardous / B3 🔋",
            confidenceScore: 0.90,
            detailSummary: "Battery"
        )
        let binID = policy.resolveBinID(for: perception)
        #expect(binID == .b3)
    }

    @Test
    func unknownMaterialMapsToResiduBin() {
        let perception = ItemPerception(
            classificationLabel: "Ceramic Shard",
            materialName: "Residual / General Trash 🗑️",
            confidenceScore: 0.50,
            detailSummary: "Unrecognized item"
        )
        let binID = policy.resolveBinID(for: perception)
        #expect(binID == .residu)
    }
}
