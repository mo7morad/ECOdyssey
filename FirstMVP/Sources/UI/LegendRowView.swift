import SwiftUI

public struct LegendRowView: View {
    public let bulletColor: Color
    public let labelText: String
    public let itemCount: Int
    public let totalCount: Int

    public init(
        bulletColor: Color,
        labelText: String,
        itemCount: Int,
        totalCount: Int
    ) {
        self.bulletColor = bulletColor
        self.labelText = labelText
        self.itemCount = itemCount
        self.totalCount = totalCount
    }

    private var percentage: Int {
        totalCount > 0 ? Int((Double(itemCount) / Double(totalCount)) * 100.0) : 0
    }

    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(bulletColor)
                .frame(width: 8, height: 8)
            Text(labelText)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 4)
            Text("\(itemCount) (\(percentage)%)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}
