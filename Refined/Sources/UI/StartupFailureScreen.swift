import SwiftUI

/// Shown when the app cannot assemble itself — a malformed ruleset, or a store that
/// will not open. A station that explains why it is down can be fixed; a blank screen
/// cannot.
struct StartupFailureScreen: View {
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)

            Text("ECOdyssey could not start")
                .font(.title2.weight(.bold))

            Text(String(describing: error))
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}
