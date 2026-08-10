import Foundation

public struct HourlyBucket: Sendable, Equatable {
    public let hour: Int
    public let count: Int

    public init(hour: Int, count: Int) {
        self.hour = hour
        self.count = count
    }
}

public struct ThroughputSeries: Sendable, Equatable {
    public let buckets: [HourlyBucket]

    public init(buckets: [HourlyBucket]) {
        self.buckets = buckets
    }

    public init(events: [ScanEvent]) {
        var countsByHour = [Int: Int]()
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        for event in events {
            let hour = calendar.component(.hour, from: event.occurredAt)
            countsByHour[hour, default: 0] += 1
        }

        var buckets: [HourlyBucket] = []
        for hour in 0..<24 {
            buckets.append(HourlyBucket(hour: hour, count: countsByHour[hour, default: 0]))
        }
        self.buckets = buckets
    }
}
