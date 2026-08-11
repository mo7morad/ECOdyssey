import Testing
@testable import FirstMVP

struct ItemTrackerTests {
    @Test
    func singleStationaryObjectAcross100FramesCountsOnce() {
        var tracker = ItemTracker()
        let firstResult = tracker.track(id: "item_101")
        #expect(firstResult == true)

        for _ in 0..<99 {
            let nextResult = tracker.track(id: "item_101")
            #expect(nextResult == false)
        }

        #expect(tracker.trackedIDs.count == 1)
    }

    @Test
    func multipleDistinctObjectsTrackSeparately() {
        var tracker = ItemTracker()
        #expect(tracker.track(id: "item_1") == true)
        #expect(tracker.track(id: "item_2") == true)
        #expect(tracker.track(id: "item_1") == false)
        #expect(tracker.trackedIDs.count == 2)
    }
}
