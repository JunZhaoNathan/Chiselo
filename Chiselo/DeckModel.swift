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
    var shadow: String?
    var textAlign: String?
    var objectFit: String?
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

struct BridgeHistoryMessage: Decodable, Equatable {
    var type: String
    var canUndo: Bool
    var canRedo: Bool
    var undoDepth: Int?
    var redoDepth: Int?
    var nextUndoLabel: String?
    var nextRedoLabel: String?
}

struct HTMLVisualChangeItem: Codable, Equatable, Identifiable {
    var changeKey: String? = nil
    var elementId: String?
    var label: String
    var kind: String
    var detail: String? = nil
    var beforeValue: String? = nil
    var afterValue: String? = nil
    var canRevert: Bool? = nil
    var revertReason: String? = nil
    var x: Int
    var y: Int
    var w: Int
    var h: Int

    var id: String {
        "\(changeKey ?? elementId ?? "missing")-\(kind)-\(x)-\(y)-\(w)-\(h)"
    }
}

enum VisualChangeFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case image
    case geometry
    case style
    case deleted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .text: return "文字"
        case .image: return "图片"
        case .geometry: return "位置尺寸"
        case .style: return "样式"
        case .deleted: return "删除"
        }
    }

    func matches(_ item: HTMLVisualChangeItem) -> Bool {
        switch self {
        case .all:
            return true
        case .text:
            return item.kind.contains("文字")
        case .image:
            return item.kind.contains("图片")
        case .geometry:
            return item.kind.contains("位置") || item.kind.contains("尺寸")
        case .style:
            return item.kind.contains("样式")
        case .deleted:
            return item.kind.contains("删除")
        }
    }

    func items(from items: [HTMLVisualChangeItem]) -> [HTMLVisualChangeItem] {
        self == .all ? items : items.filter(matches)
    }
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
    var pptxEffectRiskCount: Int?
    var visualChangeCount: Int?
    var revertableVisualChangeCount: Int?
    var responsiveRuleCount: Int?
    var responsiveLayoutRiskCount: Int?
    var responsiveChangeCount: Int?
    var responsiveChangeElementId: String?
    var responsiveChangeElementIds: [String]?
    var responsiveChangeItems: [HTMLVisualChangeItem]?
    var stylesheetCount: Int?
    var externalStylesheetCount: Int?
    var inlineStyleChangeCount: Int?
    var stylesheetRuleWritebackCount: Int?
    var pptxTextObjectCount: Int?
    var pptxImageObjectCount: Int?
    var pptxShapeObjectCount: Int?
    var pptxReviewObjectCount: Int?
    var pptxFallbackObjectCount: Int?
    var pptxTextElementId: String?
    var pptxImageElementId: String?
    var pptxShapeElementId: String?
    var pptxReviewElementId: String?
    var pptxFallbackElementId: String?
    var pptxTextElementIds: [String]?
    var pptxImageElementIds: [String]?
    var pptxShapeElementIds: [String]?
    var pptxReviewElementIds: [String]?
    var pptxFallbackElementIds: [String]?
    var cleanExport: Bool
    var sourceCleanlinessScore: Int?
    var exportArtifactCount: Int?
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
    var pptxEffectRiskElementId: String?
    var visualChangeElementId: String?
    var visualChangeElementIds: [String]?
    var visualChangeItems: [HTMLVisualChangeItem]?
    var visualChangeCanvasWidth: Int?
    var visualChangeCanvasHeight: Int?
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
        pptxEffectRiskCount: 0,
        visualChangeCount: 0,
        revertableVisualChangeCount: 0,
        responsiveRuleCount: 0,
        responsiveLayoutRiskCount: 0,
        responsiveChangeCount: 0,
        responsiveChangeElementId: nil,
        responsiveChangeElementIds: [],
        responsiveChangeItems: [],
        stylesheetCount: 0,
        externalStylesheetCount: 0,
        inlineStyleChangeCount: 0,
        stylesheetRuleWritebackCount: 0,
        pptxTextObjectCount: 0,
        pptxImageObjectCount: 0,
        pptxShapeObjectCount: 0,
        pptxReviewObjectCount: 0,
        pptxFallbackObjectCount: 0,
        pptxTextElementId: nil,
        pptxImageElementId: nil,
        pptxShapeElementId: nil,
        pptxReviewElementId: nil,
        pptxFallbackElementId: nil,
        pptxTextElementIds: [],
        pptxImageElementIds: [],
        pptxShapeElementIds: [],
        pptxReviewElementIds: [],
        pptxFallbackElementIds: [],
        cleanExport: true,
        sourceCleanlinessScore: 100,
        exportArtifactCount: 0,
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
        pptxEffectRiskElementId: nil,
        visualChangeElementId: nil,
        visualChangeElementIds: [],
        visualChangeItems: [],
        visualChangeCanvasWidth: 0,
        visualChangeCanvasHeight: 0,
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
        if (pptxEffectRiskCount ?? 0) > 0 { count += 1 }
        if (visualChangeCount ?? 0) > 0 { count += 1 }
        if (responsiveChangeCount ?? 0) > 0 { count += 1 }
        return count
    }

    var sourceCleanlinessPercent: Int {
        min(100, max(0, sourceCleanlinessScore ?? (cleanExport ? 100 : 0)))
    }

    var sourceCleanlinessDetail: String {
        if cleanExport {
            return "未检测到编辑器临时标记，适合交付或继续二次编辑。"
        }
        let count = exportArtifactCount ?? 0
        if count > 0 {
            return "\(count) 处编辑器临时标记仍在导出内容中，需要先处理。"
        }
        return "导出内容仍含临时标记，需要先处理。"
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

extension HTMLDiagnostics {
    var visualChangeTargetIds: [String] {
        normalizedTargetIds(visualChangeElementIds, fallback: visualChangeElementId)
    }

    var visualChangePreviewItems: [HTMLVisualChangeItem] {
        visualChangeItems ?? []
    }

    var responsiveChangeTargetIds: [String] {
        normalizedTargetIds(responsiveChangeElementIds, fallback: responsiveChangeElementId)
    }

    var responsiveChangePreviewItems: [HTMLVisualChangeItem] {
        responsiveChangeItems ?? []
    }

    func visualChangeTargetIds(for filter: VisualChangeFilter) -> [String] {
        if filter == .all {
            return visualChangeTargetIds
        }

        var seen = Set<String>()
        return filter.items(from: visualChangePreviewItems).compactMap(\.elementId).filter { id in
            guard !id.isEmpty, !seen.contains(id) else { return false }
            seen.insert(id)
            return true
        }
    }

    private func normalizedTargetIds(_ values: [String]?, fallback: String?) -> [String] {
        var output: [String] = []
        var seen = Set<String>()
        for value in values ?? [] {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            output.append(trimmed)
        }

        if let fallback {
            let trimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !seen.contains(trimmed) {
                output.append(trimmed)
            }
        }

        return output
    }
}
