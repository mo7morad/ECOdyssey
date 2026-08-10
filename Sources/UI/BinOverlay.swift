import SortingKit
import SwiftUI

/// Draws a box around each item the presence tier is currently following.
struct BinOverlay: View {
    let boxes: [TrackedBox]
    /// Colours the boxes once a decision is in; grey while the item is still being read.
    let highlight: Bin?
    /// Converts Vision's normalised coordinates into view coordinates. Supplied by the
    /// preview layer, because the preview crops to fill and a plain multiply would put
    /// every box in the wrong place.
    let mapBox: (CGRect) -> CGRect

    var body: some View {
        Canvas { context, _ in
            let stroke = highlight.map { Color(hex: $0.colorHex) } ?? .white.opacity(0.6)

            for box in boxes {
                let frame = mapBox(box.boundingBox)
                context.stroke(
                    Path(roundedRect: frame, cornerRadius: 12),
                    with: .color(stroke),
                    lineWidth: 3
                )
            }
        }
        .allowsHitTesting(false)
        .animation(.snappy, value: boxes)
    }
}
