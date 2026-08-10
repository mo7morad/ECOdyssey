import Foundation

public enum RulesetLoader {
    public static func load(from data: Data) throws -> SortingRuleset {
        let decoder = JSONDecoder()
        let ruleset = try decoder.decode(SortingRuleset.self, from: data)
        try ruleset.validate()
        return ruleset
    }
    
    public static func loadDefault() throws -> SortingRuleset {
        guard let url = Bundle.module.url(forResource: "DefaultRuleset", withExtension: "json") else {
            throw RulesetLoadingError.resourceNotFound
        }
        let data = try Data(contentsOf: url)
        return try load(from: data)
    }
}

public enum RulesetLoadingError: Error {
    case resourceNotFound
}
