import CoreGraphics
import SortingKit
import Vision

/// Finds items in a frame and follows them between detections.
///
/// This is the cheap per-frame tier. It answers "where are the objects" and nothing
/// else — no classification happens here. Objectness saliency runs occasionally to
/// propose boxes; between those frames the boxes are carried forward by Vision's
/// object tracker, which costs a fraction as much.
///
/// This file uses the completion-handler `VN*` API rather than the newer async Vision
/// API because `VNTrackObjectRequest` and `VNSequenceRequestHandler` have no modern
/// equivalent, and mixing the two styles in one pipeline reads worse than committing
/// to one.
public actor VisionPresenceDetector {
    /// Vision rejects tracking boxes below roughly this size with an internal error,
    /// and a box this small has too few pixels to be worth sending to perception.
    private static let minimumBoxEdge: CGFloat = 0.05
    private static let framesBetweenDetections = 10

    private let sequenceHandler = VNSequenceRequestHandler()
    private var trackingRequests: [VNTrackObjectRequest] = []
    private var framesSinceDetection = 0

    public init() {}

    public func detect(in frame: CGImage) throws -> [Detection] {
        let needsFullDetection = trackingRequests.isEmpty
            || framesSinceDetection >= Self.framesBetweenDetections

        if needsFullDetection {
            framesSinceDetection = 0
            return try proposeObjects(in: frame)
        }

        framesSinceDetection += 1
        return followTrackedObjects(in: frame)
    }

    /// Proposes candidate object boxes for the whole frame.
    ///
    /// Objectness-based saliency returns ranked rectangles around things that look like
    /// discrete objects, which is exactly the question this tier asks. Per-instance
    /// segmentation masks would give tighter outlines but need extra work to reduce to
    /// boxes; revisit if overlay precision becomes the limiting factor.
    private func proposeObjects(in frame: CGImage) throws -> [Detection] {
        let request = VNGenerateObjectnessBasedSaliencyImageRequest()
        try VNImageRequestHandler(cgImage: frame, options: [:]).perform([request])

        guard let salientObjects = request.results?.first?.salientObjects else {
            trackingRequests = []
            return []
        }

        var detections: [Detection] = []
        var requests: [VNTrackObjectRequest] = []

        for object in salientObjects {
            // Filter before clamping. Clamping first would inflate a sliver into a
            // valid-looking box and invent an object that is not there.
            guard isLargeEnough(object.boundingBox) else { continue }

            let box = clampToUnitSquare(object.boundingBox)
            requests.append(VNTrackObjectRequest(detectedObjectObservation: VNDetectedObjectObservation(boundingBox: box)))
            detections.append(Detection(boundingBox: box, quality: Double(object.confidence)))
        }

        trackingRequests = requests
        return detections
    }

    private func followTrackedObjects(in frame: CGImage) -> [Detection] {
        do {
            try sequenceHandler.perform(trackingRequests, on: frame)
        } catch {
            // Tracking failed for this frame. Drop the boxes and re-detect next frame
            // rather than reporting stale positions the tracker would associate wrongly.
            trackingRequests = []
            return []
        }

        var detections: [Detection] = []
        var survivingRequests: [VNTrackObjectRequest] = []

        for request in trackingRequests {
            guard let observation = request.results?.first as? VNDetectedObjectObservation,
                  isLargeEnough(observation.boundingBox) else { continue }

            request.inputObservation = observation
            survivingRequests.append(request)

            let box = clampToUnitSquare(observation.boundingBox)
            detections.append(Detection(boundingBox: box, quality: Double(observation.confidence)))
        }

        trackingRequests = survivingRequests
        return detections
    }

    private func isLargeEnough(_ box: CGRect) -> Bool {
        box.width >= Self.minimumBoxEdge && box.height >= Self.minimumBoxEdge
    }

    private func clampToUnitSquare(_ box: CGRect) -> CGRect {
        let width = min(box.width, 1)
        let height = min(box.height, 1)
        return CGRect(
            x: max(0, min(1 - width, box.minX)),
            y: max(0, min(1 - height, box.minY)),
            width: width,
            height: height
        )
    }
}
