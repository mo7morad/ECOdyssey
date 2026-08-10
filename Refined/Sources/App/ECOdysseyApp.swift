import SortingKit
import SwiftUI

@main
struct ECOdysseyApp: App {
    @State private var environment: AppEnvironment?
    @State private var startupError: Error?

    var body: some Scene {
        WindowGroup {
            Group {
                if let environment {
                    ScannerScreen(environment: environment)
                } else if let startupError {
                    StartupFailureScreen(error: startupError)
                } else {
                    ProgressView()
                }
            }
            .task {
                guard environment == nil, startupError == nil else { return }
                do {
                    let built = try AppEnvironment()
                    try await LegacyRecordImporter().importIfNeeded(into: built.eventStore)
                    environment = built
                } catch {
                    // A station that silently shows a blank screen is worse than one
                    // that says why it cannot start.
                    startupError = error
                }
            }
        }
    }
}
