import CoreGraphics
import Darwin
import FoundationModels
import SortingKit
import Vision

/// Identifies items with the on-device language model, using the image directly.
///
/// This tier exists because there is no good waste-sorting training data to build a
/// classifier from — the public datasets are small and generalise poorly to a real bin.
/// A general multimodal model needs none, and it can report things a classifier cannot:
/// whether an item is greasy, whether it is a bonded composite, whether a battery is
/// involved, and what the disposal instructions printed on the packaging actually say.
///
/// It is slow by comparison — seconds, not milliseconds — which is why it runs once per
/// confirmed track and never per frame.
///
/// Two separate things have to be true before this tier can run, and neither implies the
/// other: Apple Intelligence has to be supported and switched on, *and* the running OS
/// has to actually ship the image-attachment API. Callers fall back to
/// `VisionKeywordPerception` when `isAvailable` is false.
public final class FoundationModelPerception: PerceptionEngine {
    public let tier: PerceptionTier = .foundationModel

    private let session: LanguageModelSession
    private let knownMaterials: Set<String>
    private let knownHazardClasses: Set<String>

    /// Deterministic decoding. This is a classification task, not a writing task: the
    /// same photo should produce the same bin twice running, and sampling makes an
    /// evaluation score wobble for reasons that have nothing to do with the ruleset.
    private static let generationOptions = GenerationOptions(samplingMode: .greedy)

