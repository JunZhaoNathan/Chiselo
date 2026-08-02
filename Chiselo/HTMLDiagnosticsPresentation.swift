import Foundation

extension HTMLDiagnostics {
    var ordinaryPreflightSummary: String {
        if blockingExportRiskCount > 0 {
            return "\(blockingExportRiskCount) 项需先处理"
        }
        if (visualChangeCount ?? 0) > 0 {
            return "\(visualChangeCount ?? 0) 处视觉变更待复核"
        }
        return "HTML 和 PDF 可进入导出复核"
    }

    var ordinaryPreflightIcon: String {
        if blockingExportRiskCount > 0 { return "exclamationmark.triangle.fill" }
        if (visualChangeCount ?? 0) > 0 { return "rectangle.2.swap" }
        return "checkmark.seal.fill"
    }

    var preflightSummary: String {
        if blockingExportRiskCount > 0 {
            return "\(blockingExportRiskCount) 项需先处理"
        }
        if pptxReviewRiskCount > 0 {
            return "\(pptxReviewRiskCount) 项导出后需复核"
        }
        if (visualChangeCount ?? 0) > 0 {
            return "\(visualChangeCount ?? 0) 处视觉变更待复核"
        }
        return "HTML、PDF、PPTX 可进入导出复核"
    }

    var preflightIcon: String {
        if blockingExportRiskCount > 0 { return "exclamationmark.triangle.fill" }
        if pptxReviewRiskCount > 0 { return "checklist" }
        if (visualChangeCount ?? 0) > 0 { return "rectangle.2.swap" }
        return "checkmark.seal.fill"
    }

    var blockingExportRiskCount: Int {
        var count = 0
        count += brokenImages
        count += brokenMedia
        if !cleanExport { count += 1 }
        count += textOverflowCount ?? 0
        count += outOfBoundsCount ?? 0
        count += clippedGeometryCount ?? 0
        count += overlayBlockerCount ?? 0
        return count
    }

    var pptxReviewRiskCount: Int {
        var count = 0
        if tableCount > 0 { count += 1 }
        if spanTableCount > 0 { count += 1 }
        if svgCount > 0 { count += 1 }
        if (pptxEffectRiskCount ?? 0) > 0 { count += 1 }
        if (overlapCount ?? 0) > 0 { count += 1 }
        if runtimeCompatibilityRiskCount > 0 { count += 1 }
        return count
    }

    var runtimeCompatibilityRiskCount: Int {
        runtimeRiskCount ?? 0
    }

    var pptxNativeObjectCount: Int {
        (pptxTextObjectCount ?? 0) + (pptxImageObjectCount ?? 0) + (pptxShapeObjectCount ?? 0)
    }

    var pptxMappingTotalObjectCount: Int {
        pptxNativeObjectCount + (pptxReviewObjectCount ?? 0) + (pptxFallbackObjectCount ?? 0)
    }

    var pptxEditableEstimate: Int {
        let total = pptxMappingTotalObjectCount
        guard total > 0 else { return 100 }
        return boundedScore(Int((Double(pptxNativeObjectCount) / Double(total) * 100).rounded()))
    }

    var pptxMappingRecommendation: String {
        if (pptxFallbackObjectCount ?? 0) > 0 {
            return "存在只能整体保留或高风险对象。若目标是可编辑 PPTX，建议先转为可编辑版；若目标是视觉完全一致，优先导出 PDF。"
        }
        if (pptxReviewObjectCount ?? 0) > 0 {
            return "大部分对象可编辑导出，但表格、矢量、复杂效果或层叠对象需要导出后重点复核。"
        }
        return "主要由文字、图片和简单形状组成，适合导出可编辑 PPTX，仍建议抽查文本框和图片。"
    }

    var hasPPTXRepairActions: Bool {
        tableCount > 0
            || svgCount > 0
            || (pptxEffectRiskCount ?? 0) > 0
            || (overlapCount ?? 0) > 0
            || shouldOfferEditableConversion
            || shouldOfferPDFFallback
    }

    var shouldOfferEditableConversion: Bool {
        (pptxFallbackObjectCount ?? 0) > 0 || runtimeCompatibilityRiskCount > 0
    }

