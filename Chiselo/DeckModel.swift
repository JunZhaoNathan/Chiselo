import Foundation

struct EditorDeck: Codable, Equatable {
    var version: Int
    var irVersion: String?
    var sourceKind: String?
    var canvas: EditorCanvas
    var slides: [EditorSlide]
}

struct EditorCanvas: Codable, Equatable {
    var width: Double
    var height: Double
    var background: String
}

struct EditorSlide: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var elements: [EditorElement]
}

struct EditorElement: Codable, Identifiable, Equatable {
    var id: String
    var type: String
    var tagName: String?
    var htmlPath: String?
    var semanticRole: String?
    var semanticLabel: String?
    var groupId: String?
    var groupRole: String?
    var groupLabel: String?
    var sourceKind: String?
    var editability: String?
    var fidelity: String?
    var captureNote: String?
    var layoutMode: String?
    var imageSource: String?
    var imageAlt: String?
    var frame: EditorElementFrame?
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    var rotation: Double
    var z: Double
    var locked: Bool?
    var text: String?
    var style: EditorElementStyle?
}

struct EditorElementFrame: Codable, Equatable {
    var label: String?
    var x: Double
    var y: Double
    var w: Double
    var h: Double
}

struct EditorElementStyle: Codable, Equatable {
    var fontFamily: String?
    var fontSize: Double?
    var fontWeight: Double?
    var lineHeight: Double?
    var color: String?
    var fill: String?
    var stroke: String?
    var strokeWidth: Double?
    var radius: Double?
    var textAlign: String?
}

struct BridgeSelectionMessage: Decodable {
    var type: String
    var slideIndex: Int?
    var path: String?
    var element: EditorElement?
}

struct BridgeDeckMessage: Decodable {
    var type: String
    var slideIndex: Int?
    var deck: EditorDeck
}

struct HTMLTreeNode: Codable, Identifiable, Equatable {
    var id: String
    var label: String
    var path: String
    var tagName: String
    var semanticRole: String?
    var semanticLabel: String?
    var children: [HTMLTreeNode]?
}

struct BridgeHTMLTreeMessage: Decodable {
    var type: String
    var tree: [HTMLTreeNode]
    var diagnostics: HTMLDiagnostics?
}

struct BridgeHTMLDiagnosticsMessage: Decodable {
    var type: String
    var diagnostics: HTMLDiagnostics
}

struct HTMLDiagnostics: Codable, Equatable {
    var mode: String
    var imageCount: Int
    var brokenImages: Int
    var embeddedImages: Int?
    var mediaCount: Int
    var brokenMedia: Int
    var svgCount: Int
    var tableCount: Int
    var spanTableCount: Int
    var scriptCount: Int?
    var iframeCount: Int?
    var canvasCount: Int?
    var shadowRootCount: Int?
    var runtimeRootCount: Int?
    var externalResourceCount: Int?
    var overlayBlockerCount: Int?
    var runtimeRiskCount: Int?
    var cleanExport: Bool
    var textOverflowCount: Int?
    var outOfBoundsCount: Int?
    var overlapCount: Int?
    var resourceElementId: String?
    var tableElementId: String?
    var svgElementId: String?
    var textOverflowElementId: String?
    var outOfBoundsElementId: String?
    var overlapElementId: String?
    var runtimeRiskElementId: String?
    var issues: [HTMLDiagnosticIssue]?

    static let empty = HTMLDiagnostics(
        mode: "deck",
        imageCount: 0,
        brokenImages: 0,
        embeddedImages: 0,
        mediaCount: 0,
        brokenMedia: 0,
        svgCount: 0,
        tableCount: 0,
        spanTableCount: 0,
        scriptCount: 0,
        iframeCount: 0,
        canvasCount: 0,
        shadowRootCount: 0,
        runtimeRootCount: 0,
        externalResourceCount: 0,
        overlayBlockerCount: 0,
        runtimeRiskCount: 0,
        cleanExport: true,
        textOverflowCount: 0,
        outOfBoundsCount: 0,
        overlapCount: 0,
        resourceElementId: nil,
        tableElementId: nil,
        svgElementId: nil,
        textOverflowElementId: nil,
        outOfBoundsElementId: nil,
        overlapElementId: nil,
        runtimeRiskElementId: nil,
        issues: []
    )

    var issueCount: Int {
        var count = 0
        count += brokenImages
        count += brokenMedia
        if spanTableCount > 0 { count += 1 }
        if !cleanExport { count += 1 }
        count += textOverflowCount ?? 0
        count += outOfBoundsCount ?? 0
        count += overlapCount ?? 0
        return count
    }

    var warningCount: Int {
        var count = 0
        if svgCount > 0 { count += 1 }
        if tableCount > 0 { count += 1 }
        if (runtimeRiskCount ?? 0) > 0 { count += 1 }
        return count
    }
}

struct HTMLDiagnosticIssue: Codable, Identifiable, Equatable {
    var id: String
    var kind: String
    var severity: String
    var title: String
    var detail: String
    var elementId: String?
}
