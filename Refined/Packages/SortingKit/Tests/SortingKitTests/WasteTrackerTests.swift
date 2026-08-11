import Testing
import CoreGraphics
@testable import SortingKit

struct WasteTrackerTests {
    func detection(x: Double = 0.4, y: Double = 0.4, w: Double = 0.2, h: Double = 0.2, quality: Double = 1.0) -> Detection {
        Detection(boundingBox: CGRect(x: x, y: y, width: w, height: h), quality: quality)
    }

    func confirmedCount(in events: [TrackEvent]) -> Int {
        events.filter { if case .confirmed = $0 { return true }; return false }.count
    }

    @Test func singleStationaryObjectAcross200FramesCountsOnce() {
        // Regression: the original bug. A banana sitting in frame was counted every 3 seconds.
        var tracker = WasteTracker()
        let det = detection()
        var totalConfirmed = 0
        for frame in 0..<200 {
            let events = tracker.ingest([det], at: Double(frame) * 0.1) // 10fps for 20 seconds
            totalConfirmed += confirmedCount(in: events)
        }
        #expect(totalConfirmed == 1)
    }

    @Test func objectLeavingAndDifferentObjectEnteringCountsTwice() {
        var tracker = WasteTracker()
        let det1 = detection(x: 0.2, y: 0.2)
        let det2 = detection(x: 0.7, y: 0.7) // far away, different object
        var totalConfirmed = 0
        var trackIDs: Set<TrackID> = []
        // Object 1 present for 10 frames
        for frame in 0..<10 {
            let events = tracker.ingest([det1], at: Double(frame) * 0.1)
            for event in events {
                if case .confirmed(let id) = event { trackIDs.insert(id); totalConfirmed += 1 }
            }
        }
        // Gap: object 1 leaves (20 frames empty, beyond retire+grace)
        for frame in 10..<50 {
            _ = tracker.ingest([], at: Double(frame) * 0.1)
        }
        // Object 2 appears
        for frame in 50..<60 {
            let events = tracker.ingest([det2], at: Double(frame) * 0.1)
            for event in events {
                if case .confirmed(let id) = event { trackIDs.insert(id); totalConfirmed += 1 }
            }
        }
        #expect(totalConfirmed == 2)
        #expect(trackIDs.count == 2)
    }

    @Test func objectOccludedForTwoFramesStillCountsOnce() {
        // Brief occlusion (hand passes over): re-associated within grace window, still one count.
        var tracker = WasteTracker()
        let det = detection()
        var totalConfirmed = 0
        // Present for 6 frames (enough to confirm)
        for frame in 0..<6 {
            let events = tracker.ingest([det], at: Double(frame) * 0.1)
            totalConfirmed += confirmedCount(in: events)
        }
        // Missing for 2 frames
        for frame in 6..<8 {
            _ = tracker.ingest([], at: Double(frame) * 0.1)
        }
        // Returns for 10 more frames
        for frame in 8..<18 {
            let events = tracker.ingest([det], at: Double(frame) * 0.1)
            totalConfirmed += confirmedCount(in: events)
        }
        #expect(totalConfirmed == 1)
    }

    @Test func objectReappearingAfterGraceWindowCountsAgain() {
        // Grace expiry is a real boundary. After the grace window, a new track is created.
        var tracker = WasteTracker(configuration: TrackerConfiguration(reentryGraceSeconds: 2.0))
        let det = detection()
        var totalConfirmed = 0
        // Present for 6 frames to confirm
        for frame in 0..<6 {
            let events = tracker.ingest([det], at: Double(frame) * 0.1)
            totalConfirmed += confirmedCount(in: events)
        }
        // Disappear for enough frames that retire + grace expires
        // framesToRetire=12 frames missing, then grace=2.0 seconds
        // Need 12 frames missing + 2.0s after lastSeen
        for frame in 6..<60 {
            _ = tracker.ingest([], at: Double(frame) * 0.1)  // 6.0s total, well past grace
        }
        // Reappears
        for frame in 60..<70 {
            let events = tracker.ingest([det], at: Double(frame) * 0.1)
            totalConfirmed += confirmedCount(in: events)
        }
        #expect(totalConfirmed == 2)
    }

    @Test func objectSeenFewerThanConfirmFramesNeverCounts() {
        // Flicker: appears for 2 frames then vanishes. Never confirmed.
        var tracker = WasteTracker()
        let det = detection()
        var totalConfirmed = 0
        // Only 2 frames (default framesToConfirm is 4)
        for frame in 0..<2 {
            let events = tracker.ingest([det], at: Double(frame) * 0.1)
            totalConfirmed += confirmedCount(in: events)
        }
        // Then nothing for 30 frames
        for frame in 2..<32 {
            let events = tracker.ingest([], at: Double(frame) * 0.1)
            totalConfirmed += confirmedCount(in: events)
        }
        #expect(totalConfirmed == 0)
    }

    @Test func twoSimultaneousObjectsCountOnceEach() {
        var tracker = WasteTracker()
        let det1 = detection(x: 0.1, y: 0.1, w: 0.15, h: 0.15)
        let det2 = detection(x: 0.7, y: 0.7, w: 0.15, h: 0.15)
        var totalConfirmed = 0
        for frame in 0..<20 {
            let events = tracker.ingest([det1, det2], at: Double(frame) * 0.1)
            totalConfirmed += confirmedCount(in: events)
        }
        #expect(totalConfirmed == 2)
    }
}