    public static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable && isImageInputLinked
    }

    /// Why the model is unavailable, for the startup screen to show.
    ///
    /// A station that silently drops to the keyword tier looks identical to one working
    /// correctly, except that it is much worse at its job. Naming the reason is what
    /// makes that diagnosable from across the room.
    public static var unavailabilityReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return isImageInputLinked ? nil : "This build of iOS does not provide image input to the on-device model."
        case .unavailable(.deviceNotEligible):
            return "This device does not support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is switched off in Settings."
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading."
        case .unavailable:
            return "The on-device model is unavailable."
        }
    }

    /// Whether the running OS actually ships the image-attachment API.
    ///
    /// Compiling against an SDK that declares `Attachment(_: CGImage, orientation:)` does
    /// not mean the device exports it: shipping iOS 27 builds are routinely *newer* than
    /// the SDK yet still lack it, so neither `#available(iOS 27, *)` nor the deployment
    /// target answers this question — only the symbol does.
    ///
    /// This check is load-bearing in two places. FoundationModels is linked with
    /// `-weak_framework` (see OTHER_LDFLAGS) so that a missing symbol resolves to null
    /// instead of failing the whole process at launch in dyld; this then stops anything
    /// from calling through that null pointer, which would be an uncatchable
    /// `EXC_BAD_ACCESS`. Removing either half crashes the app on launch on real hardware.
    private static var isImageInputLinked: Bool {
        let anyLoadedImage = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        return dlsym(anyLoadedImage, imageAttachmentInitialiser) != nil
    }

    /// Mangled `Attachment.init(_: CGImage, orientation:)`, the one symbol `perceive`
    /// needs that the shipping framework does not always export.
    private static let imageAttachmentInitialiser = """
        $s16FoundationModels10AttachmentVA2A05ImageC7ContentVRszrlE_11orientation\
        ACyAEGSo10CGImageRefa_So0G19PropertyOrientationVSgtcfC
        """

    /// - Parameters:
    ///   - knownMaterials: the material vocabulary from the active ruleset.
    ///   - knownHazardClasses: the hazard vocabulary from the active ruleset.
    ///
    /// Anything the model returns outside these sets is treated as unrecognised rather
    /// than trusted, so a hallucinated material or an invented hazard can never reach
    /// the policy layer.
    public init(knownMaterials: Set<MaterialID>, knownHazardClasses: Set<HazardClass>) {
        self.knownMaterials = Set(knownMaterials.map(\.rawValue))
        self.knownHazardClasses = Set(knownHazardClasses.map(\.rawValue))
        self.session = LanguageModelSession(
            // Vision's own OCR and barcode readers, callable by the model. Packaging text
            // is exactly what a general model reads worst and what settles real items:
            // resin codes, "dapat didaur ulang", store drop-off wording. Given the tool,
            // the model stops guessing at blurry small print and just reads it.
            tools: [
                OCRTool(description: """
                    Read text printed on the item: disposal instructions, recycling \
                    symbols, resin codes (1-7), material names, or wording \
                    such as "recyclable" or "compostable".
                    """),
                BarcodeReaderTool()
            ],
            instructions: Self.instructions(
                materials: self.knownMaterials,
                hazards: self.knownHazardClasses
            )
        )
    }

    private static func instructions(materials: Set<String>, hazards: Set<String>) -> String {
        """
        You identify discarded items for a waste-sorting station.

        Report only what you can see. Do not guess where the item should be thrown \
        away — that decision is made elsewhere from the facts you report.

        Give itemName in English, as a short everyday name such as "plastic bottle" \
        or "pizza box".

        Choose material from exactly this list: \(materials.sorted().joined(separator: ", ")).

        Always choose the closest material on that list rather than leaving it blank. \
        When the item genuinely matches none of them, answer general_waste with a low \
        confidence — that is a useful answer, an empty one is not.

        Set hazardClass to one of: \(hazards.sorted().joined(separator: ", ")) — or \
        "none" when the item is ordinary waste. Batteries, vapes, power banks, phones, \
        chargers, cables, light bulbs, aerosol cans, paint, pesticide, medicines and \
        needles are never ordinary waste. When in doubt between "none" and a hazard, \
        say the hazard: a battery in the wrong bin starts a fire.

        Mark an item as food-soiled when it carries visible food residue, grease or \
        liquid. Mark it as composite when it bonds materials that cannot be separated \
        by hand, such as a paper cup with a plastic lining — report the material you \
        actually see and set isComposite, rather than changing the material.

        Set emptiness to "empty" for a container you can see is emptied, "hasContents" \
        when something is still inside, and "unclear" when you cannot tell. Do not \
        guess "empty" for an opaque container.

        If packaging shows disposal wording or a resin code, use the OCR tool to read \
        it and report it verbatim.
        """
    }

    /// Warms the model so the first person at the bin does not wait noticeably longer
    /// than everyone after them.
    public func prewarm() {
        session.prewarm()
    }

    public func perceive(_ frame: PerceptionFrame) async throws -> ItemPerception {
        let response = try await session.respond(
            generating: ObservedItem.self,
            options: Self.generationOptions
        ) {
            "Identify this discarded item."
            // Labelled because that is how the model addresses an image when it decides
            // to call OCR or the barcode reader. Without a label the tools above are
            // attached but unreachable.
            Attachment(frame.image).label("item")
        }

        return itemPerception(from: response.content)
    }

    private func itemPerception(from observed: ObservedItem) -> ItemPerception {
        // The model returns strings; only values the ruleset knows are trusted. An
        // unknown one yields nothing, which the policy reports as uncertain rather than
        // silently sorting the item somewhere plausible-looking.
        let materials = knownMaterials.contains(observed.material)
            ? [MaterialObservation(materialID: MaterialID(rawValue: observed.material), confidence: observed.confidence)]
            : []
        let hazardClass = knownHazardClasses.contains(observed.hazardClass)
            ? HazardClass(rawValue: observed.hazardClass)
            : nil

        return ItemPerception(
            itemName: observed.itemName,
            materials: materials,
            isFoodSoiled: observed.isFoodSoiled,
            isComposite: observed.isComposite,
            hazardClass: hazardClass,
            isEmpty: observed.isEmptied,
            printedDisposalHint: observed.printedDisposalHint.isEmpty ? nil : observed.printedDisposalHint,
            tier: .foundationModel
        )
    }
}

/// The structured answer requested from the model.
@Generable
struct ObservedItem {
    @Guide(description: "Short everyday name for the item in English, such as 'plastic bottle'.")
    let itemName: String

    @Guide(description: "The item's primary material, chosen from the allowed list.")
    let material: String

    @Guide(description: "How sure you are about the material, from 0.0 to 1.0.")
    let confidence: Double

    @Guide(description: "True when the item carries visible food residue, grease or liquid.")
    let isFoodSoiled: Bool

    @Guide(description: "True when the item bonds materials that cannot be separated by hand.")
    let isComposite: Bool

    @Guide(description: "The hazard class from the allowed list, or 'none' for ordinary waste.")
    let hazardClass: String

    @Guide(description: "Whether the container is emptied: 'empty', 'hasContents', or 'unclear'.")
    let emptiness: String

    @Guide(description: "Disposal wording or resin code printed on the item, verbatim. Empty when none is visible.")
    let printedDisposalHint: String

    /// `nil` when the model could not tell, which is a different thing from empty and
    /// must stay different — a rule requiring an emptied container should not fire on
    /// an opaque tub nobody could see inside.
    var isEmptied: Bool? {
        switch emptiness {
        case "empty": true
        case "hasContents": false
        default: nil
        }
    }
}
