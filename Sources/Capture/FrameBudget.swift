import Foundation

/// Caps how often frames reach the pipeline, backing off as the device heats up.
///
/// A device running Vision continuously above a bin for a full day will throttle. Left
/// unmanaged the app simply gets slower and slower; here the frame rate steps down
/// deliberately so detection stays responsive at a lower cost.
public actor FrameBudget {
    private var minimumInterval: TimeInterval
    private var lastAcceptedFrame: Date?
    private var thermalObserver: Task<Void, Never>?

    public init() {
        self.minimumInterval = Self.interval(for: ProcessInfo.processInfo.thermalState)
    }

    deinit {
        thermalObserver?.cancel()
    }

    /// Begins reacting to thermal changes. Separate from `init` so the observing task
    /// never captures a partially initialised actor.
    public func startMonitoringThermalState() {
        guard thermalObserver == nil else { return }
        thermalObserver = Task { [weak self] in
            let changes = NotificationCenter.default.notifications(
                named: ProcessInfo.thermalStateDidChangeNotification
            )
            for await _ in changes {
                await self?.applyThermalState(ProcessInfo.processInfo.thermalState)
            }
        }
    }

    public func shouldProcessFrame(now: Date = Date()) -> Bool {
        guard let lastAcceptedFrame else {
            self.lastAcceptedFrame = now
            return true
        }
        guard now.timeIntervalSince(lastAcceptedFrame) >= minimumInterval else { return false }

        self.lastAcceptedFrame = now
        return true
    }

    private func applyThermalState(_ state: ProcessInfo.ThermalState) {
        minimumInterval = Self.interval(for: state)
    }

    private static func interval(for state: ProcessInfo.ThermalState) -> TimeInterval {
        switch state {
        case .nominal: 1.0 / 10.0
        case .fair: 1.0 / 5.0
        case .serious: 1.0 / 2.0
        case .critical: 1.0
        @unknown default: 1.0 / 10.0
        }
    }
}
