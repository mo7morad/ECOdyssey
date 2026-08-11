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
    private let hazardHints: [String: [String]]
    private let minimumLabelConfidence: Float

    /// - Parameter minimumLabelConfidence: labels below this are discarded before
    ///   keyword matching. It only has to clear Vision's noise floor, not establish
    ///   trust — the keyword table already refuses to match anything outside the waste
    ///   vocabulary, and the policy applies the real confidence bar afterwards. Set at
    ///   0.15 this threw away most correct answers: Vision's general classifier scores
    ///   a plainly-visible drink can around 0.1, and the whole frame went unrecognised.
    public init(
        keywordHints: [String: [String]],
        hazardHints: [String: [String]],
        minimumLabelConfidence: Float = 0.02
    ) {
        self.keywordHints = keywordHints
        self.hazardHints = hazardHints
        self.minimumLabelConfidence = minimumLabelConfidence
    }

    public func perceive(_ frame: PerceptionFrame) async throws -> ItemPerception {
        let request = VNClassifyImageRequest()
        try VNImageRequestHandler(cgImage: frame.image, options: [:]).perform([request])

        let labels = (request.results ?? [])
            .filter { $0.confidence >= minimumLabelConfidence }
            .map { (identifier: $0.identifier, confidence: Double($0.confidence)) }

        return ItemPerception(
            itemName: labels.first.map(Self.humanReadable) ?? "Unrecognised item",
            materials: KeywordMatcher.findMaterials(from: labels, using: keywordHints),
            isFoodSoiled: false,
            isComposite: false,
            // Hazards are the one fact this tier must not give up on. It cannot judge
            // grease or bonding, but a battery it fails to flag ends up in a bin, and
            // the keyword table can recognise one perfectly well.
            hazardClass: KeywordMatcher.findHazard(from: labels, using: hazardHints),
            isEmpty: nil,
            printedDisposalHint: nil,
            tier: .visionKeyword
        )
    }

    private static func humanReadable(_ label: (identifier: String, confidence: Double)) -> String {
        label.identifier.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
