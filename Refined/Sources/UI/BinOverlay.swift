import SortingKit
import SwiftUI

/// Draws a box around each item the presence tier is currently following.
struct BinOverlay: View {
    let boxes: [TrackedBox]
    let highlight: Bin?
    let mapBox: (CGRect) -> CGRect

    var body: some View {
        Canvas { context, size in
            let strokeColor = highlight.map { Color(hex: $0.colorHex) } ?? .white

            // Background Noise Reduction: Dim everything outside the object bounding boxes
            if !boxes.isEmpty {
                var dimPath = Path(CGRect(origin: .zero, size: size))
                for box in boxes {
                    let frame = mapBox(box.boundingBox)
                    guard !frame.isEmpty, frame.width > 0, frame.height > 0 else { continue }
                    dimPath.addPath(Path(roundedRect: frame, cornerRadius: 16))
                }

                let dimOpacity = highlight != nil ? 0.60 : 0.40
                context.fill(
                    dimPath,
                    with: .color(Color.black.opacity(dimOpacity)),
                    style: FillStyle(eoFill: true)
                )
            }

            for box in boxes {
                let frame = mapBox(box.boundingBox)
                guard !frame.isEmpty, frame.width > 0, frame.height > 0 else { continue }
                
                // Subtle glowing background tint for the locked box
                context.fill(
                    Path(roundedRect: frame, cornerRadius: 16),
                    with: .color(strokeColor.opacity(0.12))
                )

                // Outer aura glow when item is locked/highlighted
                if highlight != nil {
                    context.stroke(
                        Path(roundedRect: frame.insetBy(dx: -4, dy: -4), cornerRadius: 20),
                        with: .color(strokeColor.opacity(0.35)),
                        lineWidth: 6
                    )
                }

                // Main bounding border
                context.stroke(
                    Path(roundedRect: frame, cornerRadius: 16),
                    with: .color(strokeColor.opacity(0.85)),
                    lineWidth: 2.5
                )

                // Corner reticle accents
                let cornerLength = min(min(frame.width, frame.height) * 0.2, 24.0)
                let reticlePath = cornerBracketsPath(for: frame, length: cornerLength, cornerRadius: 16)
                
                context.stroke(
                    reticlePath,
                    with: .color(strokeColor),
                    lineWidth: 4
                )
            }
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: boxes)
    }

    private func cornerBracketsPath(for rect: CGRect, length: CGFloat, cornerRadius: CGFloat) -> Path {
        var path = Path()

        // Top-Left Corner
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))

        // Top-Right Corner
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        // Bottom-Right Corner
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))

        // Bottom-Left Corner
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))

        return path
    }
}
