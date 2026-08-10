import Foundation

public struct BinShare: Sendable, Equatable {
    public let binID: BinID
    public let count: Int
    public let percentage: Int

    public init(binID: BinID, count: Int, percentage: Int) {
        self.binID = binID
        self.count = count
        self.percentage = percentage
    }
}

public struct AnalyticsSummary: Sendable, Equatable {
    public let totalCount: Int
    public let diversionRatePercent: Int
    public let recyclingRatePercent: Int
    public let uncertaintyRatePercent: Int
    public let binShares: [BinShare]

    public init(
        totalCount: Int,
        diversionRatePercent: Int,
        recyclingRatePercent: Int,
        uncertaintyRatePercent: Int,
        binShares: [BinShare]
    ) {
        self.totalCount = totalCount
        self.diversionRatePercent = diversionRatePercent
        self.recyclingRatePercent = recyclingRatePercent
        self.uncertaintyRatePercent = uncertaintyRatePercent
        self.binShares = binShares
    }
}

public extension AnalyticsSummary {
    init(
        events: [ScanEvent],
        knownBinIDs: Set<BinID>,
        diversionBinIDs: Set<BinID>,
        recyclingBinIDs: Set<BinID>
    ) {
        let totalCount = events.count
        guard totalCount > 0 else {
            self.init(
                totalCount: 0,
                diversionRatePercent: 0,
                recyclingRatePercent: 0,
                uncertaintyRatePercent: 0,
                binShares: []
            )
            return
        }

        var countsByBinID: [BinID: Int] = [:]
        var diversionCount = 0
        var recyclingCount = 0
        var uncertainCount = 0

        for event in events {
            let actualBinID = knownBinIDs.contains(event.binID) ? event.binID : BinID(rawValue: "retired")
            countsByBinID[actualBinID, default: 0] += 1

            if diversionBinIDs.contains(event.binID) {
                diversionCount += 1
            }
            if recyclingBinIDs.contains(event.binID) {
                recyclingCount += 1
            }
            if event.outcome == .uncertain {
                uncertainCount += 1
            }
        }

        self.init(
            totalCount: totalCount,
            diversionRatePercent: Int(round(Double(diversionCount) / Double(totalCount) * 100)),
            recyclingRatePercent: Int(round(Double(recyclingCount) / Double(totalCount) * 100)),
            uncertaintyRatePercent: Int(round(Double(uncertainCount) / Double(totalCount) * 100)),
            binShares: Self.computeBinShares(countsByBinID: countsByBinID, totalCount: totalCount)
        )
    }

    private static func computeBinShares(countsByBinID: [BinID: Int], totalCount: Int) -> [BinShare] {
        struct BinShareTemp {
            let binID: BinID
            let count: Int
            var percentage: Int
            let remainder: Double
        }

        var tempShares: [BinShareTemp] = []
        var totalPercentage = 0

        for (binID, count) in countsByBinID {
            let exactShare = (Double(count) / Double(totalCount)) * 100.0
            let floorShare = Int(floor(exactShare))
            let remainder = exactShare - Double(floorShare)

            tempShares.append(BinShareTemp(binID: binID, count: count, percentage: floorShare, remainder: remainder))
            totalPercentage += floorShare
        }

        tempShares.sort { $0.remainder > $1.remainder }

        let deficit = 100 - totalPercentage
        for i in 0..<min(deficit, tempShares.count) {
            tempShares[i].percentage += 1
        }

        return tempShares.map { BinShare(binID: $0.binID, count: $0.count, percentage: $0.percentage) }
    }
}
