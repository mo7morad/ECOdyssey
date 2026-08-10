import CoreGraphics
import FoundationModels
import SortingKit

/// Identifies items with the on-device language model, using the image directly.
///
/// This tier exists because there is no good waste-sorting training data to build a
/// classifier from — the public datasets are small and generalise poorly to a real bin.
/// A general multimodal model needs none, and it can report things a classifier cannot:
/// whether an item is greasy, whether it is a bonded composite, and what the disposal
/// instructions printed on the packaging actually say.
///
/// It is slow by comparison — seconds, not milliseconds — which is why it runs once per
/// confirmed track and never per frame.
///
/// Requires iOS 27 for image input, plus Apple Intelligence hardware. Callers must fall
/// back to `VisionKeywordPerception` when `isAvailable` is false.
@available(iOS 27, *)
public final class FoundationModelPerception: PerceptionEngine {
    public let tier: PerceptionTier = .foundationModel

    private let session: LanguageModelSession
    private let knownMaterials: Set<String>

    public static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// - Parameter knownMaterials: the material vocabulary from the active ruleset.
    ///   Anything the model returns outside this set is treated as unrecognised rather
    ///   than trusted, so a hallucinated material can never reach the policy layer.
    public init(knownMaterials: Set<MaterialID>) {
        self.knownMaterials = Set(knownMaterials.map(\.rawValue))
        self.session = LanguageModelSession(
            instructions: """
            You identify discarded items for a waste-sorting station.

            Report only what you can see. Do not guess where the item should be thrown \
            away — that decision is made elsewhere from the facts you report.

            Choose material from exactly this list: \
            \(self.knownMaterials.sorted().joined(separator: ", ")).

            Mark an item as food-soiled when it carries visible food residue, grease or \
            liquid. Mark it as composite when it bonds materials that cannot be \
            separated by hand, such as a paper cup with a plastic lining.

            If packaging shows disposal wording or a resin code, report it verbatim.
            """
        )
    }

    /// Warms the model so the first person at the bin does not wait noticeably longer
    /// than everyone after them.
    public func prewarm() {
        session.prewarm()
    }

    public func perceive(_ frame: PerceptionFrame) async throws -> ItemPerception {
        let response = try await session.respond(generating: ObservedItem.self) {
            "Identify this discarded item."
            Attachment(frame.croppedImage())
        }
        let observed = response.content

        // The model returns a string; only materials the ruleset knows are trusted.
        // An unknown value yields no material, which the policy reports as uncertain
        // rather than silently sorting the item somewhere plausible-looking.
        let materials = knownMaterials.contains(observed.material)
            ? [MaterialObservation(materialID: MaterialID(rawValue: observed.material), confidence: observed.confidence)]
            : []

        return ItemPerception(
            itemName: observed.itemName,
            materials: materials,
            isFoodSoiled: observed.isFoodSoiled,
            isComposite: observed.isComposite,
            printedDisposalHint: observed.printedDisposalHint,
            tier: .foundationModel
        )
    }
}

/// The structured answer requested from the model.
@available(iOS 27, *)
@Generable
struct ObservedItem {
    @Guide(description: "Short common name for the item, such as 'plastic water bottle'.")
    let itemName: String

    @Guide(description: "The item's primary material, chosen from the allowed list.")
    let material: String

    @Guide(description: "How sure you are about the material, from 0.0 to 1.0.")
    let confidence: Double

    @Guide(description: "True when the item carries visible food residue, grease or liquid.")
    let isFoodSoiled: Bool

    @Guide(description: "True when the item bonds materials that cannot be separated by hand.")
    let isComposite: Bool

    @Guide(description: "Disposal wording or resin code printed on the item, verbatim. Empty when none is visible.")
    let printedDisposalHint: String
}