    var shouldOfferPDFFallback: Bool {
        (pptxFallbackObjectCount ?? 0) > 0
            || (pptxEffectRiskCount ?? 0) > 0
            || pptxEditabilityScore < 65
    }

    var pptxTextTargetIds: [String] {
        normalizedTargetIds(pptxTextElementIds, fallback: pptxTextElementId)
    }

    var pptxImageTargetIds: [String] {
        normalizedTargetIds(pptxImageElementIds, fallback: pptxImageElementId)
    }

    var pptxShapeTargetIds: [String] {
        normalizedTargetIds(pptxShapeElementIds, fallback: pptxShapeElementId)
    }

    var pptxReviewTargetIds: [String] {
        normalizedTargetIds(pptxReviewElementIds, fallback: pptxReviewElementId)
    }

    var pptxFallbackTargetIds: [String] {
        normalizedTargetIds(pptxFallbackElementIds, fallback: pptxFallbackElementId)
    }

    var visualChangePreviewCanvasWidth: Int {
        if let visualChangeCanvasWidth, visualChangeCanvasWidth > 0 {
            return visualChangeCanvasWidth
        }
        return max(visualChangePreviewItems.map { $0.x + $0.w }.max() ?? 1, 1)
    }

    var visualChangePreviewCanvasHeight: Int {
        if let visualChangeCanvasHeight, visualChangeCanvasHeight > 0 {
            return visualChangeCanvasHeight
        }
        return max(visualChangePreviewItems.map { $0.y + $0.h }.max() ?? 1, 1)
    }

    var runtimeCompatibilityDetail: String {
        let risks = runtimeCompatibilityRiskCount
        if risks == 0 {
            return "普通 HTML 对象，可直接精修"
        }

        var parts: [String] = []
        if (scriptCount ?? 0) > 0 || (runtimeRootCount ?? 0) > 0 {
            parts.append("脚本渲染")
        }
        if (iframeCount ?? 0) > 0 {
            parts.append("\(iframeCount ?? 0) 个嵌入页面")
        }
        if (canvasCount ?? 0) > 0 {
            parts.append("\(canvasCount ?? 0) 个画布")
        }
        if (shadowRootCount ?? 0) > 0 {
            parts.append("\(shadowRootCount ?? 0) 个封装组件")
        }
        if (overlayBlockerCount ?? 0) > 0 {
            parts.append("\(overlayBlockerCount ?? 0) 个遮罩")
        }
        if (externalResourceCount ?? 0) > 0 {
            parts.append("\(externalResourceCount ?? 0) 个外部资源")
        }
        return parts.isEmpty ? "\(risks) 项动态内容风险" : parts.joined(separator: "，")
    }

    var responsiveReviewDetail: String {
        let responsiveRules = responsiveRuleCount ?? 0
        let responsiveRisks = responsiveLayoutRiskCount ?? 0
        let responsiveChanges = responsiveChangeCount ?? 0
        let widthSuffix = responsiveReviewWidthText.isEmpty ? "窄屏和宽屏" : responsiveReviewWidthText
        if responsiveChanges > 0 {
            return "\(responsiveChanges) 个已修改对象处在响应式规则、弹性/网格或粘性布局影响链里，导出前建议检查\(widthSuffix)。"
        }
        if responsiveRisks == 0 {
            return "未检测到明显响应式规则，常规宽度复核即可。"
        }
        if responsiveRules > 0 {
            return "\(responsiveRules) 条响应式规则或容器规则，修改后建议检查\(widthSuffix)。"
        }
        return "\(responsiveRisks) 个弹性/网格/粘性布局对象，修改后建议做多宽度预览。"
    }

    var responsiveReviewWidthText: String {
        let widths = (responsiveReviewWidths ?? []).filter { $0 > 0 }.prefix(4)
        guard !widths.isEmpty else { return "" }
        return "断点附近宽度 \(widths.map { "\($0)" }.joined(separator: " / "))px"
    }

    var sourcePollutionReviewCount: Int {
        max(0, inlineStyleChangeCount ?? 0)
            + max(0, externalStylesheetAffectedChangeCount ?? 0)
            + max(0, stylesheetRuleWritebackCount ?? 0)
    }

