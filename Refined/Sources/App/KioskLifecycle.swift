import UIKit

/// Device behaviour for a station that runs unattended all day.
@MainActor
public enum KioskLifecycle {
    /// Keeps the screen awake while the scanner is showing. A station that sleeps is a
    /// station that stops counting.
    public static func beginKioskMode() {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    /// Restores normal sleep behaviour, so the app does not hold the screen on while
    /// sitting on some other screen.
    public static func endKioskMode() {
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
