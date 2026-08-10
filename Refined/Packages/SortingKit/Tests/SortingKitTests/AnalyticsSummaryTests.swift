import Testing
import Foundation
@testable import SortingKit

func makeScanEvent(
    binID: BinID,
    materialID: MaterialID = "test_material",
    outcome: ScanOutcome = .sorted
) -> ScanEvent {
    ScanEvent(
        trackID: TrackID(),
        occurredAt: Date(),
        binID: binID,
        materialID: materialID,
        itemName: "Test Item",
        confidence: 0.9,
        outcome: outcome,
        perceptionTier: .visionKeyword,
        stationID: "test"
    )
}

struct AnalyticsSummaryTests {

    @Test func zeroEventsProducesZeroRatesAndNoDivideByZero() {
        let summary = AnalyticsSummary(
            events: [],
            knownBinIDs: ["organic", "recyclable", "residual"],
            diversionBinIDs: ["organic", "recyclable"],
            recyclingBinIDs: ["recyclable"]
        )
        #expect(summary.totalCount == 0)
        #expect(summary.diversionRatePercent == 0)
        #expect(summary.recyclingRatePercent == 0)
        #expect(summary.uncertaintyRatePercent == 0)
        #expect(summary.binShares.isEmpty)
    }

    @Test func percentagesSumTo100UnderLargestRemainderRounding() {
        // 3 bins with 1 event each: 33.3% each should round to sum to 100
        let events = [
            makeScanEvent(binID: "organic"),
            makeScanEvent(binID: "recyclable"),
            makeScanEvent(binID: "residual"),
        ]
        let summary = AnalyticsSummary(
            events: events,
            knownBinIDs: ["organic", "recyclable", "residual"],
            diversionBinIDs: ["organic", "recyclable"],
            recyclingBinIDs: ["recyclable"]
        )
        let totalPercent = summary.binShares.reduce(0) { $0 + $1.percentage }
        #expect(totalPercent == 100)
    }

    @Test func unknownBinIDSurfacesAsRetiredNotResidual() {
        // §6.4 regression: unknown BinID must become 'retired', never silently residual
        let events = [
            makeScanEvent(binID: "deleted_bin"),
            makeScanEvent(binID: "organic"),
        ]
        let summary = AnalyticsSummary(
            events: events,
            knownBinIDs: ["organic", "recyclable", "residual"],
            diversionBinIDs: ["organic", "recyclable"],
            recyclingBinIDs: ["recyclable"]
        )
        let retiredShare = summary.binShares.first { $0.binID == BinID(rawValue: "retired") }
        #expect(retiredShare != nil)
        #expect(retiredShare?.count == 1)
        // Must NOT appear under residual
        let residualShare = summary.binShares.first { $0.binID == BinID(rawValue: "residual") }
        #expect(residualShare == nil || residualShare?.count == 0)
    }

    @Test func diversionAndRecyclingRatesComputeCorrectly() {
        let events = [
            makeScanEvent(binID: "organic"),
            makeScanEvent(binID: "recyclable"),
            makeScanEvent(binID: "recyclable"),
            makeScanEvent(binID: "residual"),
        ]
        let summary = AnalyticsSummary(
            events: events,
            knownBinIDs: ["organic", "recyclable", "residual"],
            diversionBinIDs: ["organic", "recyclable"],
            recyclingBinIDs: ["recyclable"]
        )
        #expect(summary.diversionRatePercent == 75)  // 3/4
        #expect(summary.recyclingRatePercent == 50)   // 2/4
    }

    @Test func uncertaintyRateReflectsUncertainOutcomes() {
        let events = [
            makeScanEvent(binID: "residual", outcome: .uncertain),
            makeScanEvent(binID: "organic", outcome: .sorted),
            makeScanEvent(binID: "residual", outcome: .uncertain),
            makeScanEvent(binID: "recyclable", outcome: .sorted),
        ]
        let summary = AnalyticsSummary(
            events: events,
            knownBinIDs: ["organic", "recyclable", "residual"],
            diversionBinIDs: ["organic", "recyclable"],
            recyclingBinIDs: ["recyclable"]
        )
        #expect(summary.uncertaintyRatePercent == 50)  // 2/4
    }
}
