import AVFoundation
import CoreImage
import CoreGraphics

public enum CameraPermission: Sendable, Equatable {
    case granted
    case denied
    case undetermined
}

public enum CameraError: Error {
    case permissionDenied
    case noCameraAvailable
}

/// Owns the capture session and turns it into a stream of frames.
///
/// An actor rather than an observable object: session configuration and start/stop are
/// blocking calls that must stay off the main thread, and the only state a view needs
/// from here is the permission result, which is returned rather than observed.
public actor CameraSession {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let frameQueue = DispatchQueue(label: "com.ecodyssey.camera.frames")
    private var frameDelegate: FrameDelegate?

    public init() {}

    /// The session backing the preview layer. Reading this does not start capture.
    public nonisolated var previewSource: AVCaptureSession { captureSession }

    public func requestPermission() async -> CameraPermission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .granted
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }

    public func start() throws -> AsyncStream<CGImage> {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw CameraError.permissionDenied
        }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.noCameraAvailable
        }

        // Buffering the newest frame only is the backpressure mechanism: when the
        // pipeline is busy, stale frames are dropped rather than queued behind it.
        let (stream, continuation) = AsyncStream.makeStream(of: CGImage.self, bufferingPolicy: .bufferingNewest(1))
        let delegate = FrameDelegate(continuation: continuation)
        frameDelegate = delegate

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1280x720

        let input = try AVCaptureDeviceInput(device: camera)
        guard captureSession.canAddInput(input), captureSession.canAddOutput(videoOutput) else {
            captureSession.commitConfiguration()
            throw CameraError.noCameraAvailable
        }
        captureSession.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(delegate, queue: frameQueue)
        captureSession.addOutput(videoOutput)
        captureSession.commitConfiguration()

        captureSession.startRunning()
        return stream
    }

    public func stop() {
        captureSession.stopRunning()
        frameDelegate?.finish()
        frameDelegate = nil
    }
}

/// Converts sample buffers to `CGImage` on the capture queue.
///
/// The continuation is stored immutably so the delegate is safely sendable without
/// locking, and the `CIContext` is built once — constructing one per frame compiles
/// shaders and allocates GPU resources every time, which cooks an always-on kiosk.
private final class FrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, Sendable {
    private let continuation: AsyncStream<CGImage>.Continuation
    private let renderContext = CIContext(options: [.useSoftwareRenderer: false])

    init(continuation: AsyncStream<CGImage>.Continuation) {
        self.continuation = continuation
    }

    func finish() {
        continuation.finish()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let rendered = renderContext.createCGImage(image, from: image.extent) else { return }
        continuation.yield(rendered)
    }
}
