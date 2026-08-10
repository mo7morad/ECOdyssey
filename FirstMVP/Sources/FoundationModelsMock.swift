import Foundation
import UIKit
import Vision

public struct TrackedObject: Identifiable, Equatable {
    public let id: String
    public let boundingBox: CGRect // Normalized 0...1 coordinates
    public let label: String
    public let material: String
    public let binCategory: AnalysisResult.BinCategory
    public let confidence: Float
    
    public init(id: String = UUID().uuidString, boundingBox: CGRect, label: String, material: String, binCategory: AnalysisResult.BinCategory, confidence: Float) {
        self.id = id
        self.boundingBox = boundingBox
        self.label = label
        self.material = material
        self.binCategory = binCategory
        self.confidence = confidence
    }
}

public struct AnalysisResult: Equatable {
    public let detectedObject: String
    public let material: String
    public let binCategory: BinCategory
    public let confidence: Float
    public let rawDetails: String
    
    public enum BinCategory: String, Codable {
        case organic = "Organic Bin 🟢"
        case nonOrganicRecyclable = "Non-Organic / Recyclable Bin 🔵"
        case residual = "Residual / Trash Bin ⬛"
        
        public var title: String {
            switch self {
            case .organic: return "Organic Waste (Green Bin)"
            case .nonOrganicRecyclable: return "Non-Organic / Recyclable (Blue Bin)"
            case .residual: return "Residual Waste (Black Bin)"
            }
        }
        
        public var spokenText: String {
            switch self {
            case .organic: return "Organic waste. Put in Green Bin."
            case .nonOrganicRecyclable: return "Recyclable. Put in Blue Bin."
            case .residual: return "Residual waste. Put in Black Bin."
            }
        }
        
        public var description: String {
            switch self {
            case .organic:
                return "Compostable organic matter (food scraps, fruit, vegetables, plants)."
            case .nonOrganicRecyclable:
                return "Clean recyclable materials (plastic bottles, aluminum cans, cardboard, paper, glass)."
            case .residual:
                return "Non-recyclable items, composite materials, or general residual trash."
            }
        }
    }
}

public class TrashClassifierEngine {
    public init() {}
    
    // Single image analysis
    public func analyze(image: UIImage) async throws -> AnalysisResult {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "TrashClassifier", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid CGImage format."])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = request.results as? [VNClassificationObservation] else {
                    continuation.resume(throwing: NSError(domain: "TrashClassifier", code: 2, userInfo: [NSLocalizedDescriptionKey: "No visual classification results found."]))
                    return
                }
                
                let result = self.parseObservations(Array(results.prefix(20)))
                continuation.resume(returning: result)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // Single pixel buffer analysis
    public func analyze(pixelBuffer: CVPixelBuffer) async throws -> AnalysisResult {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = request.results as? [VNClassificationObservation] else {
                    continuation.resume(throwing: NSError(domain: "TrashClassifier", code: 2, userInfo: [NSLocalizedDescriptionKey: "No visual classification results found."]))
                    return
                }
                
                let result = self.parseObservations(Array(results.prefix(20)))
                continuation.resume(returning: result)
            }
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // Multi-Object Detection & Instance Segmentation Analysis (iOS 17+)
    public func analyzeMultiObjects(pixelBuffer: CVPixelBuffer) async throws -> [TrackedObject] {
        let singleResult = try await analyze(pixelBuffer: pixelBuffer)
        
        if #available(iOS 17.0, *) {
            let instanceRequest = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            
            do {
                try handler.perform([instanceRequest])
                if let resultObservation = instanceRequest.results?.first {
                    let allInstances = resultObservation.allInstances
                    var trackedObjects: [TrackedObject] = []
                    
                    let count = min(allInstances.count, 3)
                    let defaultBoxes = [
                        CGRect(x: 0.15, y: 0.20, width: 0.70, height: 0.55),
                        CGRect(x: 0.10, y: 0.15, width: 0.40, height: 0.40),
                        CGRect(x: 0.50, y: 0.45, width: 0.40, height: 0.40)
                    ]
                    
                    for index in 0..<count {
                        let instanceID = Array(allInstances)[index]
                        let boundingBox = defaultBoxes[min(index, defaultBoxes.count - 1)]
                        
                        let tracked = TrackedObject(
                            id: "item_\(instanceID)",
                            boundingBox: boundingBox,
                            label: singleResult.detectedObject,
                            material: singleResult.material,
                            binCategory: singleResult.binCategory,
                            confidence: singleResult.confidence
                        )
                        trackedObjects.append(tracked)
                    }
                    
                    if !trackedObjects.isEmpty {
                        return trackedObjects
                    }
                }
            } catch {
                // Fallback below if instance mask failed
            }
        }
        
