import Foundation

private struct TestFailure: LocalizedError {
    var errorDescription: String?
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure(errorDescription: message)
    }
}

@main
struct VisualChangeFilterTest {
    static func main() throws {
        let items = [
            HTMLVisualChangeItem(elementId: "text-1", label: "标题", kind: "文字", x: 1, y: 2, w: 30, h: 10),
            HTMLVisualChangeItem(elementId: "image-1", label: "封面图", kind: "图片", x: 4, y: 5, w: 40, h: 20),
            HTMLVisualChangeItem(elementId: "box-1", label: "卡片", kind: "位置/尺寸", x: 8, y: 9, w: 50, h: 30),
            HTMLVisualChangeItem(elementId: "style-1", label: "按钮", kind: "样式", x: 12, y: 13, w: 60, h: 25),
            HTMLVisualChangeItem(elementId: nil, label: "旧对象", kind: "删除对象", x: 16, y: 17, w: 70, h: 35)
        ]

        var diagnostics = HTMLDiagnostics.empty
        diagnostics.visualChangeElementId = "fallback-1"
        diagnostics.visualChangeElementIds = ["text-1", "text-1", "image-1"]
        diagnostics.visualChangeItems = items

        try expect(VisualChangeFilter.all.items(from: items).count == 5, "All filter should include every visual change.")
        try expect(VisualChangeFilter.text.items(from: items).map(\.elementId) == ["text-1"], "Text filter should match text changes.")
        try expect(VisualChangeFilter.image.items(from: items).map(\.elementId) == ["image-1"], "Image filter should match image changes.")
        try expect(VisualChangeFilter.geometry.items(from: items).map(\.elementId) == ["box-1"], "Geometry filter should match position/size changes.")
        try expect(VisualChangeFilter.style.items(from: items).map(\.elementId) == ["style-1"], "Style filter should match style changes.")
        try expect(VisualChangeFilter.deleted.items(from: items).count == 1, "Deleted filter should match deleted objects.")
        try expect(diagnostics.visualChangeTargetIds == ["text-1", "image-1", "fallback-1"], "All target ids should be deduplicated and include fallback.")
        try expect(diagnostics.visualChangeTargetIds(for: .text) == ["text-1"], "Filtered target ids should use preview items for text.")
        try expect(diagnostics.visualChangeTargetIds(for: .deleted).isEmpty, "Deleted preview item without element id should not become a target.")

        print("Visual change filter test OK")
    }
}
