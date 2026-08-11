import SwiftUI
import CoreVideo

public struct LiveCameraScannerView: UIViewControllerRepresentable {
    public var onFrameCaptured: (CVPixelBuffer) -> Void

    public init(onFrameCaptured: @escaping (CVPixelBuffer) -> Void) {
        self.onFrameCaptured = onFrameCaptured
    }

    public func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onFrameCaptured = onFrameCaptured
        return controller
    }

    public func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}
