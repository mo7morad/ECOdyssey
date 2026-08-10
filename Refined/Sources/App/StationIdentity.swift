import Foundation

/// Identifies which physical waste station this device is watching.
///
/// Analytics roll up per station, so an operator running several devices can see which
/// bins fill fastest and when. Generated once per install and stable thereafter.
public enum StationIdentity {
    private static let storageKey = "station_identifier"

    public static var current: String {
        if let existing = UserDefaults.standard.string(forKey: storageKey) {
            return existing
        }
        let generated = "station-\(UUID().uuidString.prefix(8))"
        UserDefaults.standard.set(generated, forKey: storageKey)
        return generated
    }
}
