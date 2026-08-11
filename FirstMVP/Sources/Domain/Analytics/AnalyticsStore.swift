import Foundation
import SwiftUI

@Observable
public class AnalyticsStore: @unchecked Sendable {
    public static let shared = AnalyticsStore()

    public private(set) var records: [ScanRecord] = []
    private let storageKey = "ecosort_scanned_records"

    public init() {
        loadFromStorage()
    }

    public func appendRecord(objectName: String, materialName: String, binID: BinID) {
        let newRecord = ScanRecord(
            objectName: objectName,
            materialName: materialName,
            binID: binID
        )
        records.insert(newRecord, at: 0)
        saveToStorage()
    }

    public func clearHistory() {
        records.removeAll()
        saveToStorage()
    }

    public var totalCount: Int {
        records.count
    }

    public func count(for binID: BinID) -> Int {
        records.filter { $0.binID == binID }.count
    }

    public var recyclingRatePercentage: Int {
        guard totalCount > 0 else { return 0 }
        let countRecyclable = count(for: .recyclable)
        return Int((Double(countRecyclable) / Double(totalCount)) * 100.0)
    }

    public var diversionRatePercentage: Int {
        guard totalCount > 0 else { return 0 }
        let totalDiverted = count(for: .organic) + count(for: .recyclable)
        return Int((Double(totalDiverted) / Double(totalCount)) * 100.0)
    }

    private func saveToStorage() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ScanRecord].self, from: data) {
            self.records = decoded
        }
    }
}
