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

    private var lockedItem: TrackedItem?
    private var candidateItem: TrackedItem?
    private var candidateFramesCount = 0
    private let framesToLock = 5

    public func resumeLiveCamera() {
        selectedGalleryImage = nil
        activePerception = nil
        activeBin = nil
        trackedItems = []
        itemTracker.reset()
        lockedItem = nil
        candidateItem = nil
        candidateFramesCount = 0
    }

    private func handleDetectedItems(_ items: [TrackedItem]) {
        guard selectedGalleryImage == nil else {
            isProcessing = false
            return
        }
        trackedItems = items
        
        if let primary = items.first {
            let currentLabel = primary.perception.classificationLabel
            
            if lockedItem == nil {
                updateCandidate(with: primary)
            } else if let locked = lockedItem, locked.perception.classificationLabel == currentLabel {
                candidateItem = nil
                candidateFramesCount = 0
                lockedItem = primary
                updateActiveState(with: primary)
            } else {
                updateCandidate(with: primary)
            }
        } else {
            candidateItem = nil
            candidateFramesCount = 0
        }
        
        isProcessing = false
    }
    
    private func updateCandidate(with item: TrackedItem) {
        if candidateItem?.perception.classificationLabel == item.perception.classificationLabel {
            candidateFramesCount += 1
        } else {
            candidateItem = item
            candidateFramesCount = 1
        }
        
        if candidateFramesCount >= framesToLock {
            lockedItem = item
            updateActiveState(with: item)
            candidateItem = nil
            candidateFramesCount = 0
        }
    }
    
    private func updateActiveState(with item: TrackedItem) {
        let isNewLock = activePerception?.classificationLabel != item.perception.classificationLabel
        
        activePerception = item.perception
        let bin = Bin.resolve(item.assignedBinID)
        activeBin = bin
        
        if isNewLock {
            recordAndAnnounce(
                id: item.id,
                label: item.perception.classificationLabel,
                material: item.perception.materialName,
                bin: bin
            )
        }
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
