import CoreGraphics
import Evaluations
import Foundation
import ImageIO
import SortingKit
@testable import ECOdyssey

/// One labelled photo: a picture of a real item and the bin it actually belongs in.
///
/// Carries the file name rather than the image because a sample has to be `Codable` and
/// a `CGImage` is not. The name is also what shows up in the Xcode evaluation report,
/// so a failing row says "residu__gelas-kopi.jpg" instead of an opaque index.
struct WastePhotoSample: SampleProtocol {
    let input: String
    let expected: BinID?
}

extension BinID {
    /// What an uncertain decision reports to the evaluation. Reuses the identifier
    /// `ScanCoordinator` already persists for unresolved rows, so "no answer" is one
    /// vocabulary across analytics and grading rather than two.
    static let unresolved = BinID(rawValue: "unresolved")
}

/// Reads the labelled photo set out of the test bundle.
///
/// Photos are named `<binID>__<anything>.jpg`, so adding a case to the dataset is
/// dropping a file into `Evaluations/Photos/` and naming it — no code change, which is
/// what makes it realistic to grow this to the hundreds of samples it needs.
/// Anchors `Bundle(for:)` to this test bundle. A Swift Testing suite is a struct, so
/// there is no test class to hand it.
private final class EvaluationBundleToken {}

enum EvaluationPhotos {
    static var bundle: Bundle { Bundle(for: EvaluationBundleToken.self) }

    enum PhotoError: Error {
        case unreadable(String)
    }

    static func samples(in bundle: Bundle) -> [WastePhotoSample] {
        let urls = bundle.urls(forResourcesWithExtension: nil, subdirectory: "Photos") ?? []
        return urls
            .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
            .compactMap { url in
                guard let binID = expectedBin(fromFileName: url.lastPathComponent) else { return nil }
                return WastePhotoSample(input: url.lastPathComponent, expected: binID)
            }
            .sorted { $0.input < $1.input }
    }

    /// `residu__gelas-kopi.jpg` → `residu`. A file without the separator is skipped
    /// rather than guessed at, so an unlabelled photo cannot quietly score as a pass.
    static func expectedBin(fromFileName name: String) -> BinID? {
        guard let separator = name.range(of: "__") else { return nil }
        let prefix = String(name[name.startIndex..<separator.lowerBound])
        return prefix.isEmpty ? nil : BinID(rawValue: prefix)
    }

    /// Decoded through the app's own `UprightImageDecoder`, so the evaluation grades the
    /// pipeline the station runs — same rotation, same size cap — rather than a
    /// higher-resolution one that only exists in tests.
    static func image(named name: String, in bundle: Bundle) throws -> CGImage {
        guard let url = bundle.url(forResource: "Photos/\(name)", withExtension: nil),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { throw PhotoError.unreadable(name) }

        return try UprightImageDecoder.decode(source)
    }
}
