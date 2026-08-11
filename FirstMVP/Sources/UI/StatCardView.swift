import SwiftUI

public struct StatCardView: View {
    public let titleText: String
    public let valueText: String
    public let systemIconName: String
    public let accentColor: Color

    public init(
        titleText: String,
        valueText: String,
        systemIconName: String,
        accentColor: Color
    ) {
        self.titleText = titleText
        self.valueText = valueText
        self.systemIconName = systemIconName
        self.accentColor = accentColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: systemIconName)
                    .foregroundColor(accentColor)
                Text(titleText)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Text(valueText)
                .font(.title2)
                .fontWeight(.heavy)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
}
