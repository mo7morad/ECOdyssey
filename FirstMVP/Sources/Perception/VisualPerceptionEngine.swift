import Foundation
import UIKit
import Vision

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
        let (perception, binID) = try await analyzeBuffer(pixelBuffer)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        if #available(iOS 17.0, *) {
            if let items = try? extractMaskedItems(using: handler, perception: perception, binID: binID) {
                return items
            }
        }

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
    private func extractMaskedItems(
        using handler: VNImageRequestHandler,
        perception: ItemPerception,
        binID: BinID
    ) throws -> [TrackedItem]? {
        let maskRequest = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([maskRequest])
        guard let observation = maskRequest.results?.first else { return nil }

        let instances = observation.allInstances
        let trackedCount = min(instances.count, 3)
        var items: [TrackedItem] = []

        for index in 0..<trackedCount {
            let instanceID = Array(instances)[index]
            let box = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
            let tracked = TrackedItem(
                id: "item_\(instanceID)",
                boundingBox: box,
                perception: perception,
                assignedBinID: binID
            )
            items.append(tracked)
        }
        return items.isEmpty ? nil : items
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
        let perception = buildPerception(from: Array(results.prefix(20)))
        continuation.resume(returning: (perception, policy.resolveBinID(for: perception)))
    }

    private func buildPerception(from observations: [VNClassificationObservation]) -> ItemPerception {
        let topObservation = observations.first
        let rawLabel = topObservation?.identifier ?? "Object"
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
            detailSummary: details
        )
    }

    private func deriveMaterialName(from observations: [VNClassificationObservation]) -> String {
        let labels = observations.map { $0.identifier.lowercased() }

        if containsAny(labels: labels, keywords: SortingPolicy.organicKeywords) {
            return "Organic / Food Scraps 🍌"
        }
        if containsAny(labels: labels, keywords: SortingPolicy.plasticKeywords) {
            return "Plastic 🧴"
        }
        if containsAny(labels: labels, keywords: SortingPolicy.metalKeywords) {
            return "Aluminum / Metal 🥫"
        }
        if containsAny(labels: labels, keywords: SortingPolicy.paperKeywords) {
            return "Paper / Cardboard 📦"
        }
        if containsAny(labels: labels, keywords: SortingPolicy.glassKeywords) {
            return "Glass 🍾"
        }
        return "Mixed / General Trash 🗑️"
    }

    private func containsAny(labels: [String], keywords: Set<String>) -> Bool {
        labels.contains { label in
            keywords.contains { label.contains($0) }
        }
    }
}
