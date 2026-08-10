import CoreGraphics

/// One item found in one frame by the presence tier.
public struct Detection: Sendable, Equatable {
    /// Normalised 0…1, in Vision's coordinate space (origin bottom-left).
    public let boundingBox: CGRect

    /// How good this frame is as material to hand to perception, 0…1.
    ///
    /// Named for what it measures rather than how it is measured: the presence tier
    /// picks the proxy. A detector that cannot estimate quality must report a varying
    /// value or best-frame selection silently degrades to "whichever frame came first",
    /// which is usually the blurriest.
    public let quality: Double

    public init(boundingBox: CGRect, quality: Double) {
        self.boundingBox = boundingBox
        self.quality = quality
    }
}
