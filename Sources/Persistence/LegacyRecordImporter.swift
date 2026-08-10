import Foundation
import SortingKit

/// One-time migration of history written by the original `UserDefaults` store.
///
/// The old format keyed bins by their display string, emoji included, so renaming a bin
/// would have reclassified every past record. Those three literals are mapped onto
/// stable `BinID`s here; anything unrecognised becomes an explicit retired marker
/// rather than being folded into residual and quietly skewing the numbers.
public struct LegacyRecordImporter {
    private let legacyRecordsKey = "ecosort_scanned_records"
    private let completionFlagKey = "didImportLegacyRecords"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func importIfNeeded(into store: ScanEventStore) async throws {
        guard !defaults.bool(forKey: completionFlagKey) else { return }
        defer { defaults.set(true, forKey: completionFlagKey) }

        guard let payload = defaults.data(forKey: legacyRecordsKey) else { return }
        let legacyRecords = try JSONDecoder().decode([LegacyScannedItem].self, from: payload)

        for record in legacyRecords {
            try await store.append(record.asScanEvent())
        }
        defaults.removeObject(forKey: legacyRecordsKey)
    }
}

/// The shape the original app persisted.
struct LegacyScannedItem: Codable {
    let id: UUID
    let timestamp: Date
    let objectName: String
    let material: String
    let binCategoryRaw: String

    func asScanEvent() -> ScanEvent {
        ScanEvent(
            trackID: TrackID(rawValue: "legacy-\(id.uuidString)"),
            occurredAt: timestamp,
            binID: Self.binID(fromLegacyLabel: binCategoryRaw),
            materialID: MaterialID(rawValue: material),
            itemName: objectName,
            confidence: 0,
            outcome: .sorted,
            perceptionTier: .visionKeyword,
            stationID: "legacy"
        )
    }

    private static func binID(fromLegacyLabel label: String) -> BinID {
        switch label {
        case "Organic Bin 🟢": BinID(rawValue: "organic")
        case "Non-Organic / Recyclable Bin 🔵": BinID(rawValue: "recyclable")
        case "Residual / Trash Bin ⬛": BinID(rawValue: "residual")
        default: BinID(rawValue: "retired")
        }
    }
}
