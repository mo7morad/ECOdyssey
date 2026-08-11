import Foundation

public enum KeywordMatcher {
    /// Maps Vision's labels onto ruleset materials, best match first.
    ///
    /// Matching is token-based rather than substring-based on purpose: a substring rule
    /// turns "toucan" into an aluminium can and "candle" into one too.
    ///
    /// Where two materials both claim a label, the more specific keyword wins — "beer
    /// bottle" (glass) beats a bare "bottle" (plastic) on the same label, regardless of
    /// what order the hint dictionary happens to iterate in. Without that tie-break the
    /// winner varied between launches, because `hints` is a dictionary and its order is
    /// not stable.
    public static func findMaterials(
        from visionLabels: [(identifier: String, confidence: Double)],
        using hints: [String: [String]]
    ) -> [MaterialObservation] {
        var strongestMatch = [MaterialID: Match]()

        for (identifier, confidence) in visionLabels {
            let labelTokens = tokenize(identifier)

            for (materialRaw, keywords) in hints {
                guard let specificity = bestSpecificity(matching: labelTokens, among: keywords) else { continue }

                let materialID = MaterialID(rawValue: materialRaw)
                let candidate = Match(confidence: confidence, specificity: specificity)
                if let existing = strongestMatch[materialID], !candidate.outranks(existing) { continue }
                strongestMatch[materialID] = candidate
            }
        }

        return strongestMatch
            .sorted { lhs, rhs in
                if lhs.value.confidence != rhs.value.confidence { return lhs.value.confidence > rhs.value.confidence }
                if lhs.value.specificity != rhs.value.specificity { return lhs.value.specificity > rhs.value.specificity }
                // Final tie-break on the identifier so the ranking is reproducible.
                return lhs.key.rawValue < rhs.key.rawValue
            }
            .map { MaterialObservation(materialID: $0.key, confidence: $0.value.confidence) }
    }

    /// The hazard class a tier that cannot reason about hazards should still report.
    ///
    /// Deliberately returns on the *strongest* label rather than the most specific one:
    /// missing a battery is a fire, so this errs toward flagging. A false hazard costs
    /// one person one wasted walk to the B3 box; a missed one costs a truck.
    public static func findHazard(
        from visionLabels: [(identifier: String, confidence: Double)],
        using hints: [String: [String]]
    ) -> HazardClass? {
        visionLabels
            .sorted { $0.confidence > $1.confidence }
            .lazy
            .compactMap { label in
                hints
                    .filter { matchesAnyKeyword(label.identifier, among: $0.value) }
                    // Dictionary order is not stable across launches; without this the
                    // reported class could vary between runs on the same photo.
                    .min { $0.key < $1.key }
                    .map { HazardClass(rawValue: $0.key) }
            }
            .first
    }

    /// Whether any of `keywords` appears in `text` as a run of whole tokens.
    ///
    /// Shares the tokenizer with material matching on purpose: two definitions of what
    /// "matches" means is how "toucan" starts matching "can" again in one of them.
    public static func matchesAnyKeyword(_ text: String, among keywords: [String]) -> Bool {
        bestSpecificity(matching: tokenize(text), among: keywords) != nil
    }

    /// Token count of the longest keyword that matches, or `nil` when none does.
    private static func bestSpecificity(matching labelTokens: [String], among keywords: [String]) -> Int? {
        keywords
            .map(tokenize)
            .filter { containsConsecutiveTokens(labelTokens, $0) }
            .map(\.count)
            .max()
    }

    private struct Match {
        let confidence: Double
        let specificity: Int

        func outranks(_ other: Match) -> Bool {
            confidence != other.confidence ? confidence > other.confidence : specificity > other.specificity
        }
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
