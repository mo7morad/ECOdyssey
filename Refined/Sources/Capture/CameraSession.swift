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
    case stillCaptureProducedNoImage
}

/// Owns the capture session, turns it into a stream of frames, and photographs items on
/// demand.
///
/// The two outputs answer two different questions and are deliberately not
/// interchangeable. The video stream answers "is something there, and is it holding
/// still" — cheap, continuous, and good enough for boxes. `captureStill()` answers "what
/// is it" — one properly focused, exposed, upright photograph, which is what perception
/// actually reads.
///
/// An actor rather than an observable object: session configuration and start/stop are
/// blocking calls that must stay off the main thread, and the only state a view needs
/// from here is the permission result, which is returned rather than observed.
public actor CameraSession {
    // Read from `previewSource` off the actor to hand the layer a live session; the
    // reference never changes after init and AVCaptureSession is documented as safe to
    // touch from other threads for this purpose.
    private nonisolated(unsafe) let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let frameQueue = DispatchQueue(label: "com.ecodyssey.camera.frames")
    private var frameDelegate: FrameDelegate?
    /// Captures in flight, keyed by their settings' unique ID. `AVCapturePhotoOutput`
    /// holds its delegate weakly, so a delegate dropped here is a photograph lost and a
    /// continuation that never resumes. Keying by ID rather than holding a single
    /// reference means two overlapping captures cannot evict each other.
    private var capturesInFlight: [Int64: StillCaptureDelegate] = [:]

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
        // `.photo` rather than a video preset because this session's job includes taking
        // photographs: it is what gives `photoOutput` the full sensor rather than a
        // 720p crop of it. The video stream stays at preview resolution, which is all the
        // presence tier needs.
        captureSession.sessionPreset = .photo

        let input = try AVCaptureDeviceInput(device: camera)
        guard captureSession.canAddInput(input),
              captureSession.canAddOutput(videoOutput),
              captureSession.canAddOutput(photoOutput)
        else {
            captureSession.commitConfiguration()
            throw CameraError.noCameraAvailable
        }
        captureSession.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(delegate, queue: frameQueue)
        captureSession.addOutput(videoOutput)
        captureSession.addOutput(photoOutput)
        captureSession.commitConfiguration()

        captureSession.startRunning()
        return stream
    }

    /// Photographs whatever is in front of the camera, upright and ready to read.
    ///
    /// Perception reads this and never a video frame. A frame from
    /// `AVCaptureVideoDataOutput` arrives at whatever focus and exposure the session
    /// happened to be at, motion-blurred, and in the sensor's native landscape
    /// orientation — the pipeline does not rotate buffers, and rotating them there would
    /// move every box out from under the overlay. A still is focused, exposed, and
    /// carries its orientation in EXIF.
    ///
    /// It is decoded through `UprightImageDecoder`, byte for byte the same path a picked
    /// library photo takes, so the live station and the gallery screen hand the model
    /// identical input. That equivalence is the point: reading a photo from the library
    /// already worked well, and reading a video frame did not.
    public func captureStill() async throws -> CGImage {
        let settings = AVCapturePhotoSettings()
        let captureID = settings.uniqueID

        let encodedPhoto: Data = try await withCheckedThrowingContinuation { continuation in
            let delegate = StillCaptureDelegate { [weak self] result in
                continuation.resume(with: result)
                Task { await self?.forgetCapture(captureID) }
            }
            capturesInFlight[captureID] = delegate
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
        return try UprightImageDecoder.decode(encodedPhoto)
    }

    public func stop() {
        captureSession.stopRunning()
        frameDelegate?.finish()
        frameDelegate = nil
    }

    private func forgetCapture(_ captureID: Int64) {
        capturesInFlight[captureID] = nil
    }
}

/// Hands one photograph back to `captureStill()`.
///
/// Sendable by having no mutable state at all: the completion closure is the only thing
/// stored, and it is immutable. `didFinishProcessingPhoto` is called exactly once per
/// capture, which is what makes it safe to resume a continuation from here.
private final class StillCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, Sendable {
    private let completion: @Sendable (Result<Data, Error>) -> Void

    init(completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }
        guard let encodedPhoto = photo.fileDataRepresentation() else {
            completion(.failure(CameraError.stillCaptureProducedNoImage))
            return
        }
        // Encoded rather than `cgImageRepresentation()`: the orientation lives in the
        // file's EXIF, and the pixel representation drops it.
        completion(.success(encodedPhoto))
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
