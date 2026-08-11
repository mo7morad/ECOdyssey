import SwiftUI
import PhotosUI
import CoreVideo

@MainActor
@Observable
public final class LiveScannerViewModel {
    public var trackedItems: [TrackedItem] = []
    public var activePerception: ItemPerception?
    public var activeBin: Bin?
    public var selectedGalleryImage: UIImage?
    public var isVoiceEnabled: Bool = true
    public var isProcessing: Bool = false
    public var isAnalyticsSheetPresented: Bool = false

    private let perceptionEngine = VisualPerceptionEngine()
    private var itemTracker = ItemTracker()
    private let speechAnnouncer = SpeechAnnouncer()
    private let analyticsStore = AnalyticsStore.shared

    public init() {}

    public func processFrameBuffer(_ pixelBuffer: CVPixelBuffer) {
        guard selectedGalleryImage == nil, !isProcessing else { return }
        isProcessing = true

        Task {
            do {
                let items = try await perceptionEngine.analyzeTrackedObjects(in: pixelBuffer)
                self.handleDetectedItems(items)
            } catch {
                self.isProcessing = false
            }
        }
    }

    public func processSelectedImage(_ image: UIImage) {
        selectedGalleryImage = image
        trackedItems = []
        activePerception = nil
        activeBin = nil
        isProcessing = true

        Task {
            do {
                let (perception, binID) = try await perceptionEngine.analyzeImage(image)
                self.handleStaticAnalysis(perception: perception, binID: binID)
            } catch {
                self.isProcessing = false
            }
        }
    }

    public func resumeLiveCamera() {
        selectedGalleryImage = nil
        activePerception = nil
        activeBin = nil
        trackedItems = []
        itemTracker.reset()
    }

    private func handleDetectedItems(_ items: [TrackedItem]) {
        guard selectedGalleryImage == nil else {
            isProcessing = false
            return
        }
        trackedItems = items
        if let primary = items.first {
            activePerception = primary.perception
            let bin = Bin.resolve(primary.assignedBinID)
            activeBin = bin
            recordAndAnnounce(
                id: primary.id,
                label: primary.perception.classificationLabel,
                material: primary.perception.materialName,
                bin: bin
            )
        }
        isProcessing = false
    }

    private func handleStaticAnalysis(perception: ItemPerception, binID: BinID) {
        activePerception = perception
        let bin = Bin.resolve(binID)
        activeBin = bin
        isProcessing = false
        analyticsStore.appendRecord(
            objectName: perception.classificationLabel,
            materialName: perception.materialName,
            binID: binID
        )
        if isVoiceEnabled {
            speechAnnouncer.announceIfNeeded(
                "\(perception.classificationLabel). \(bin.spokenText)",
                force: true
            )
        }
    }

    private func recordAndAnnounce(id: String, label: String, material: String, bin: Bin) {
        let isFirstSeen = itemTracker.track(id: id)
        if isFirstSeen {
            analyticsStore.appendRecord(
                objectName: label,
                materialName: material,
                binID: bin.id
            )
        }
        if isVoiceEnabled {
            speechAnnouncer.announceIfNeeded("\(label). \(bin.spokenText)")
        }
    }
}
