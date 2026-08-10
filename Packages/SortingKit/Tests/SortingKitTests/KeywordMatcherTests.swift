import Testing
import Foundation
@testable import SortingKit

@Suite("Keyword Matcher Tests")
struct KeywordMatcherTests {
    @Test("Single word keyword matches exact token")
    func singleWordKeywordMatchesExactToken() {
        let hints = ["organic": ["banana"]]
        let materials = KeywordMatcher.findMaterials(
            from: [(identifier: "banana", confidence: 0.9)],
            using: hints
        )
        #expect(materials.count == 1)
        #expect(materials.first?.materialID == "organic")
    }
    
    @Test("Multi-word keyword matches tokenized label")
    func multiWordKeywordMatchesTokenizedLabel() {
        let hints = ["recyclable": ["water bottle"]]
        let materials = KeywordMatcher.findMaterials(
            from: [(identifier: "water_bottle", confidence: 0.8)],
            using: hints
        )
        #expect(materials.count == 1)
        #expect(materials.first?.materialID == "recyclable")
    }
    
    @Test("Substring does not match whole token")
    func substringDoesNotMatchWholeToken() {
        let hints = ["metal": ["can"]]
        let materials = KeywordMatcher.findMaterials(
            from: [(identifier: "toucan", confidence: 0.8)],
            using: hints
        )
        #expect(materials.isEmpty)
    }
    
    @Test("No match returns empty")
    func noMatchReturnsEmpty() {
        let hints = ["organic": ["apple"]]
        let materials = KeywordMatcher.findMaterials(
            from: [(identifier: "xyz", confidence: 0.9)],
            using: hints
        )
        #expect(materials.isEmpty)
    }
    
    @Test("Multiple labels return ranked materials")
    func multipleLabelsReturnRankedMaterials() {
        let hints = ["organic": ["banana"], "recyclable": ["water bottle"]]
        let materials = KeywordMatcher.findMaterials(
            from: [
                (identifier: "banana", confidence: 0.7),
                (identifier: "water_bottle", confidence: 0.9)
            ],
            using: hints
        )
        #expect(materials.count == 2)
        #expect(materials[0].materialID == "recyclable")
        #expect(materials[1].materialID == "organic")
    }
}
