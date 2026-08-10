import Foundation
import SortingKit

/// Exports counted items as CSV.
///
/// The first thing anyone piloting this asks for is their data in a spreadsheet.
public enum CSVExport {
    private static let header = "timestamp,station,bin,material,item,confidence,outcome,tier"

    public static func makeRows(from events: [ScanEvent]) -> String {
        let formatter = ISO8601DateFormatter()
        let rows = events.map { event in
            [
                formatter.string(from: event.occurredAt),
                event.stationID,
                event.binID.rawValue,
                event.materialID.rawValue,
                escape(event.itemName),
                String(format: "%.3f", event.confidence),
                event.outcome.rawValue,
                event.perceptionTier.rawValue,
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    /// Writes the export to a temporary file for sharing.
    public static func makeFile(from events: [ScanEvent]) -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "ecodyssey-scans.csv")
        try? makeRows(from: events).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Item names come from a model and may contain commas or quotes.
    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
