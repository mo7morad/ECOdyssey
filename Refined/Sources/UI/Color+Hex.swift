import SwiftUI

extension Color {
    /// Builds a colour from the `#RRGGBB` strings used in the ruleset.
    ///
    /// Bin colours are site configuration, so they arrive as text rather than as asset
    /// catalogue entries. Unparseable values fall back to grey rather than crashing a
    /// kiosk over a typo in a JSON file.
    init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex

        guard digits.count == 6, let packed = UInt32(digits, radix: 16) else {
            self = .gray
            return
        }

        self.init(
            red: Double((packed >> 16) & 0xFF) / 255,
            green: Double((packed >> 8) & 0xFF) / 255,
            blue: Double(packed & 0xFF) / 255
        )
    }
}
