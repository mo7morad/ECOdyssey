import CoreGraphics
import Foundation
import ImageIO

/// Decodes encoded image data into an upright, size-bounded `CGImage` for perception.
///
/// Two corrections that every image reaching a perception tier needs, and that used to be
/// applied on the photo-library path but not the live one — which is exactly why the same
/// item was identified reliably from the gallery and unreliably when held up to the camera.
///
/// **Rotation.** A photograph records its orientation in EXIF rather than in its pixels.
/// Left unapplied, a portrait-mounted station hands the model an item lying on its side,
/// and both tiers read a rotated item markedly worse.
///
/// **Size.** A full-resolution capture buys latency rather than detail on an item that
/// already fills the frame.
public enum UprightImageDecoder {
    public enum DecodingError: Error {
        case unreadableImageData
        case undecodableImage
    }

    /// Longest edge handed to perception.
    public static let maximumPixelSize = 1536

    /// For an image in memory: a still just captured, or a picked library photo.
    public static func decode(_ encodedImage: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(encodedImage as CFData, nil) else {
            throw DecodingError.unreadableImageData
        }
        return try decode(source)
    }

    /// For an image still on disk, so a file is not read into memory twice.
    public static func decode(_ source: CGImageSource) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]
        guard let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw DecodingError.undecodableImage
        }
        return decoded
    }
}
