import SwiftUI
import AVFoundation
import Vision

// MARK: - Live Camera View Representable
struct LiveCameraScannerView: UIViewControllerRepresentable {
    var onFrameDetected: (CVPixelBuffer) -> Void
    
    func makeUIViewController(context: Context) -> LiveCameraViewController {
        let controller = LiveCameraViewController()
        controller.onFrameCaptured = onFrameDetected
        return controller
    }
    
    func updateUIViewController(_ uiViewController: LiveCameraViewController, context: Context) {}
}

// MARK: - UIViewController for AVCaptureSession
class LiveCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sampleQueue = DispatchQueue(label: "com.ecosort.videoQueue")
    
    var onFrameCaptured: ((CVPixelBuffer) -> Void)?
    private var lastProcessTime = Date.distantPast
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .hd1280x720
        
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: backCamera) else {
            print("Failed to access camera.")
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: sampleQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle processing to once every 0.35 seconds for smooth performance
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) >= 0.35 else { return }
        lastProcessTime = now
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrameCaptured?(pixelBuffer)
    }
}
