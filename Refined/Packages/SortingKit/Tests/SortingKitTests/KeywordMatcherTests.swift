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
    
    @Test("The more specific keyword wins when two materials claim one label")
    func moreSpecificKeywordOutranksBareToken() {
        // "bottle" is deliberately a plastic hint so that Vision's bare "bottle" label
        // matches something at all. A beer bottle must still come out as glass.
        //
        // Both materials match this label at the same confidence, so only the specificity
        // tie-break separates them. Before it existed the winner came down to whichever
        // way the hint dictionary happened to iterate, which varies per process — hence
        // an explicit ordering rule rather than a repeated-run test, which would sample
        // one seed many times and prove nothing.
        let hints = ["pet_plastic": ["bottle"], "glass": ["beer bottle"]]

        let materials = KeywordMatcher.findMaterials(
            from: [(identifier: "beer_bottle", confidence: 0.6)],
            using: hints
        )

        #expect(materials.first?.materialID == "glass")
    }

    @Test("A bare token matches a compound label")
    func bareTokenMatchesCompoundLabel() {
        // Vision emits "pop_bottle" and "soda_can" far more often than any phrase the
        // hint table used to list, which is why most real items matched nothing.
        let hints = ["pet_plastic": ["bottle"], "aluminium": ["can"]]
        let materials = KeywordMatcher.findMaterials(
            from: [(identifier: "pop_bottle", confidence: 0.4), (identifier: "soda_can", confidence: 0.3)],
            using: hints
        )

        #expect(materials.map(\.materialID) == ["pet_plastic", "aluminium"])
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
