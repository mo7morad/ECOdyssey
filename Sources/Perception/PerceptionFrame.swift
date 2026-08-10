import CoreGraphics
import SortingKit

/// One item, isolated from the frame it was seen in, ready for perception.
public struct PerceptionFrame: Sendable {
    public let image: CGImage
    /// Normalised, in Vision's coordinate space (origin bottom-left).
    public let boundingBox: CGRect

    public init(image: CGImage, boundingBox: CGRect) {
        self.image = image
        self.boundingBox = boundingBox
    }

    /// The item cropped out of the frame.
    ///
    /// Vision's origin is bottom-left and `CGImage`'s is top-left, so the box is
    /// flipped vertically on the way in. Falls back to the full frame when the crop
    /// cannot be made, since a whole-frame guess beats no answer at all.
    public func croppedImage() -> CGImage {
        let pixelRect = CGRect(
            x: boundingBox.minX * CGFloat(image.width),
            y: (1 - boundingBox.maxY) * CGFloat(image.height),
            width: boundingBox.width * CGFloat(image.width),
            height: boundingBox.height * CGFloat(image.height)
        )
        return image.cropping(to: pixelRect) ?? image
    }
}

/// Turns a picture of one item into facts about it.
///
/// Two implementations exist: the on-device language model where it is available, and
/// a Vision classifier everywhere else. Neither ever returns a bin — that is policy.
public protocol PerceptionEngine: Sendable {
    var tier: PerceptionTier { get }
    func perceive(_ frame: PerceptionFrame) async throws -> ItemPerception
}
