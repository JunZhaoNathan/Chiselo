import AppKit
import Foundation

struct HTMLVisualSnapshotPair: Equatable {
    var baseline: NSImage?
    var current: NSImage?
    var diff: HTMLVisualSnapshotDiff?
    var capturedAt: Date?

    var hasImages: Bool {
        baseline != nil || current != nil
    }

    static let empty = HTMLVisualSnapshotPair(baseline: nil, current: nil, diff: nil, capturedAt: nil)
}

struct HTMLVisualSnapshotDiff: Equatable {
    var changedPixelRatio: Double
    var averageDelta: Double
    var maxDelta: Double
    var sampleWidth: Int
    var sampleHeight: Int
    var heatmap: NSImage?

    var hasMeaningfulChange: Bool {
        changedPixelRatio >= 0.001 || averageDelta >= 0.01
    }

    static func == (lhs: HTMLVisualSnapshotDiff, rhs: HTMLVisualSnapshotDiff) -> Bool {
        lhs.changedPixelRatio == rhs.changedPixelRatio
            && lhs.averageDelta == rhs.averageDelta
            && lhs.maxDelta == rhs.maxDelta
            && lhs.sampleWidth == rhs.sampleWidth
            && lhs.sampleHeight == rhs.sampleHeight
            && lhs.heatmap?.size == rhs.heatmap?.size
    }
}
