import Testing
@testable import FirstMVP

struct AnalyticsStoreTests {
    @Test
    func metricsCalculationsAreCorrect() {
        let store = AnalyticsStore()
        store.clearHistory()

        store.appendRecord(objectName: "Apple", materialName: "Organic", binID: .organik)
        store.appendRecord(objectName: "Bottle", materialName: "Plastic", binID: .anorganik)
        store.appendRecord(objectName: "Box", materialName: "Cardboard", binID: .kertas)
        store.appendRecord(objectName: "Battery", materialName: "Hazardous", binID: .b3)
        store.appendRecord(objectName: "Wrapper", materialName: "Trash", binID: .residu)

        #expect(store.totalCount == 5)
        #expect(store.count(for: .organik) == 1)
        #expect(store.count(for: .anorganik) == 1)
        #expect(store.count(for: .kertas) == 1)
        #expect(store.count(for: .b3) == 1)
        #expect(store.count(for: .residu) == 1)

        // Diversion rate = (organik 1 + anorganik 1 + kertas 1) / 5 = 60%
        #expect(store.diversionRatePercentage == 60)

        // Carbon Saved = organik (50) + anorganik (200) + kertas (100) = 350
        #expect(store.totalCarbonSavedGrams == 350)
    }
}