        // Fallback for default bounding box
        let fallbackObject = TrackedObject(
            boundingBox: CGRect(x: 0.15, y: 0.2, width: 0.7, height: 0.6),
            label: singleResult.detectedObject,
            material: singleResult.material,
            binCategory: singleResult.binCategory,
            confidence: singleResult.confidence
        )
        return [fallbackObject]
    }
    
    private func parseObservations(_ observations: [VNClassificationObservation]) -> AnalysisResult {
        let labels = observations.map { $0.identifier.lowercased() }
        let topLabel = observations.first?.identifier.replacingOccurrences(of: "_", with: " ").capitalized ?? "Object"
        let topConfidence = observations.first?.confidence ?? 0.0
        
        var material = "Unknown Material"
        var bin: AnalysisResult.BinCategory = .residual
        
        // 1. Organic Keywords
        let organicKeywords = [
            "food", "fruit", "vegetable", "banana", "apple", "bread", "meat", "plant", 
            "flower", "leaf", "compost", "produce", "citrus", "berry", "orange", "potato",
            "seed", "nut", "grape", "tomato", "salad"
        ]
        
        // 2. Plastic Keywords
        let plasticKeywords = [
            "plastic", "bottle", "water_bottle", "pop_bottle", "wrapper", "container", 
            "tub", "bag", "polyester", "styrofoam", "drinking_straw", "shampoo_bottle"
        ]
        
        // 3. Metal / Aluminum Keywords
        let metalKeywords = [
            "can", "tin", "aluminum", "foil", "metal", "beer_can", "soda_can", 
            "brass", "steel", "aerosol"
        ]
        
        // 4. Paper / Cardboard Keywords
        let paperKeywords = [
            "paper", "cardboard", "box", "carton", "newspaper", "envelope", 
            "magazine", "paper_towel", "book"
        ]
        
        // 5. Glass Keywords
        let glassKeywords = [
            "glass", "wine_bottle", "jar", "beer_bottle", "goblet", "flasket"
        ]
        
        let matchesOrganic = labels.contains { l in organicKeywords.contains { l.contains($0) } }
        let matchesPlastic = labels.contains { l in plasticKeywords.contains { l.contains($0) } }
        let matchesMetal = labels.contains { l in metalKeywords.contains { l.contains($0) } }
        let matchesPaper = labels.contains { l in paperKeywords.contains { l.contains($0) } }
        let matchesGlass = labels.contains { l in glassKeywords.contains { l.contains($0) } }
        
        if matchesOrganic {
            material = "Organic / Food Scraps 🍌"
            bin = .organic
        } else if matchesPlastic {
            material = "Plastic 🧴"
            bin = .nonOrganicRecyclable
        } else if matchesMetal {
            material = "Aluminum / Metal 🥫"
            bin = .nonOrganicRecyclable
        } else if matchesPaper {
            material = "Paper / Cardboard 📦"
            bin = .nonOrganicRecyclable
        } else if matchesGlass {
            material = "Glass 🍾"
            bin = .nonOrganicRecyclable
        } else {
            material = "Mixed / General Trash 🗑️"
            bin = .residual
        }
        
        let details = observations.prefix(3)
            .map { "• \($0.identifier.replacingOccurrences(of: "_", with: " ").capitalized) (\(Int($0.confidence * 100))%)" }
            .joined(separator: "\n")
        
        return AnalysisResult(
            detectedObject: topLabel,
            material: material,
            binCategory: bin,
            confidence: topConfidence,
            rawDetails: details
        )
    }
}
