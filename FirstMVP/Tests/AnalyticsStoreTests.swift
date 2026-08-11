import Testing
@testable import FirstMVP

struct AnalyticsStoreTests {
    @Test
    func metricsCalculationsAreCorrect() {
        let store = AnalyticsStore()
        store.clearHistory()

        store.appendRecord(objectName: "Apple", materialName: "Organic", binID: .organic)
        store.appendRecord(objectName: "Can", materialName: "Metal", binID: .recyclable)
        store.appendRecord(objectName: "Wrapper", materialName: "Trash", binID: .residual)

        #expect(store.totalCount == 3)
        #expect(store.count(for: .organic) == 1)
        #expect(store.count(for: .recyclable) == 1)
        #expect(store.count(for: .residual) == 1)

        // Diversion rate = (organic 1 + recyclable 1) / 3 = 66%
        #expect(store.diversionRatePercentage == 66)

        // Recycling rate = recyclable 1 / 3 = 33%
        #expect(store.recyclingRatePercentage == 33)
    }
}
