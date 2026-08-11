import CoreGraphics
import SortingKit

/// One photograph of one item, ready for perception.
///
/// Deliberately carries no bounding box. Perception used to be handed a crop taken from
/// a video frame around a presence box, and that crop was the single largest cause of bad
/// readings: an objectness-saliency box is coarse, is carried forward by the object
/// tracker for several frames between detections, and can drift off the item entirely.
/// Cropping to it fed a whole-scene classifier a keyhole — a bottle cropped to its label
/// is a rectangle of colour — while the same item photographed whole was read correctly
/// every time from the photo library.
///
/// Framing is now settled before this type exists: `CameraSession.captureStill()`
/// photographs the scene, and presence boxes are used for what they are actually good at,
/// which is drawing the overlay and deciding *when* to take that photograph.
public struct PerceptionFrame: Sendable {
    public let image: CGImage

    public init(image: CGImage) {
        self.image = image
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
