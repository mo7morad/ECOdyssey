import SortingKit
import SwiftUI

/// The kiosk's main screen: live preview, boxes over what it can see, and the bin
/// instruction for the item in front of it.
struct ScannerScreen: View {
    let environment: AppEnvironment

    @State private var permission: CameraPermission = .undetermined
    @State private var boxMapper: (CGRect) -> CGRect = { $0 }
    @State private var isShowingAnalytics = false
    @State private var isShowingGallery = false

    private var coordinator: ScanCoordinator { environment.coordinator }

    var body: some View {
        ZStack {
            switch permission {
            case .granted:
                scannerContent
            case .denied:
                PermissionScreen()
            case .undetermined:
                Color.black.ignoresSafeArea()
            }
        }
        .task { await runSession() }
        .sheet(isPresented: $isShowingAnalytics) {
            AnalyticsScreen(eventStore: environment.eventStore, ruleset: environment.ruleset)
        }
        .sheet(isPresented: $isShowingGallery) {
            GalleryScanScreen(scanner: environment.stillImageScanner)
        }
    }

    private var scannerContent: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView(session: environment.cameraSession.previewSource, boxMapper: $boxMapper)
                .ignoresSafeArea()

            BinOverlay(
                boxes: coordinator.trackedBoxes,
                highlight: coordinator.latestDecision?.suggestedBin,
                mapBox: boxMapper
            )
            .ignoresSafeArea()

            VStack {
                HStack(spacing: 12) {
                    Spacer()
                    stationButton("photo.on.rectangle") { isShowingGallery = true }
                    stationButton("chart.bar.fill") { isShowingAnalytics = true }
                }
                .padding()

                Spacer()

                DecisionCard(decision: coordinator.latestDecision, isPerceiving: coordinator.isPerceiving)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
            }
        }
    }

    private func stationButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .padding(12)
                .background(.thinMaterial, in: Circle())
        }
    }

    private func runSession() async {
        permission = await environment.cameraSession.requestPermission()
        guard permission == .granted else { return }

        KioskLifecycle.beginKioskMode()
        defer { KioskLifecycle.endKioskMode() }

        do {
            let frames = try await environment.cameraSession.start()
            await coordinator.run(frames: frames)
        } catch {
            permission = .denied
        }
        await environment.cameraSession.stop()
    }
}
