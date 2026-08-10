import Foundation
import SwiftUI
import Vision

// MARK: - Logged Historical Item Record
public struct ScannedItemRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let objectName: String
    public let material: String
    public let binCategoryRaw: String
    
    public var binCategory: AnalysisResult.BinCategory {
        AnalysisResult.BinCategory(rawValue: binCategoryRaw) ?? .residual
    }
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), objectName: String, material: String, binCategory: AnalysisResult.BinCategory) {
        self.id = id
        self.timestamp = timestamp
        self.objectName = objectName
        self.material = material
        self.binCategoryRaw = binCategory.rawValue
    }
}

// MARK: - Analytics Store Manager
@Observable
public class AnalyticsStore {
    public static let shared = AnalyticsStore()
    
    public var records: [ScannedItemRecord] = []
    
    public init() {
        loadFromStorage()
    }
    
    public func logItem(objectName: String, material: String, binCategory: AnalysisResult.BinCategory) {
        // Prevent duplicate logging if exact same item was logged within 3 seconds
        if let last = records.first, last.objectName == objectName, Date().timeIntervalSince(last.timestamp) < 3.0 {
            return
        }
        
        let newRecord = ScannedItemRecord(objectName: objectName, material: material, binCategory: binCategory)
        records.insert(newRecord, at: 0)
        saveToStorage()
    }
    
    public func clearHistory() {
        records.removeAll()
        saveToStorage()
    }
    
    // Stats
    public var totalCount: Int { records.count }
    
    public var organicCount: Int {
        records.filter { $0.binCategory == .organic }.count
    }
    
    public var recyclableCount: Int {
        records.filter { $0.binCategory == .nonOrganicRecyclable }.count
    }
    
    public var residualCount: Int {
        records.filter { $0.binCategory == .residual }.count
    }
    
    public var recyclingRatePercentage: Int {
        guard totalCount > 0 else { return 0 }
        let recyclableTotal = organicCount + recyclableCount
        return Int((Double(recyclableTotal) / Double(totalCount)) * 100.0)
    }
    
    // Persistence
    private let storageKey = "ecosort_scanned_records"
    
    private func saveToStorage() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ScannedItemRecord].self, from: data) {
            self.records = decoded
        }
    }
}