    var sourcePollutionReviewDetail: String {
        let inlineChanges = inlineStyleChangeCount ?? 0
        let ruleWrites = stylesheetRuleWritebackCount ?? 0
        let stylesheets = stylesheetCount ?? 0
        let externalSheets = externalStylesheetCount ?? 0
        let externalAffectedChanges = externalStylesheetAffectedChangeCount ?? 0
        let ruleTargets = stylesheetRuleWritebackTargets.prefix(3).joined(separator: "、")
        let ruleTargetSuffix = ruleTargets.isEmpty ? "" : "（\(ruleTargets)）"
        if ruleWrites > 0 && inlineChanges == 0 {
            return "\(ruleWrites) 次样式修改已写入本地 CSS 规则\(ruleTargetSuffix)，源码更易继续维护。"
        }
        if ruleWrites > 0 && inlineChanges > 0 {
            return "\(ruleWrites) 次写入 CSS 规则\(ruleTargetSuffix)，\(inlineChanges) 个对象仍写入 inline style。"
        }
        if inlineChanges > 0 && stylesheets > 0 {
            return "\(inlineChanges) 个变化写入 inline style；原稿含 \(stylesheets) 个样式表，保存前建议抽查源码。"
        }
        if externalAffectedChanges > 0 {
            return "\(externalAffectedChanges) 个已修改对象可能受 \(externalSheets) 个外部样式表影响，建议保存前复核宽度和 class 效果。"
        }
        if inlineChanges > 0 {
            return "\(inlineChanges) 个对象发生 inline style 写回。"
        }
        return "未检测到明显源码污染风险。"
    }

    var htmlReadinessScore: Int {
        boundedScore(
            100
            - (brokenImages + brokenMedia) * 18
            - (cleanExport ? 0 : 30)
            - (textOverflowCount ?? 0) * 10
            - (outOfBoundsCount ?? 0) * 10
            - (clippedGeometryCount ?? 0) * 12
            - min(8, precisionEditingRiskCount)
            - min(12, (overlayBlockerCount ?? 0) * 6)
            - min(8, (responsiveLayoutRiskCount ?? 0) * 2)
            - min(18, (overlapCount ?? 0) * 3)
        )
    }

    var pdfFidelityScore: Int {
        boundedScore(
            100
            - (brokenImages + brokenMedia) * 22
            - (textOverflowCount ?? 0) * 12
            - (outOfBoundsCount ?? 0) * 12
            - (clippedGeometryCount ?? 0) * 14
            - min(10, (overlayBlockerCount ?? 0) * 5)
            - min(20, (overlapCount ?? 0) * 4)
        )
    }

    var pptxEditabilityScore: Int {
        boundedScore(
            100
            - (brokenImages + brokenMedia) * 16
            - (textOverflowCount ?? 0) * 8
            - (outOfBoundsCount ?? 0) * 8
            - (clippedGeometryCount ?? 0) * 10
            - min(18, (overlapCount ?? 0) * 5)
            - min(16, tableCount * 4)
            - (spanTableCount > 0 ? 18 : 0)
            - min(20, svgCount * 6)
            - min(22, (pptxEffectRiskCount ?? 0) * 4)
            - min(28, runtimeCompatibilityRiskCount * 4)
        )
    }

    var overallExportScore: Int {
        min(htmlReadinessScore, pdfFidelityScore, pptxEditabilityScore)
    }

    var pptxRiskSummary: String {
        if pptxEditabilityScore >= 85 {
            return "PPTX 可编辑性较好，导出后抽查文本框和图片即可。"
        }
        if pptxEditabilityScore >= 65 {
            return "PPTX 可编辑性中等，导出后重点检查表格、SVG、复杂效果、动态组件和层级。"
        }
        return "PPTX 可编辑性风险较高，建议先处理红色问题并复核复杂效果、脚本渲染、嵌入页面和整体对象。"
    }

    private func boundedScore(_ value: Int) -> Int {
        min(100, max(0, value))
    }

    private func normalizedTargetIds(_ values: [String]?, fallback: String?) -> [String] {
        var seen = Set<String>()
        var ids: [String] = []
        for value in values ?? [] {
            guard !value.isEmpty, seen.insert(value).inserted else { continue }
            ids.append(value)
        }
        if let fallback, !fallback.isEmpty, seen.insert(fallback).inserted {
            ids.append(fallback)
        }
        return ids
    }
}
