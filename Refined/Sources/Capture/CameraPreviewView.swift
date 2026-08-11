import AVFoundation
import SwiftUI

/// Hosts the live camera preview and publishes the box-coordinate conversion.
///
/// The preview crops to fill, so mapping a normalised box to the screen by multiplying
/// by the view size puts it in the wrong place whenever the frame and view aspect
/// ratios differ. `layerRectConverted(fromMetadataOutputRect:)` accounts for the crop,
/// and only the preview layer can do that conversion — hence handing it back out.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    @Binding var boxMapper: (CGRect) -> CGRect

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill

        // Deferred because assigning a binding during `makeUIView` modifies state in the
        // middle of a view update. Both captures are weak: a strong one here would
        // outlive the view it is meant to be handing back.
        Task { @MainActor [weak view] in
            boxMapper = { [weak view] normalisedBox in
                guard let view else { return .zero }
                return view.previewLayer.layerRectConverted(fromMetadataOutputRect: normalisedBox)
            }
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // Safe by construction: `layerClass` above guarantees the type.
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
