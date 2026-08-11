import Testing
@testable import FirstMVP

struct SortingPolicyTests {
    private let policy = SortingPolicy()

    @Test
    func organicKeywordsMapToOrganicBin() {
        let perception = ItemPerception(
            classificationLabel: "Banana Peel",
            materialName: "Organic / Food Scraps 🍌",
            confidenceScore: 0.95,
            detailSummary: "Food scrap"
        )
        let binID = policy.resolveBinID(for: perception)
        #expect(binID == .organic)
    }

    @Test
    func plasticKeywordsMapToRecyclableBin() {
        let perception = ItemPerception(
            classificationLabel: "Water Bottle",
            materialName: "Plastic 🧴",
            confidenceScore: 0.90,
            detailSummary: "Plastic bottle"
        )
        let binID = policy.resolveBinID(for: perception)
        #expect(binID == .recyclable)
    }

    @Test
    func unknownMaterialMapsToResidualBin() {
        let perception = ItemPerception(
            classificationLabel: "Ceramic Shard",
            materialName: "Mixed / General Trash 🗑️",
            confidenceScore: 0.50,
            detailSummary: "Unrecognized item"
        )
        let binID = policy.resolveBinID(for: perception)
        #expect(binID == .residual)
    }
}
