import CoreGraphics
import SortingKit
import Vision

/// Identifies items with Vision's general-purpose image classifier and the ruleset's
/// keyword hints.
///
/// This is the tier that runs wherever the on-device language model is not available —
/// on iOS 26, on hardware without Apple Intelligence, and whenever the user has turned
/// it off. It is not a stub: for many devices it is the shipping behaviour, so its
/// keyword table in `DefaultRuleset.json` deserves real attention.
///
/// Its ceiling is real, though. Vision's labels describe what an object *is*
/// ("water bottle"), never its condition, so this tier cannot tell clean cardboard from
/// a greasy pizza box and always reports items as unsoiled.
public final class VisionKeywordPerception: PerceptionEngine {
    public let tier: PerceptionTier = .visionKeyword

    private let keywordHints: [String: [String]]
    private let minimumLabelConfidence: Float

    /// - Parameter minimumLabelConfidence: labels below this are discarded before
    ///   keyword matching. Vision emits a long tail of low-confidence guesses, and
    ///   letting those through is how a toucan becomes an aluminium can.
    public init(keywordHints: [String: [String]], minimumLabelConfidence: Float = 0.15) {
        self.keywordHints = keywordHints
        self.minimumLabelConfidence = minimumLabelConfidence
    }

    public func perceive(_ frame: PerceptionFrame) async throws -> ItemPerception {
        let request = VNClassifyImageRequest()
        try VNImageRequestHandler(cgImage: frame.croppedImage(), options: [:]).perform([request])

        let labels = (request.results ?? [])
            .filter { $0.confidence >= minimumLabelConfidence }
            .map { (identifier: $0.identifier, confidence: Double($0.confidence)) }

        return ItemPerception(
            itemName: labels.first.map(Self.humanReadable) ?? "Unrecognised item",
            materials: KeywordMatcher.findMaterials(from: labels, using: keywordHints),
            isFoodSoiled: false,
            isComposite: false,
            printedDisposalHint: nil,
            tier: .visionKeyword
        )
    }

    private static func humanReadable(_ label: (identifier: String, confidence: Double)) -> String {
        label.identifier.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
