public struct TrackerConfiguration: Sendable, Equatable {
    public let associationIoUThreshold: Double
    public let framesToConfirm: Int
    public let framesToRetire: Int
    public let reentryGraceSeconds: Double

    public init(
        associationIoUThreshold: Double = 0.3,
        framesToConfirm: Int = 4,
        framesToRetire: Int = 12,
        reentryGraceSeconds: Double = 4.0
    ) {
        self.associationIoUThreshold = associationIoUThreshold
        self.framesToConfirm = framesToConfirm
        self.framesToRetire = framesToRetire
        self.reentryGraceSeconds = reentryGraceSeconds
    }
}
