import Foundation

public enum KeywordMatcher {
    public static func findMaterials(
        from visionLabels: [(identifier: String, confidence: Double)],
        using hints: [String: [String]]
    ) -> [MaterialObservation] {
        var observations = [MaterialID: MaterialObservation]()
        
        for (identifier, confidence) in visionLabels {
            let labelTokens = tokenize(identifier)
            
            for (materialRaw, keywords) in hints {
                for keyword in keywords {
                    let keywordTokens = tokenize(keyword)
                    
                    if containsConsecutiveTokens(labelTokens, keywordTokens) {
                        let materialID = MaterialID(rawValue: materialRaw)
                        if let existing = observations[materialID] {
                            if confidence > existing.confidence {
                                observations[materialID] = MaterialObservation(materialID: materialID, confidence: confidence)
                            }
                        } else {
                            observations[materialID] = MaterialObservation(materialID: materialID, confidence: confidence)
                        }
                        break
                    }
                }
            }
        }
        
        return observations.values.sorted { $0.confidence > $1.confidence }
    }
    
    private static func tokenize(_ text: String) -> [String] {
        let set = CharacterSet(charactersIn: "_- ")
        return text.lowercased().components(separatedBy: set).filter { !$0.isEmpty }
    }
    
    private static func containsConsecutiveTokens(_ textTokens: [String], _ keywordTokens: [String]) -> Bool {
        guard !keywordTokens.isEmpty, textTokens.count >= keywordTokens.count else { return false }
        
        for i in 0...(textTokens.count - keywordTokens.count) {
            let slice = Array(textTokens[i..<(i + keywordTokens.count)])
            if slice == keywordTokens {
                return true
            }
        }
        return false
    }
}
