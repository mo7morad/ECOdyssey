import Charts
import SortingKit
import SwiftUI

/// Items counted per hour of day — the number that tells an operator when to empty
/// which bin.
struct ThroughputChart: View {
    let series: ThroughputSeries

    var body: some View {
        Chart(series.buckets, id: \.hour) { bucket in
            BarMark(
                x: .value("Hour", bucket.hour),
                y: .value("Items", bucket.count)
            )
            .foregroundStyle(Color.accentColor.gradient)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: Array(stride(from: 0, through: 24, by: 6))) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text("\(hour):00")
                    }
                }
            }
        }
    }
}
