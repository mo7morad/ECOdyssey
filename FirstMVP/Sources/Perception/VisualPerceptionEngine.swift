import Foundation
import UIKit
import Vision
import CoreImage

public enum VisualPerceptionError: Error, LocalizedError {
    case invalidImageFormat
    case classificationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidImageFormat:
            return "Provided image does not contain a valid CGImage format."
        case .classificationFailed(let reason):
            return "Classification failed: \(reason)"
        }
    }
}

public struct VisualPerceptionEngine: Sendable {
    private let policy = SortingPolicy()

    public init() {}

    public func analyzeImage(_ image: UIImage) async throws -> (ItemPerception, BinID) {
        guard let cgImage = image.cgImage else {
            throw VisualPerceptionError.invalidImageFormat
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        return try await performClassification(using: handler)
    }

    public func analyzeBuffer(_ pixelBuffer: CVPixelBuffer) async throws -> (ItemPerception, BinID) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        return try await performClassification(using: handler)
    }

    public func analyzeTrackedObjects(in pixelBuffer: CVPixelBuffer) async throws -> [TrackedItem] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        if #available(iOS 17.0, *) {
            if let items = try? await extractAndClassifyMaskedItems(using: handler, from: pixelBuffer) {
                return items
            }
        }

        // Fallback for older iOS versions or if masking fails
        let (perception, binID) = try await performClassification(using: handler)
        let defaultBox = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        let item = TrackedItem(
            id: "item_0",
            boundingBox: defaultBox,
            perception: perception,
            assignedBinID: binID
        )
        return [item]
    }

    @available(iOS 17.0, *)
    private func extractAndClassifyMaskedItems(
        using handler: VNImageRequestHandler,
        from originalBuffer: CVPixelBuffer
    ) async throws -> [TrackedItem]? {
        let maskRequest = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([maskRequest])
        guard let observation = maskRequest.results?.first else { return nil }

        let instances = observation.allInstances
        let trackedCount = min(instances.count, 3)
        var items: [TrackedItem] = []

        let maskBuffer = observation.instanceMask

        for index in 0..<trackedCount {
            let instanceID = Array(instances)[index]
            
            // 1. Calculate precise bounding box from the mask
            let box = calculateBoundingBox(for: instanceID, in: maskBuffer)
            
            // 2. Generate a clean, isolated image of just this instance
            let instancesSet = IndexSet(integer: instanceID)
            guard let maskedPixelBuffer = try? observation.generateMaskedImage(
                ofInstances: instancesSet,
                from: handler,
                croppedToInstancesExtent: true
            ) else { continue }
            
            // 3. Classify the isolated image
            let instanceHandler = VNImageRequestHandler(cvPixelBuffer: maskedPixelBuffer, options: [:])
            if let (perception, binID) = try? await performClassification(using: instanceHandler) {
                let tracked = TrackedItem(
                    id: "item_\(instanceID)",
                    boundingBox: box,
                    perception: perception,
                    assignedBinID: binID
                )
                items.append(tracked)
            }
        }
        return items.isEmpty ? nil : items
    }

    private func calculateBoundingBox(for instanceID: Int, in maskBuffer: CVPixelBuffer) -> CGRect {
        CVPixelBufferLockBaseAddress(maskBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(maskBuffer)
        let height = CVPixelBufferGetHeight(maskBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(maskBuffer) else { return .zero }
        
        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0
        
        let format = CVPixelBufferGetPixelFormatType(maskBuffer)
        if format == kCVPixelFormatType_OneComponent8 {
            let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
            for y in 0..<height {
                let row = buffer.advanced(by: y * bytesPerRow)
                for x in 0..<width {
                    if row[x] == UInt8(instanceID) {
                        if x < minX { minX = x }
                        if x > maxX { maxX = x }
                        if y < minY { minY = y }
                        if y > maxY { maxY = y }
                    }
                }
            }
        }
        
        if minX > maxX || minY > maxY {
            return CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        }
        
        // Convert to normalized coordinates (0.0 to 1.0)
        // Vision's coordinate system origin is bottom-left
        let normalizedX = CGFloat(minX) / CGFloat(width)
        let normalizedY = 1.0 - (CGFloat(maxY) / CGFloat(height))
        let normalizedWidth = CGFloat(maxX - minX) / CGFloat(width)
        let normalizedHeight = CGFloat(maxY - minY) / CGFloat(height)
        
        return CGRect(x: normalizedX, y: normalizedY, width: normalizedWidth, height: normalizedHeight)
    }

    private func performClassification(using handler: VNImageRequestHandler) async throws -> (ItemPerception, BinID) {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { req, error in
                self.handleClassificationResults(req: req, error: error, continuation: continuation)
            }
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func handleClassificationResults(
        req: VNRequest,
        error: Error?,
        continuation: CheckedContinuation<(ItemPerception, BinID), Error>
    ) {
        if let error = error {
            let err = VisualPerceptionError.classificationFailed(error.localizedDescription)
            continuation.resume(throwing: err)
            return
        }
        guard let results = req.results as? [VNClassificationObservation], !results.isEmpty else {
            let err = VisualPerceptionError.classificationFailed("No observations found.")
            continuation.resume(throwing: err)
            return
        }
        
        // Apply a strict confidence threshold to eliminate background guesses
        let confidentResults = results.filter { $0.confidence > 0.4 }
        let targetResults = confidentResults.isEmpty ? Array(results.prefix(1)) : confidentResults
        
        let perception = buildPerception(from: targetResults)
        continuation.resume(returning: (perception, policy.resolveBinID(for: perception)))
    }

    private func buildPerception(from observations: [VNClassificationObservation]) -> ItemPerception {
        let topObservation = observations.first
        let rawLabel = topObservation?.identifier ?? "Unknown Object"
        let topLabel = rawLabel.replacingOccurrences(of: "_", with: " ").capitalized
        let confidence = topObservation?.confidence ?? 0.0
        let material = deriveMaterialName(from: observations)
        let details = observations.prefix(3)
            .map { observation -> String in
                let cleanLabel = observation.identifier.replacingOccurrences(of: "_", with: " ").capitalized
                let percentage = Int(observation.confidence * 100)
                return "• \(cleanLabel) (\(percentage)%)"
            }
            .joined(separator: "\n")

        return ItemPerception(
            classificationLabel: topLabel,
            materialName: material,
            confidenceScore: confidence,
            detailSummary: details.isEmpty ? "• Unrecognized (Low Confidence)" : details
        )
    }

    private func deriveMaterialName(from observations: [VNClassificationObservation]) -> String {
        let labels = observations.prefix(3).map { $0.identifier.lowercased() }

        if containsAny(labels: labels, keywords: SortingPolicy.organicKeywords) {
            return "Organic / Food Scraps 🍌"
        }
        if containsAny(labels: labels, keywords: SortingPolicy.b3Keywords) {
            return "Hazardous / B3 🔋"
        }
        if containsAny(labels: labels, keywords: SortingPolicy.paperKeywords) {
            return "Paper / Cardboard 📦"
        }
        if containsAny(labels: labels, keywords: SortingPolicy.anorganicKeywords) {
            return "Inorganic / Recyclable 🧴"
        }
        
        return "Residual / General Trash 🗑️"
    }

    private func containsAny(labels: [String], keywords: Set<String>) -> Bool {
        labels.contains { label in
            keywords.contains { label.contains($0) }
        }
    }
}
