import AppKit
import Foundation
import UniformTypeIdentifiers
import WebKit

private struct OpenTabPayload: Sendable {
    let title: String
    let url: URL
    let mode: String
    let content: String
}

private enum OpenTabReadResult: Sendable {
    case success(OpenTabPayload)
    case failure(filename: String, message: String)
}

private struct OpenTabSafetyInfo: Equatable {
    var backupURL: URL?
    var backupCreated: Bool
    var warning: String?
    var editWarningShown: Bool = false
}

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

@MainActor
final class EditorModel: ObservableObject {
    enum EditorBackdrop: String, CaseIterable, Identifiable {
        case clean
        case grid
        case dots

        var id: String { rawValue }

        var title: String {
            switch self {
            case .clean: return "干净"
            case .grid: return "细网格"
            case .dots: return "点阵"
            }
        }

        var iconName: String {
            switch self {
            case .clean: return "rectangle"
            case .grid: return "square.grid.3x3"
            case .dots: return "circle.grid.3x3"
            }
        }
    }

    struct EditorTab: Identifiable, Equatable {
        let id: UUID
        var title: String
        var url: URL?
        var mode: String
        var content: String
        var needsSnapshot: Bool
    }

    struct DocumentStats: Equatable {
        var pageCount: Int?
        var objectCount: Int?
        var imageCount: Int?
        var htmlNodeCount: Int?

        static let empty = DocumentStats(pageCount: nil, objectCount: nil, imageCount: nil, htmlNodeCount: nil)
    }

    @Published var deck: EditorDeck?
    @Published var selectedElement: EditorElement?
    @Published var selectedSlideIndex: Int = 0
    @Published var documentMode: String = "deck"
    @Published var selectionPath: String?
    @Published var htmlTree: [HTMLTreeNode] = []
    @Published var status: String = "正在启动编辑器..."
    @Published var tabs: [EditorTab] = []
    @Published var activeTabID: UUID?
    @Published var isFileDropTargeted: Bool = false
    @Published var editorBackdrop: EditorBackdrop = .clean
    @Published var documentStats: DocumentStats = .empty
    @Published var htmlDiagnostics: HTMLDiagnostics = .empty
    @Published var htmlVisualSnapshotPair: HTMLVisualSnapshotPair = .empty
    @Published var isCapturingHTMLVisualSnapshot: Bool = false
    @Published var isExportPreflightPresented: Bool = false
    @Published var isHistoryBrowserPresented: Bool = false
    @Published var historySnapshots: [SafeFileHistory.VersionSnapshot] = []
    @Published var selectedHistorySnapshotID: String?
    @Published var canUndoEdit: Bool = false
    @Published var canRedoEdit: Bool = false
    @Published var undoDepth: Int = 0
    @Published var redoDepth: Int = 0

    var hasOpenDocument: Bool {
        activeTabID != nil && !tabs.isEmpty
    }

    var currentSlideElements: [EditorElement] {
        guard let deck,
              deck.slides.indices.contains(selectedSlideIndex) else {
            return []
        }
        return deck.slides[selectedSlideIndex].elements
    }

    var canRevealSafetyFolder: Bool {
        openedURL != nil
    }

    weak var webView: WKWebView?
    private var openedURL: URL?
    private let safeFileHistory = SafeFileHistory()
    private var activeRenderExporter: HTMLRenderExporter?
    private var isSwitchingTabs = false
    private let editorBackdropDefaultsKey = "Chiselo.EditorBackdrop"
    private var htmlVisualBaselineImage: NSImage?
    private var pendingHTMLVisualBaselineCapture = false
    private var tabSafetyInfo: [UUID: OpenTabSafetyInfo] = [:]

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    init() {
        if let rawValue = UserDefaults.standard.string(forKey: editorBackdropDefaultsKey),
           let backdrop = EditorBackdrop(rawValue: rawValue) {
            editorBackdrop = backdrop
        }
    }

    private func updatePublished<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<EditorModel, Value>, to value: Value) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }

    private func refreshDocumentStats() {
        if let deck {
            var objectCount = 0
            var imageCount = 0

            for slide in deck.slides {
                objectCount += slide.elements.count
                imageCount += slide.elements.reduce(0) { total, element in
                    total + (element.type == "image" ? 1 : 0)
                }
            }

            updatePublished(
                \.documentStats,
                to: DocumentStats(
                    pageCount: deck.slides.count,
                    objectCount: objectCount,
                    imageCount: imageCount,
                    htmlNodeCount: nil
                )
            )
            return
        }

        updatePublished(
            \.documentStats,
            to: DocumentStats(
                pageCount: nil,
                objectCount: nil,
                imageCount: nil,
                htmlNodeCount: htmlNodeCount(htmlTree)
            )
        )
    }

    private func htmlNodeCount(_ nodes: [HTMLTreeNode]) -> Int {
        nodes.reduce(0) { total, node in
            total + 1 + htmlNodeCount(node.children ?? [])
        }
    }

    private static let selfEditableHTMLRuntime = #"""
<style data-chiselo-lite-runtime>
  :root {
    --chiselo-lite-accent: #0a84ff;
    --chiselo-lite-ink: #1d1d1f;
    --chiselo-lite-muted: rgba(60, 60, 67, 0.72);
    --chiselo-lite-glass: rgba(246, 248, 252, 0.72);
    --chiselo-lite-border: rgba(60, 60, 67, 0.18);
    --chiselo-lite-shadow: 0 18px 55px rgba(0, 0, 0, 0.18);
  }

  .chiselo-lite-toolbar {
    position: fixed;
    z-index: 2147483647;
    top: max(14px, env(safe-area-inset-top));
    right: max(14px, env(safe-area-inset-right));
    display: flex;
    align-items: center;
    gap: 6px;
    max-width: min(720px, calc(100vw - 28px));
    padding: 7px;
    border: 1px solid var(--chiselo-lite-border);
    border-radius: 16px;
    background: var(--chiselo-lite-glass);
    color: var(--chiselo-lite-ink);
    box-shadow: var(--chiselo-lite-shadow);
    -webkit-backdrop-filter: blur(24px) saturate(1.35);
    backdrop-filter: blur(24px) saturate(1.35);
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
  }

  .chiselo-lite-title,
  .chiselo-lite-status,
  .chiselo-lite-button {
    height: 28px;
    line-height: 28px;
    white-space: nowrap;
  }

  .chiselo-lite-title {
    padding: 0 8px 0 10px;
    font-size: 12px;
    font-weight: 760;
    color: var(--chiselo-lite-ink);
  }

  .chiselo-lite-status {
    max-width: 180px;
    overflow: hidden;
    text-overflow: ellipsis;
    padding: 0 8px;
    font-size: 11px;
    font-weight: 650;
    color: var(--chiselo-lite-muted);
  }

  .chiselo-lite-button {
    appearance: none;
    border: 1px solid rgba(60, 60, 67, 0.16);
    border-radius: 10px;
    padding: 0 10px;
    background: rgba(255, 255, 255, 0.72);
    color: var(--chiselo-lite-ink);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.72);
    font: inherit;
    font-size: 12px;
    font-weight: 700;
    cursor: pointer;
  }

  .chiselo-lite-button:hover {
    background: rgba(255, 255, 255, 0.92);
  }

  .chiselo-lite-button:active {
    transform: translateY(1px);
  }

  .chiselo-lite-button.is-primary {
    border-color: rgba(10, 132, 255, 0.38);
    background: var(--chiselo-lite-accent);
    color: white;
    box-shadow: 0 7px 18px rgba(10, 132, 255, 0.25);
  }

  .chiselo-lite-button.is-danger {
    color: #c0262d;
  }

  .chiselo-lite-editing [data-chiselo-lite-editable] {
    cursor: text !important;
    outline: 1.5px dashed rgba(10, 132, 255, 0.5) !important;
    outline-offset: 3px !important;
    -webkit-user-select: text !important;
    user-select: text !important;
  }

  .chiselo-lite-editing [data-chiselo-lite-editable][data-chiselo-lite-font-lock="true"] {
    font-family: var(--chiselo-lite-edit-font-family) !important;
    font-size: var(--chiselo-lite-edit-font-size) !important;
    font-weight: var(--chiselo-lite-edit-font-weight) !important;
    line-height: var(--chiselo-lite-edit-line-height) !important;
    letter-spacing: var(--chiselo-lite-edit-letter-spacing) !important;
    color: var(--chiselo-lite-edit-color) !important;
  }

  .chiselo-lite-editing [data-chiselo-lite-editable]:focus {
    outline: 2px solid var(--chiselo-lite-accent) !important;
    box-shadow: 0 0 0 4px rgba(10, 132, 255, 0.15) !important;
  }

  @media (max-width: 720px) {
    .chiselo-lite-toolbar {
      left: 10px;
      right: 10px;
      top: auto;
      bottom: max(10px, env(safe-area-inset-bottom));
      flex-wrap: wrap;
      border-radius: 14px;
    }

    .chiselo-lite-title {
      width: 100%;
    }

    .chiselo-lite-status {
      flex: 1 1 auto;
    }
  }
</style>
<script data-chiselo-lite-runtime>
(() => {
  "use strict";

  if (window.__chiseloLiteEditor) return;

  const RUNTIME_SELECTOR = "[data-chiselo-lite-runtime]";
  const EDITABLE_SELECTOR = "h1,h2,h3,h4,h5,h6,p,li,figcaption,caption,td,th,button,a,label,blockquote,pre,span,strong,em,b,i,u,small,code,mark,time,sub,sup";
  const STORAGE_KEY = `chiselo-lite:${location.pathname || "document"}:${document.title || "untitled"}`;
  const FONT_LOCK_PROPS = [
    "--chiselo-lite-edit-font-family",
    "--chiselo-lite-edit-font-size",
    "--chiselo-lite-edit-font-weight",
    "--chiselo-lite-edit-line-height",
    "--chiselo-lite-edit-letter-spacing",
    "--chiselo-lite-edit-color"
  ];

  let isEditing = false;
  let statusNode = null;
  let editButton = null;
  let originalBodyHTML = cleanBodyHTML();

  function doctypeHTML() {
    const doctype = document.doctype;
    if (!doctype) return "";
    const publicId = doctype.publicId ? ` PUBLIC "${doctype.publicId}"` : "";
    const systemPrefix = !doctype.publicId && doctype.systemId ? " SYSTEM" : "";
    const systemId = doctype.systemId ? ` "${doctype.systemId}"` : "";
    return `<!doctype ${doctype.name}${publicId}${systemPrefix}${systemId}>\n`;
  }

  function stripRuntime(node) {
    if (node.classList?.contains("chiselo-lite-editing")) {
      node.classList.remove("chiselo-lite-editing");
      if (!node.getAttribute("class")) node.removeAttribute("class");
    }

    for (const attribute of [...node.attributes || []]) {
      if (attribute.name.startsWith("data-chiselo-lite") || attribute.name === "contenteditable" || attribute.name === "spellcheck") {
        node.removeAttribute(attribute.name);
      }
    }

    for (const property of FONT_LOCK_PROPS) {
      node.style?.removeProperty(property);
    }
    if (node.getAttribute?.("style") === "") node.removeAttribute("style");
  }

  function cleanClone(root) {
    const clone = root.cloneNode(true);
    for (const runtimeNode of clone.querySelectorAll?.(RUNTIME_SELECTOR) || []) {
      runtimeNode.remove();
    }
    for (const node of [clone, ...clone.querySelectorAll?.("*") || []]) {
      stripRuntime(node);
    }
    return clone;
  }

  function cleanHTML() {
    return doctypeHTML() + cleanClone(document.documentElement).outerHTML;
  }

  function cleanBodyHTML() {
    return cleanClone(document.body).innerHTML;
  }

  function isEditableTarget(node) {
    if (!node || node.closest?.(RUNTIME_SELECTOR)) return false;
    const text = (node.textContent || "").replace(/\s+/g, " ").trim();
    if (!text) return false;
    const style = getComputedStyle(node);
    if (style.display === "none" || style.visibility === "hidden") return false;
    const rect = node.getBoundingClientRect();
    return rect.width > 2 && rect.height > 2;
  }

  function editableNodes() {
    const candidates = [...document.body.querySelectorAll(EDITABLE_SELECTOR)].filter(isEditableTarget);
    const nodes = [];
    for (const node of candidates) {
      if (nodes.some((parent) => parent.contains(node))) continue;
      nodes.push(node);
    }
    return nodes;
  }

  function updateStatus(text) {
    if (statusNode) statusNode.textContent = text;
  }

  function lockTypography(node) {
    const computed = getComputedStyle(node);
    node.style.setProperty("--chiselo-lite-edit-font-family", computed.fontFamily || "inherit");
    node.style.setProperty("--chiselo-lite-edit-font-size", computed.fontSize || "inherit");
    node.style.setProperty("--chiselo-lite-edit-font-weight", computed.fontWeight || "inherit");
    node.style.setProperty("--chiselo-lite-edit-line-height", computed.lineHeight || "normal");
    node.style.setProperty("--chiselo-lite-edit-letter-spacing", computed.letterSpacing || "normal");
    node.style.setProperty("--chiselo-lite-edit-color", computed.color || "inherit");
    node.setAttribute("data-chiselo-lite-font-lock", "true");
  }

  function unlockTypography(node) {
    node.removeAttribute("data-chiselo-lite-font-lock");
    for (const property of FONT_LOCK_PROPS) {
      node.style.removeProperty(property);
    }
    if (node.getAttribute("style") === "") node.removeAttribute("style");
  }

  function insertPlainTextAtSelection(text) {
    if (!text) return;
    if (document.queryCommandSupported?.("insertText")) {
      document.execCommand("insertText", false, text);
      return;
    }

    const selection = document.getSelection();
    if (!selection || selection.rangeCount === 0) return;
    const range = selection.getRangeAt(0);
    range.deleteContents();
    const textNode = document.createTextNode(text);
    range.insertNode(textNode);
    range.setStartAfter(textNode);
    range.collapse(true);
    selection.removeAllRanges();
    selection.addRange(range);
  }

  function setEditing(enabled) {
    isEditing = enabled;
    document.documentElement.classList.toggle("chiselo-lite-editing", enabled);

    for (const node of document.querySelectorAll("[data-chiselo-lite-editable]")) {
      unlockTypography(node);
      node.removeAttribute("data-chiselo-lite-editable");
      node.removeAttribute("contenteditable");
      node.removeAttribute("spellcheck");
    }

    if (enabled) {
      const nodes = editableNodes();
      for (const node of nodes) {
        lockTypography(node);
        node.setAttribute("data-chiselo-lite-editable", "true");
        node.setAttribute("contenteditable", "true");
        node.setAttribute("spellcheck", "true");
      }
      updateStatus(`可编辑 ${nodes.length} 处文字`);
    } else {
      updateStatus("预览模式");
    }

    if (editButton) editButton.textContent = enabled ? "退出编辑" : "编辑文字";
  }

  function downloadHTML() {
    setEditing(false);
    const blob = new Blob([cleanHTML()], { type: "text/html;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    const title = (document.title || "document").replace(/[\\/:*?"<>|]+/g, "-").trim() || "document";
    link.href = url;
    link.download = `${title}-edited.html`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    updateStatus("已生成下载文件");
  }

  function saveDraft() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({
        body: cleanBodyHTML(),
        savedAt: new Date().toISOString()
      }));
      updateStatus("草稿已保存");
    } catch {
      updateStatus("浏览器不允许保存草稿");
    }
  }

  function loadDraft() {
    try {
      const draft = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
      if (!draft?.body) {
        updateStatus("没有草稿");
        return;
      }
      setEditing(false);
      document.body.innerHTML = draft.body;
      installToolbar();
      updateStatus("草稿已载入");
    } catch {
      updateStatus("草稿载入失败");
    }
  }

  function restoreInitial() {
    setEditing(false);
    document.body.innerHTML = originalBodyHTML;
    installToolbar();
    updateStatus("已恢复初始");
  }

  function button(label, className, action) {
    const node = document.createElement("button");
    node.type = "button";
    node.className = `chiselo-lite-button ${className || ""}`.trim();
    node.textContent = label;
    node.addEventListener("click", action);
    return node;
  }

  function installToolbar() {
    for (const node of document.querySelectorAll(".chiselo-lite-toolbar")) {
      node.remove();
    }

    const toolbar = document.createElement("div");
    toolbar.className = "chiselo-lite-toolbar";
    toolbar.setAttribute("data-chiselo-lite-runtime", "");

    const title = document.createElement("div");
    title.className = "chiselo-lite-title";
    title.textContent = "Chiselo 编辑模式";

    statusNode = document.createElement("div");
    statusNode.className = "chiselo-lite-status";
    statusNode.textContent = "预览模式";

    editButton = button("编辑文字", "is-primary", () => setEditing(!isEditing));
    toolbar.append(
      title,
      editButton,
      button("保存草稿", "", saveDraft),
      button("载入草稿", "", loadDraft),
      button("下载 HTML", "", downloadHTML),
      button("恢复初始", "is-danger", restoreInitial),
      statusNode
    );

    document.body.appendChild(toolbar);
    if (isEditing) setEditing(true);
  }

  document.addEventListener("click", (event) => {
    if (!isEditing) return;
    if (event.target.closest?.(RUNTIME_SELECTOR)) return;
    if (event.target.closest?.("a")) event.preventDefault();
  }, true);

  document.addEventListener("input", (event) => {
    if (!event.target.closest?.("[data-chiselo-lite-editable]")) return;
    updateStatus("有未导出的修改");
  }, true);

  document.addEventListener("paste", (event) => {
    if (!event.target.closest?.("[data-chiselo-lite-editable]")) return;
    const text = event.clipboardData?.getData("text/plain") || "";
    if (!text) return;
    event.preventDefault();
    insertPlainTextAtSelection(text);
    updateStatus("有未导出的修改");
  }, true);

  installToolbar();
  window.__chiseloLiteEditor = { cleanHTML, setEditing, saveDraft, loadDraft, restoreInitial, downloadHTML };
})();
</script>
"""#

    func attachWebView(_ webView: WKWebView) {
        self.webView = webView
    }

    func handleBridgeMessage(_ body: [String: Any]) {
        guard let type = body["type"] as? String else { return }

        do {
            switch type {
            case "bridgeReady":
                applyEditorBackdrop()
                if let activeTabID {
                    updatePublished(\.status, to: "编辑器已就绪")
                    loadTab(id: activeTabID)
                } else {
                    updatePublished(\.status, to: "打开项目或拖入 HTML 文件开始")
                }

            case "selectionChanged":
                guard hasOpenDocument else {
                    updatePublished(\.selectedElement, to: nil)
                    updatePublished(\.selectionPath, to: nil)
                    return
                }
                let message = bridgeSelectionMessage(from: body)
                updatePublished(\.selectedSlideIndex, to: message.slideIndex ?? selectedSlideIndex)
                updatePublished(\.selectedElement, to: message.element)
                updatePublished(\.selectionPath, to: message.path)
                if let element = message.element {
                    updatePublished(\.status, to: "已选中 \(element.semanticLabel ?? element.tagName ?? element.type)")
                } else {
                    updatePublished(\.status, to: "未选中对象")
                }

            case "deckChanged":
                guard hasOpenDocument else {
                    updatePublished(\.deck, to: nil)
                    updatePublished(\.selectedElement, to: nil)
                    updatePublished(\.selectedSlideIndex, to: 0)
                    updatePublished(\.selectionPath, to: nil)
                    updatePublished(\.htmlTree, to: [])
                    updatePublished(\.htmlDiagnostics, to: .empty)
                    resetHTMLVisualSnapshots()
                    refreshDocumentStats()
                    return
                }
                let data = try JSONSerialization.data(withJSONObject: body, options: [])
                let message = try JSONDecoder().decode(BridgeDeckMessage.self, from: data)
                updatePublished(\.deck, to: message.deck)
                updatePublished(\.htmlTree, to: [])
                updatePublished(\.htmlDiagnostics, to: .empty)
                resetHTMLVisualSnapshots()
                updatePublished(\.documentMode, to: "deck")
                updatePublished(\.selectedSlideIndex, to: message.slideIndex ?? selectedSlideIndex)
                updatePublished(\.status, to: "页面已更新")
                refreshDocumentStats()

            case "htmlTreeChanged":
                guard hasOpenDocument else {
                    updatePublished(\.htmlTree, to: [])
                    updatePublished(\.htmlDiagnostics, to: .empty)
                    refreshDocumentStats()
                    return
                }
                let data = try JSONSerialization.data(withJSONObject: body, options: [])
                let message = try JSONDecoder().decode(BridgeHTMLTreeMessage.self, from: data)
                updatePublished(\.htmlTree, to: message.tree)
                updatePublished(\.htmlDiagnostics, to: message.diagnostics ?? .empty)
                refreshDocumentStats()
                capturePendingHTMLVisualBaselineIfNeeded()

            case "htmlDiagnosticsChanged":
                guard hasOpenDocument else {
                    updatePublished(\.htmlDiagnostics, to: .empty)
                    return
                }
                let data = try JSONSerialization.data(withJSONObject: body, options: [])
                let message = try JSONDecoder().decode(BridgeHTMLDiagnosticsMessage.self, from: data)
                updatePublished(\.htmlDiagnostics, to: message.diagnostics)

            case "historyChanged":
                guard hasOpenDocument else {
                    resetEditorHistoryState()
                    return
                }
                let data = try JSONSerialization.data(withJSONObject: body, options: [])
                let message = try JSONDecoder().decode(BridgeHistoryMessage.self, from: data)
                updatePublished(\.canUndoEdit, to: message.canUndo)
                updatePublished(\.canRedoEdit, to: message.canRedo)
                updatePublished(\.undoDepth, to: max(0, message.undoDepth ?? 0))
                updatePublished(\.redoDepth, to: max(0, message.redoDepth ?? 0))

            case "documentDirty":
                markActiveTabNeedsSnapshot()
                presentBackupReminderBeforeFirstEditIfNeeded()

            case "requestReplaceImage":
                replaceSelectedImage()

            default:
                break
            }
        } catch {
            updatePublished(\.status, to: "Bridge decode failed: \(error.localizedDescription)")
        }
    }

    private func bridgeSelectionMessage(from body: [String: Any]) -> BridgeSelectionMessage {
        BridgeSelectionMessage(
            type: "selectionChanged",
            slideIndex: bridgeInt(body["slideIndex"]),
            path: bridgeString(body["path"]),
            element: bridgeElement(body["element"])
        )
    }

    private func bridgeElement(_ value: Any?) -> EditorElement? {
        guard let object = value as? [String: Any],
              let id = bridgeString(object["id"]),
              let type = bridgeString(object["type"]),
              let x = bridgeDouble(object["x"]),
              let y = bridgeDouble(object["y"]),
              let w = bridgeDouble(object["w"]),
              let h = bridgeDouble(object["h"]),
              let rotation = bridgeDouble(object["rotation"]),
              let z = bridgeDouble(object["z"]) else {
            return nil
        }

        return EditorElement(
            id: id,
            type: type,
            tagName: bridgeString(object["tagName"]),
            htmlPath: bridgeString(object["htmlPath"]),
            semanticRole: bridgeString(object["semanticRole"]),
            semanticLabel: bridgeString(object["semanticLabel"]),
            groupId: bridgeString(object["groupId"]),
            groupRole: bridgeString(object["groupRole"]),
            groupLabel: bridgeString(object["groupLabel"]),
            sourceKind: bridgeString(object["sourceKind"]),
            editability: bridgeString(object["editability"]),
            fidelity: bridgeString(object["fidelity"]),
            captureNote: bridgeString(object["captureNote"]),
            layoutMode: bridgeString(object["layoutMode"]),
            imageSource: bridgeString(object["imageSource"]),
            imageAlt: bridgeString(object["imageAlt"]),
            frame: bridgeElementFrame(object["frame"]),
            x: x,
            y: y,
            w: w,
            h: h,
            rotation: rotation,
            z: z,
            locked: bridgeBool(object["locked"]),
            text: bridgeString(object["text"]),
            style: bridgeStyle(object["style"])
        )
    }

    private func bridgeElementFrame(_ value: Any?) -> EditorElementFrame? {
        guard let object = value as? [String: Any],
              let x = bridgeDouble(object["x"]),
              let y = bridgeDouble(object["y"]),
              let w = bridgeDouble(object["w"]),
              let h = bridgeDouble(object["h"]) else {
            return nil
        }

        return EditorElementFrame(
            label: bridgeString(object["label"]),
            x: x,
            y: y,
            w: w,
            h: h
        )
    }

    private func bridgeStyle(_ value: Any?) -> EditorElementStyle? {
        guard let object = value as? [String: Any] else { return nil }

        return EditorElementStyle(
            fontFamily: bridgeString(object["fontFamily"]),
            fontSize: bridgeDouble(object["fontSize"]),
            fontWeight: bridgeDouble(object["fontWeight"]),
            lineHeight: bridgeDouble(object["lineHeight"]),
            color: bridgeString(object["color"]),
            fill: bridgeString(object["fill"]),
            stroke: bridgeString(object["stroke"]),
            strokeWidth: bridgeDouble(object["strokeWidth"]),
            radius: bridgeDouble(object["radius"]),
            shadow: bridgeString(object["shadow"]),
            textAlign: bridgeString(object["textAlign"]),
            objectFit: bridgeString(object["objectFit"])
        )
    }

    private func bridgeString(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private func bridgeDouble(_ value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double.isFinite ? double : nil
        case let number as NSNumber:
            let double = number.doubleValue
            return double.isFinite ? double : nil
        case let string as String:
            let double = Double(string)
            return double?.isFinite == true ? double : nil
        default:
            return nil
        }
    }

    private func bridgeCGFloat(_ value: Any?) -> CGFloat? {
        guard let value = bridgeDouble(value) else { return nil }
        return CGFloat(value)
    }

    private func bridgeInt(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private func bridgeBool(_ value: Any?) -> Bool? {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            switch string.lowercased() {
            case "true", "1": return true
            case "false", "0": return false
            default: return nil
            }
        default:
            return nil
        }
    }

    func setEditorBackdrop(_ backdrop: EditorBackdrop) {
        editorBackdrop = backdrop
        UserDefaults.standard.set(backdrop.rawValue, forKey: editorBackdropDefaultsKey)
        applyEditorBackdrop()
    }

    func openDeck() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = openContentTypes

        guard panel.runModal() == .OK else { return }
        openDroppedURLs(panel.urls)
    }

    func activateTab(_ id: UUID) {
        guard activeTabID != id, tabs.contains(where: { $0.id == id }) else { return }
        captureActiveTabSnapshot { [weak self] in
            self?.loadTab(id: id)
        }
    }

    func closeTab(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = activeTabID == id
        tabSafetyInfo.removeValue(forKey: id)
        tabs.remove(at: index)

        guard wasActive else { return }

        if tabs.isEmpty {
            resetToWelcome()
            return
        }

        let nextIndex = min(index, tabs.count - 1)
        loadTab(id: tabs[nextIndex].id)
    }

    func openDroppedURLs(_ urls: [URL]) {
        let openableURLs = urls.filter(canOpenURL)
        guard !openableURLs.isEmpty else {
            status = "拖入 HTML、HTM、XHTML 或 Chiselo 项目文件即可打开"
            isFileDropTargeted = false
            return
        }

        isFileDropTargeted = false
        status = openableURLs.count == 1 ? "正在打开 \(openableURLs[0].lastPathComponent)..." : "正在打开 \(openableURLs.count) 个文件..."
        captureActiveTabSnapshot { [weak self] in
            guard let self else { return }

            DispatchQueue.global(qos: .userInitiated).async {
                let results = openableURLs.map(readOpenTabPayload)

                DispatchQueue.main.async { [weak self] in
                    Task { @MainActor in
                        self?.applyOpenTabReadResults(results)
                    }
                }
            }
        }
    }

    func openDroppedFiles(from providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }

        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()

        for provider in fileProviders {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }

                let url: URL?
                if let itemURL = item as? URL {
                    url = itemURL
                } else if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let string = item as? String {
                    url = URL(string: string)
                } else {
                    url = nil
                }

                if let url {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            Task { @MainActor in
                self?.openDroppedURLs(urls)
            }
        }

        return true
    }

    func setFileDropTargeted(_ targeted: Bool) {
        guard isFileDropTargeted != targeted else { return }
        isFileDropTargeted = targeted
    }

    private func presentBackupReminderBeforeFirstEditIfNeeded() {
        guard let activeTabID,
              var safety = tabSafetyInfo[activeTabID],
              !safety.editWarningShown else {
            return
        }

        safety.editWarningShown = true
        tabSafetyInfo[activeTabID] = safety

        let alert = NSAlert()
        alert.messageText = "修改前请确认原始文件已备份"
        if let warning = safety.warning {
            alert.informativeText = "\(warning)\n\n建议先在 Finder 里复制一份原始 HTML，再继续精修。"
            alert.alertStyle = .warning
        } else if let backupURL = safety.backupURL {
            let verb = safety.backupCreated ? "已自动创建原始备份" : "已保留已有原始备份"
            alert.informativeText = "\(verb)：\(backupURL.lastPathComponent)\n\n保存覆盖前还会写入 `.chiselo-history` 版本快照。重要交付文件建议先确认这份备份存在。"
            alert.alertStyle = .informational
        } else {
            alert.informativeText = "当前文件还没有可确认的自动备份。重要 HTML 建议先复制一份原始文件，再继续修改。"
            alert.alertStyle = .warning
        }
        alert.addButton(withTitle: "继续修改")
        alert.addButton(withTitle: "打开备份位置")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn, let backupURL = safety.backupURL {
            NSWorkspace.shared.activateFileViewerSelecting([backupURL])
            status = "已显示原始备份：\(backupURL.lastPathComponent)"
        } else if let backupURL = safety.backupURL {
            status = "修改前备份已确认：\(backupURL.lastPathComponent)"
        } else {
            status = "请确认已自行备份原始文件"
        }
    }

    func saveDeck() {
        guard hasOpenDocument else {
            status = "请先打开项目或拖入 HTML 文件"
            return
        }

        if documentMode == "html" {
            saveCurrentHTML()
            return
        }

        guard let json = deckJSON else {
            status = "当前没有可保存的固定画布项目"
            return
        }

        guard let url = openedURL ?? chooseSaveURL(defaultName: "chiselo-project.aislide", contentTypes: deckContentTypes) else { return }

        do {
            let snapshotURL = try safeFileHistory.protectFileBeforeOverwrite(at: url, fallbackExtension: "aislide")
            try json.write(to: url, atomically: true, encoding: .utf8)
            openedURL = url
            updateActiveTabAfterSave(url: url, mode: "deck", content: json)
            status = safeFileHistory.saveStatus(for: url, snapshotURL: snapshotURL)
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }

    func revealSafetyFolder() {
        guard let openedURL else {
            status = "当前文件还没有保存位置"
            return
        }

        let historyDirectory = safeFileHistory.historyDirectory(for: openedURL)
        if FileManager.default.fileExists(atPath: historyDirectory.path) {
            NSWorkspace.shared.open(historyDirectory)
            status = "已打开版本快照目录"
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([openedURL])
        status = "还没有保存快照，已显示当前文件位置"
    }

    func presentHistoryBrowser() {
        guard openedURL != nil else {
            status = "当前文件还没有保存位置"
            return
        }

        refreshHistorySnapshots()
        isHistoryBrowserPresented = true
        status = historySnapshots.isEmpty ? "没有找到可恢复的版本快照" : "已打开版本历史"
    }

    func refreshHistorySnapshots() {
        guard let openedURL else {
            historySnapshots = []
            selectedHistorySnapshotID = nil
            return
        }

        do {
            let snapshots = try safeFileHistory.versionSnapshots(for: openedURL)
            let previousSelection = selectedHistorySnapshotID
            updatePublished(\.historySnapshots, to: snapshots)
            if let previousSelection, snapshots.contains(where: { $0.id == previousSelection }) {
                selectedHistorySnapshotID = previousSelection
            } else {
                selectedHistorySnapshotID = snapshots.first?.id
            }
        } catch {
            historySnapshots = []
            selectedHistorySnapshotID = nil
            status = "读取版本历史失败：\(error.localizedDescription)"
        }
    }

    func restoreSelectedHistorySnapshot() {
        guard let selectedHistorySnapshotID,
              let snapshot = historySnapshots.first(where: { $0.id == selectedHistorySnapshotID }) else {
            status = "请选择一个版本快照"
            return
        }

        restoreSnapshot(at: snapshot.url)
    }

    func restoreLatestSnapshot() {
        guard let openedURL else {
            status = "当前文件还没有保存位置"
            return
        }

        do {
            guard let snapshotURL = try safeFileHistory.latestVersionSnapshot(for: openedURL) else {
                status = "没有找到可恢复的版本快照"
                return
            }

            restoreSnapshot(at: snapshotURL)
        } catch {
            status = "恢复失败：\(error.localizedDescription)"
        }
    }

    private func restoreSnapshot(at snapshotURL: URL) {
        guard let openedURL else {
            status = "当前文件还没有保存位置"
            return
        }

        do {
            guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
                status = "快照不存在或已被移动"
                refreshHistorySnapshots()
                return
            }

            let alert = NSAlert()
            alert.messageText = "恢复这个 Chiselo 快照？"
            alert.informativeText = "将用 \(snapshotURL.lastPathComponent) 覆盖当前文件。覆盖前会先为当前文件再保存一份快照。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "恢复")
            alert.addButton(withTitle: "取消")

            guard alert.runModal() == .alertFirstButtonReturn else {
                status = "已取消恢复"
                return
            }

            _ = try safeFileHistory.protectFileBeforeOverwrite(
                at: openedURL,
                fallbackExtension: documentMode == "html" ? "html" : "aislide"
            )
            try FileManager.default.removeItem(at: openedURL)
            try FileManager.default.copyItem(at: snapshotURL, to: openedURL)

            let restoredContent = try readTextFile(at: openedURL)
            updateActiveTabAfterSave(url: openedURL, mode: documentMode, content: restoredContent)

            if documentMode == "html" {
                importHTML(restoredContent, from: openedURL)
            } else {
                loadDeckJSON(restoredContent)
            }

            refreshHistorySnapshots()
            status = "已恢复 \(snapshotURL.lastPathComponent)"
        } catch {
            status = "恢复失败：\(error.localizedDescription)"
        }
    }

    func exportHTML() {
        guard hasOpenDocument else {
            status = "请先打开项目或拖入 HTML 文件"
            return
        }

        exportCurrentHTML { [weak self] html in
            self?.saveHTML(html)
        }
    }

    func exportEditableHTML() {
        guard hasOpenDocument else {
            status = "请先打开项目或拖入 HTML 文件"
            return
        }

        exportCurrentHTML { [weak self] html in
            guard let self else { return }
            let editableHTML = self.selfEditableHTML(from: html)
            self.saveHTML(editableHTML, defaultName: self.editableHTMLDefaultName)
        }
    }

    func exportPDF() {
        guard hasOpenDocument else {
            status = "请先打开项目或拖入 HTML 文件"
            return
        }

        guard let url = chooseSaveURL(defaultName: "document.pdf", contentTypes: [.pdf]) else { return }
        status = "Rendering PDF..."

        exportCurrentHTML { [weak self] html in
            self?.renderExport(html: html, outputURL: url, format: .pdf)
        }
    }

    func exportPPTX() {
        guard hasOpenDocument else {
            status = "请先打开项目或拖入 HTML 文件"
            return
        }

        guard let url = chooseSaveURL(defaultName: "document.pptx", contentTypes: [pptxContentType]) else { return }
        status = "Exporting editable PPTX..."

        exportCurrentHTML { [weak self] html in
            self?.renderExport(html: html, outputURL: url, format: .pptx)
        }
    }

    func presentExportPreflight() {
        guard hasOpenDocument else {
            status = "请先打开项目或拖入 HTML 文件"
            return
        }

        refreshHTMLDiagnostics()
        refreshHTMLVisualReviewSnapshot()
        isExportPreflightPresented = true
        status = "已打开导出预检"
    }

    func freezeCurrentHTMLLayout() {
        guard hasOpenDocument else {
            status = "请先打开项目或拖入 HTML 文件"
            return
        }

        guard documentMode == "html" else {
            status = "转为可编辑版适用于 HTML 文档模式"
            return
        }

        status = "正在转换可编辑版..."

        exportCurrentHTML { [weak self] html in
            guard let self else { return }

            if let index = self.activeTabIndex {
                self.tabs[index].content = html
                self.tabs[index].mode = "html"
                self.tabs[index].needsSnapshot = false
                self.clearEditorDirtyFlag()
            }

            guard let data = html.data(using: .utf8) else {
                self.status = "转换可编辑版失败：无法编码 HTML"
                return
            }

            let base64 = data.base64EncodedString()
            let baseHref = self.openedURL?.deletingLastPathComponent().absoluteString ?? ""
            guard let baseLiteral = self.jsStringLiteral(baseHref) else {
                self.status = "转换可编辑版失败：无法解析资源路径"
                return
            }

            let script = """
            window.ChiseloEditor?.importHTMLFromBase64('\(base64)', \(baseLiteral))
              .then(deck => JSON.stringify(deck));
            """

            self.webView?.evaluateJavaScript(script) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.status = "转换可编辑版失败：\(error.localizedDescription)"
                        return
                    }

                    guard let json = result as? String, !json.isEmpty else {
                        self.status = "转换可编辑版失败：没有可编辑对象结构"
                        return
                    }

                    let id = UUID()
                    let title = self.frozenLayoutTitle()
                    self.tabs.append(EditorTab(id: id, title: title, url: nil, mode: "deck", content: json, needsSnapshot: false))
                    self.activeTabID = id
                    self.openedURL = nil
                    self.loadDeckJSON(json)
                    self.status = "已转换为可编辑版：\(title)"
                }
            }
        }
    }

    private func exportCurrentHTML(completion: @escaping (String) -> Void) {
        guard hasOpenDocument else {
            status = "请先打开项目或拖入 HTML 文件"
            return
        }

        webView?.evaluateJavaScript("window.ChiseloEditor?.exportHTML();") { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.status = "Export failed: \(error.localizedDescription)"
                    return
                }

                guard let html = result as? String else {
                    self.status = "Export failed: no HTML returned"
                    return
                }

                completion(html)
            }
        }
    }

    private func renderExport(html: String, outputURL: URL, format: RenderExportFormat) {
        let baseURL = openedURL?.deletingLastPathComponent()
        let exporter = HTMLRenderExporter(html: html, baseURL: baseURL)
        activeRenderExporter = exporter

        if format == .pptx {
            exporter.renderEditablePages { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    self.activeRenderExporter = nil

                    switch result {
                    case .success(let pages):
                        do {
                            try HTMLRenderExporter.writeEditablePPTX(pages: pages, to: outputURL, baseURL: baseURL)
                            self.status = "Exported editable \(outputURL.lastPathComponent) (\(pages.count) page\(pages.count == 1 ? "" : "s"))"
                        } catch {
                            self.status = "Export failed: \(error.localizedDescription)"
                        }

                    case .failure(let error):
                        self.status = "Export failed: \(error.localizedDescription)"
                    }
                }
            }
            return
        }

        exporter.renderPages { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.activeRenderExporter = nil

                switch result {
                case .success(let pages):
                    do {
                        switch format {
                        case .pdf:
                            try HTMLRenderExporter.writePDF(pages: pages, to: outputURL)
                        case .pptx:
                            break
                        }
                        self.status = "Exported \(outputURL.lastPathComponent) (\(pages.count) page\(pages.count == 1 ? "" : "s"))"
                    } catch {
                        self.status = "Export failed: \(error.localizedDescription)"
                    }

                case .failure(let error):
                    self.status = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func replaceSelectedImage() {
        guard hasOpenDocument else {
            status = "请先打开项目或拖入 HTML 文件"
            return
        }

        guard documentMode == "html" else {
            status = "图片替换适用于 HTML 文档模式"
            return
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = imageContentTypes

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let mimeType = imageMIMEType(for: url)
            let base64 = data.base64EncodedString()
            guard let mimeLiteral = jsStringLiteral(mimeType) else { return }

            webView?.evaluateJavaScript("window.ChiseloEditor?.replaceSelectedImageFromBase64(\(mimeLiteral), '\(base64)');") { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.status = "Replace image failed: \(error.localizedDescription)"
                        return
                    }

                    if result == nil || result is NSNull {
                        self.status = "Select an image element first"
                    } else {
                        self.status = "Replaced image with \(url.lastPathComponent)"
                    }
                }
            }
        } catch {
            status = "Replace image failed: \(error.localizedDescription)"
        }
    }

    func editorCommand(_ command: String) {
        guard hasOpenDocument else {
            status = "请先打开项目或拖入 HTML 文件"
            return
        }

        runJavaScript("window.ChiseloEditor?.command('\(command)');")
    }

    func selectSlide(index: Int) {
        runJavaScript("window.ChiseloEditor?.selectSlide(\(index));")
    }

    func selectElement(id: String) {
        if let element = currentSlideElements.first(where: { $0.id == id }) {
            updatePublished(\.selectedElement, to: element)
        }

        guard let literal = jsStringLiteral(id) else { return }
        runJavaScript("window.ChiseloEditor?.selectElementById(\(literal));")
    }

    private func applyEditorBackdrop() {
        guard let literal = jsStringLiteral(editorBackdrop.rawValue) else { return }
        runJavaScript("window.ChiseloEditor?.setBackdropStyle?.(\(literal));")
    }

    private func markActiveTabNeedsSnapshot() {
        guard let index = activeTabIndex, !tabs[index].needsSnapshot else { return }
        tabs[index].needsSnapshot = true
    }

    private func clearEditorDirtyFlag() {
        runJavaScript("window.ChiseloEditor?.clearDirty?.();")
    }

    private func resetHTMLVisualSnapshots() {
        htmlVisualBaselineImage = nil
        pendingHTMLVisualBaselineCapture = false
        isCapturingHTMLVisualSnapshot = false
        updatePublished(\.htmlVisualSnapshotPair, to: .empty)
    }

    func selectHTMLNode(id: String) {
        guard let literal = jsStringLiteral(id) else { return }
        runJavaScript("window.ChiseloEditor?.selectHTMLById(\(literal));")
    }

    func refreshHTMLDiagnostics() {
        guard hasOpenDocument, documentMode == "html" else { return }

        webView?.evaluateJavaScript("JSON.stringify(window.ChiseloEditor?.getImportDiagnostics?.() ?? null);") { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.status = "预检刷新失败：\(error.localizedDescription)"
                    return
                }

                guard let json = result as? String,
                      json != "null",
                      let data = json.data(using: .utf8),
                      let diagnostics = try? JSONDecoder().decode(HTMLDiagnostics.self, from: data) else {
                    return
                }

                self.updatePublished(\.htmlDiagnostics, to: diagnostics)
            }
        }
    }

    private func capturePendingHTMLVisualBaselineIfNeeded() {
        guard pendingHTMLVisualBaselineCapture, documentMode == "html" else { return }
        pendingHTMLVisualBaselineCapture = false

        captureHTMLVisualSnapshot { [weak self] image in
            guard let self else { return }
            self.htmlVisualBaselineImage = image
            self.updatePublished(
                \.htmlVisualSnapshotPair,
                to: HTMLVisualSnapshotPair(baseline: image, current: nil, diff: nil, capturedAt: nil)
            )
        }
    }

    private func captureHTMLVisualSnapshot(completion: @escaping (NSImage?) -> Void) {
        guard let webView, hasOpenDocument, documentMode == "html" else {
            completion(nil)
            return
        }

        isCapturingHTMLVisualSnapshot = true
        let source = "JSON.stringify(window.ChiseloEditor?.prepareVisualReviewSnapshot?.() ?? null);"
        webView.evaluateJavaScript(source) { [weak self, weak webView] result, error in
            Task { @MainActor in
                guard let self else { return }
                guard let webView else {
                    self.isCapturingHTMLVisualSnapshot = false
                    completion(nil)
                    return
                }

                if let error {
                    self.isCapturingHTMLVisualSnapshot = false
                    self.status = "截图复核捕获失败：\(error.localizedDescription)"
                    completion(nil)
                    return
                }

                guard let json = result as? String,
                      json != "null",
                      let data = json.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let snapshotObject = object["snapshot"] as? [String: Any] else {
                    self.isCapturingHTMLVisualSnapshot = false
                    completion(nil)
                    return
                }
                let restoreState = object["state"]
                let plan = self.visualSnapshotCapturePlan(from: snapshotObject)

                guard !plan.segments.isEmpty else {
                    self.restoreHTMLVisualSnapshotState(restoreState, in: webView) {
                        self.isCapturingHTMLVisualSnapshot = false
                        completion(nil)
                    }
                    return
                }

                self.captureHTMLVisualSnapshotSegments(plan: plan, webView: webView, restoreState: restoreState, completion: completion)
            }
        }
    }

    private struct VisualSnapshotCapturePlan {
        var contentWidth: CGFloat
        var contentHeight: CGFloat
        var viewportHeight: CGFloat
        var segments: [CGFloat]
    }

    private func visualSnapshotCapturePlan(from object: [String: Any]) -> VisualSnapshotCapturePlan {
        let contentWidth = max(1, bridgeCGFloat(object["contentWidth"]) ?? 1)
        let contentHeight = max(1, bridgeCGFloat(object["contentHeight"]) ?? bridgeCGFloat(object["height"]) ?? 1)
        let viewportHeight = max(1, (object["rect"] as? [String: Any]).flatMap { bridgeCGFloat($0["height"]) } ?? contentHeight)
        let maxSegments = 6
        var segments: [CGFloat] = []
        let maxOffset = max(0, contentHeight - viewportHeight)
        if maxOffset <= 0 {
            segments = [0]
        } else {
            let naturalCount = Int(ceil(contentHeight / viewportHeight))
            let count = min(maxSegments, max(2, naturalCount))
            for index in 0..<count {
                let progress = CGFloat(index) / CGFloat(max(count - 1, 1))
                segments.append(maxOffset * progress)
            }
        }
        return VisualSnapshotCapturePlan(contentWidth: contentWidth, contentHeight: contentHeight, viewportHeight: viewportHeight, segments: Array(Set(segments)).sorted())
    }

    private func captureHTMLVisualSnapshotSegments(plan: VisualSnapshotCapturePlan, webView: WKWebView, restoreState: Any?, completion: @escaping (NSImage?) -> Void) {
        var captures: [(offset: CGFloat, image: NSImage)] = []

        func finish(_ image: NSImage?) {
            restoreHTMLVisualSnapshotState(restoreState, in: webView) {
                self.isCapturingHTMLVisualSnapshot = false
                completion(image)
            }
        }

        func captureNext(index: Int) {
            guard index < plan.segments.count else {
                finish(stitchedVisualSnapshot(captures: captures, plan: plan))
                return
            }

            let offset = plan.segments[index]
            webView.evaluateJavaScript("JSON.stringify(window.ChiseloEditor?.scrollVisualReviewSnapshotTo?.(\(offset)) ?? null);") { [weak self, weak webView] result, error in
                Task { @MainActor in
                    guard let self, let webView else { return }
                    if let error {
                        self.status = "截图复核捕获失败：\(error.localizedDescription)"
                        finish(nil)
                        return
                    }

                    guard let json = result as? String,
                          json != "null",
                          let data = json.data(using: .utf8),
                          let snapshotObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let rectObject = snapshotObject["rect"] as? [String: Any] else {
                        finish(nil)
                        return
                    }

                    let webBounds = webView.bounds
                    let rect = NSRect(
                        x: max(0, self.bridgeCGFloat(rectObject["x"]) ?? 0),
                        y: max(0, self.bridgeCGFloat(rectObject["y"]) ?? 0),
                        width: max(1, self.bridgeCGFloat(rectObject["width"]) ?? webBounds.width),
                        height: max(1, self.bridgeCGFloat(rectObject["height"]) ?? webBounds.height)
                    ).intersection(webBounds)

                    guard rect.width > 1, rect.height > 1 else {
                        captureNext(index: index + 1)
                        return
                    }

                    let config = WKSnapshotConfiguration()
                    config.rect = rect
                    webView.takeSnapshot(with: config) { [weak self] image, error in
                        Task { @MainActor in
                            guard let self else { return }
                            if let error {
                                self.status = "截图复核捕获失败：\(error.localizedDescription)"
                                finish(nil)
                                return
                            }
                            if let image {
                                captures.append((offset: offset, image: image))
                            }
                            captureNext(index: index + 1)
                        }
                    }
                }
            }
        }

        captureNext(index: 0)
    }

    private func stitchedVisualSnapshot(captures: [(offset: CGFloat, image: NSImage)], plan: VisualSnapshotCapturePlan) -> NSImage? {
        guard !captures.isEmpty, let first = captures.first?.image else { return nil }
        if captures.count == 1 {
            return first
        }

        let width = max(1, first.size.width)
        let scale = width / max(plan.contentWidth, 1)
        let height = max(1, plan.contentHeight * scale)
        let result = NSImage(size: NSSize(width: width, height: height))
        result.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        for capture in captures {
            let y = max(0, height - capture.offset * scale - capture.image.size.height)
            capture.image.draw(in: NSRect(x: 0, y: y, width: width, height: capture.image.size.height), from: .zero, operation: .copy, fraction: 1.0)
        }
        result.unlockFocus()
        return result
    }

    private func restoreHTMLVisualSnapshotState(_ state: Any?, in webView: WKWebView, completion: @escaping () -> Void) {
        guard let state,
              JSONSerialization.isValidJSONObject(state),
              let data = try? JSONSerialization.data(withJSONObject: state, options: []),
              let json = String(data: data, encoding: .utf8) else {
            completion()
            return
        }

        webView.evaluateJavaScript("window.ChiseloEditor?.restoreVisualReviewSnapshot?.(\(json));") { [weak self] _, error in
            Task { @MainActor in
                if let error {
                    self?.status = "截图视角恢复失败：\(error.localizedDescription)"
                }
                completion()
            }
        }
    }

    func refreshHTMLVisualReviewSnapshot() {
        guard hasOpenDocument, documentMode == "html" else {
            updatePublished(\.htmlVisualSnapshotPair, to: .empty)
            return
        }

        captureHTMLVisualSnapshot { [weak self] image in
            guard let self else { return }
            let diff = self.visualSnapshotDiff(baseline: self.htmlVisualBaselineImage, current: image)
            self.updatePublished(
                \.htmlVisualSnapshotPair,
                to: HTMLVisualSnapshotPair(
                    baseline: self.htmlVisualBaselineImage,
                    current: image,
                    diff: diff,
                    capturedAt: image == nil ? self.htmlVisualSnapshotPair.capturedAt : Date()
                )
            )
        }
    }

    private func visualSnapshotDiff(baseline: NSImage?, current: NSImage?) -> HTMLVisualSnapshotDiff? {
        guard let baseline,
              let current,
              let baselinePixels = rgbaPixels(for: baseline),
              let currentPixels = rgbaPixels(for: current),
              baselinePixels.width == currentPixels.width,
              baselinePixels.height == currentPixels.height,
              baselinePixels.bytes.count == currentPixels.bytes.count else {
            return nil
        }

        let width = baselinePixels.width
        let height = baselinePixels.height
        let pixelCount = max(width * height, 1)
        var changedPixels = 0
        var totalDelta = 0.0
        var maxDelta = 0.0
        var heatmapBytes = Array(repeating: UInt8(0), count: pixelCount * 4)

        var pixelIndex = 0
        var byteIndex = 0
        while byteIndex + 3 < baselinePixels.bytes.count {
            let redDelta = abs(Int(baselinePixels.bytes[byteIndex]) - Int(currentPixels.bytes[byteIndex]))
            let greenDelta = abs(Int(baselinePixels.bytes[byteIndex + 1]) - Int(currentPixels.bytes[byteIndex + 1]))
            let blueDelta = abs(Int(baselinePixels.bytes[byteIndex + 2]) - Int(currentPixels.bytes[byteIndex + 2]))
            let alphaDelta = abs(Int(baselinePixels.bytes[byteIndex + 3]) - Int(currentPixels.bytes[byteIndex + 3]))
            let normalizedDelta = Double(redDelta + greenDelta + blueDelta + alphaDelta) / (255.0 * 4.0)

            totalDelta += normalizedDelta
            maxDelta = max(maxDelta, normalizedDelta)
            if normalizedDelta >= 0.035 {
                changedPixels += 1
            }

            let intensity = UInt8(min(255, max(0, Int((normalizedDelta * 420).rounded()))))
            heatmapBytes[pixelIndex * 4] = 255
            heatmapBytes[pixelIndex * 4 + 1] = UInt8(max(0, 180 - Int(intensity) / 2))
            heatmapBytes[pixelIndex * 4 + 2] = 40
            heatmapBytes[pixelIndex * 4 + 3] = intensity

            pixelIndex += 1
            byteIndex += 4
        }

        return HTMLVisualSnapshotDiff(
            changedPixelRatio: Double(changedPixels) / Double(pixelCount),
            averageDelta: totalDelta / Double(pixelCount),
            maxDelta: maxDelta,
            sampleWidth: width,
            sampleHeight: height,
            heatmap: imageFromRGBABytes(heatmapBytes, width: width, height: height)
        )
    }

    private struct RGBAPixels {
        var width: Int
        var height: Int
        var bytes: [UInt8]
    }

    private func rgbaPixels(for image: NSImage, width targetWidth: Int = 192, height targetHeight: Int = 128) -> RGBAPixels? {
        let imageWidth = max(image.size.width, 1)
        let imageHeight = max(image.size.height, 1)
        let byteCount = targetWidth * targetHeight * 4
        var bytes = Array(repeating: UInt8(0), count: byteCount)
        guard let context = CGContext(
            data: &bytes,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight).fill()
        image.draw(in: fittedRect(imageSize: NSSize(width: imageWidth, height: imageHeight), targetSize: NSSize(width: targetWidth, height: targetHeight)), from: .zero, operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        return RGBAPixels(width: targetWidth, height: targetHeight, bytes: bytes)
    }

    private func fittedRect(imageSize: NSSize, targetSize: NSSize) -> NSRect {
        let scale = min(targetSize.width / max(imageSize.width, 1), targetSize.height / max(imageSize.height, 1))
        let width = max(1, imageSize.width * scale)
        let height = max(1, imageSize.height * scale)
        return NSRect(
            x: (targetSize.width - width) / 2,
            y: (targetSize.height - height) / 2,
            width: width,
            height: height
        )
    }

    private func imageFromRGBABytes(_ bytes: [UInt8], width: Int, height: Int) -> NSImage? {
        var mutableBytes = bytes
        guard let context = CGContext(
            data: &mutableBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    func updateElement(_ element: EditorElement) {
        updatePublished(\.selectedElement, to: element)
        markActiveTabNeedsSnapshot()

        do {
            let data = try encoder.encode(element)
            guard let json = String(data: data, encoding: .utf8) else { return }
            runJavaScript("window.ChiseloEditor?.updateElement(\(json));")
        } catch {
            status = "Element update failed: \(error.localizedDescription)"
        }
    }

    private func loadDeckJSON(_ json: String) {
        guard let data = json.data(using: .utf8) else { return }

        do {
            let decodedDeck = try JSONDecoder().decode(EditorDeck.self, from: data)
            resetHTMLVisualSnapshots()
            deck = decodedDeck
            selectedElement = nil
            selectedSlideIndex = 0
            documentMode = "deck"
            selectionPath = nil
            htmlTree = []
            htmlDiagnostics = .empty
            refreshDocumentStats()
            status = "画布精修：\(openedURL?.lastPathComponent ?? "未命名")"
            let base64 = data.base64EncodedString()
            runJavaScript("window.ChiseloEditor?.loadDeckFromBase64('\(base64)');")
        } catch {
            status = "Chiselo 项目无效：\(error.localizedDescription)"
        }
    }

    private func importHTML(_ html: String, from url: URL?) {
        guard let data = html.data(using: .utf8) else { return }
        resetHTMLVisualSnapshots()
        pendingHTMLVisualBaselineCapture = true
        deck = nil
        selectedElement = nil
        selectedSlideIndex = 0
        documentMode = "html"
        selectionPath = nil
        htmlTree = []
        htmlDiagnostics = .empty
        refreshDocumentStats()
        status = "HTML 文档模式：\(url?.lastPathComponent ?? "未命名 HTML")"
        let base64 = data.base64EncodedString()
        let baseHref = url?.deletingLastPathComponent().absoluteString ?? ""
        guard let baseLiteral = jsStringLiteral(baseHref) else { return }
        runJavaScript("window.ChiseloEditor?.openHTMLFromBase64('\(base64)', \(baseLiteral))?.catch(error => console.error(error));")
    }

    private func runJavaScript(_ source: String) {
        webView?.evaluateJavaScript(source) { [weak self] _, error in
            guard let error else { return }
            Task { @MainActor in
                self?.status = "JavaScript failed: \(error.localizedDescription)"
            }
        }
    }

    private func saveHTML(_ html: String, defaultName: String = "document.html") {
        guard let url = chooseSaveURL(defaultName: defaultName, contentTypes: [.html]) else { return }

        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
            status = "Exported \(url.lastPathComponent)"
        } catch {
            status = "Export failed: \(error.localizedDescription)"
        }
    }

    private var editableHTMLDefaultName: String {
        guard let openedURL else { return "document-editable.html" }
        let baseName = openedURL.deletingPathExtension().lastPathComponent
        let safeName = baseName.isEmpty ? "document" : baseName
        return "\(safeName)-editable.html"
    }

    private func selfEditableHTML(from html: String) -> String {
        let runtime = Self.selfEditableHTMLRuntime
        if let range = html.range(of: "</body>", options: [.caseInsensitive, .backwards]) {
            return html.replacingCharacters(in: range, with: "\n\(runtime)\n</body>")
        }

        if let range = html.range(of: "</html>", options: [.caseInsensitive, .backwards]) {
            return html.replacingCharacters(in: range, with: "\n\(runtime)\n</html>")
        }

        return "\(html)\n\(runtime)\n"
    }

    private func saveCurrentHTML() {
        webView?.evaluateJavaScript("window.ChiseloEditor?.exportHTML();") { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.status = "Save failed: \(error.localizedDescription)"
                    return
                }

                guard let html = result as? String else {
                    self.status = "Save failed: no HTML returned"
                    return
                }

                guard let url = self.openedURL ?? self.chooseSaveURL(defaultName: "document.html", contentTypes: [.html]) else { return }

                do {
                    let snapshotURL = try self.safeFileHistory.protectFileBeforeOverwrite(at: url, fallbackExtension: "html")
                    try html.write(to: url, atomically: true, encoding: .utf8)
                    self.openedURL = url
                    self.updateActiveTabAfterSave(url: url, mode: "html", content: html)
                    self.status = self.safeFileHistory.saveStatus(for: url, snapshotURL: snapshotURL)
                } catch {
                    self.status = "Save failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func chooseSaveURL(defaultName: String, contentTypes: [UTType]) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = contentTypes
        panel.nameFieldStringValue = defaultName
        return panel.runModal() == .OK ? panel.url : nil
    }

    private var deckJSON: String? {
        guard let deck else { return nil }
        guard let data = try? encoder.encode(deck) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private var deckContentTypes: [UTType] {
        [.json, UTType(filenameExtension: "aislide")].compactMap { $0 }
    }

    private var openContentTypes: [UTType] {
        [.json, .html, UTType(filenameExtension: "htm"), UTType(filenameExtension: "xhtml"), UTType(filenameExtension: "aislide")].compactMap { $0 }
    }

    private var pptxContentType: UTType {
        UTType(filenameExtension: "pptx") ?? .data
    }

    private var imageContentTypes: [UTType] {
        [
            .image,
            UTType(filenameExtension: "svg"),
            UTType(filenameExtension: "webp")
        ].compactMap { $0 }
    }

    private func imageMIMEType(for url: URL) -> String {
        if let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType {
            return mimeType
        }

        switch url.pathExtension.lowercased() {
        case "svg":
            return "image/svg+xml"
        case "webp":
            return "image/webp"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        default:
            return "image/png"
        }
    }

    private func jsStringLiteral(_ string: String) -> String? {
        guard let data = try? JSONEncoder().encode(string) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private var activeTabIndex: Int? {
        guard let activeTabID else { return nil }
        return tabs.firstIndex(where: { $0.id == activeTabID })
    }

    private func captureActiveTabSnapshot(completion: @escaping () -> Void) {
        guard let index = activeTabIndex, webView != nil else {
            completion()
            return
        }

        guard tabs[index].needsSnapshot else {
            completion()
            return
        }

        let mode = tabs[index].mode
        let source: String
        if mode == "html" || documentMode == "html" {
            source = "window.ChiseloEditor?.exportHTML();"
        } else {
            source = "JSON.stringify(window.ChiseloEditor?.getDeck?.() ?? null);"
        }

        webView?.evaluateJavaScript(source) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.status = "Could not snapshot tab: \(error.localizedDescription)"
                    completion()
                    return
                }

                guard let currentIndex = self.activeTabIndex else {
                    completion()
                    return
                }

                if let html = result as? String, mode == "html" || self.documentMode == "html" {
                    self.tabs[currentIndex].content = html
                } else if let json = result as? String, json != "null", mode == "deck" {
                    self.tabs[currentIndex].content = self.prettyDeckJSON(from: json) ?? json
                } else if mode == "deck", let json = self.deckJSON {
                    self.tabs[currentIndex].content = json
                }

                self.tabs[currentIndex].needsSnapshot = false
                self.clearEditorDirtyFlag()
                completion()
            }
        }
    }

    private func resetToWelcome() {
        activeTabID = nil
        openedURL = nil
        tabSafetyInfo.removeAll()
        deck = nil
        selectedElement = nil
        selectedSlideIndex = 0
        documentMode = "deck"
        selectionPath = nil
        htmlTree = []
        htmlDiagnostics = .empty
        resetEditorHistoryState()
        resetHTMLVisualSnapshots()
        refreshDocumentStats()
        status = "打开项目或拖入 HTML 文件开始"
    }

    private func loadTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        isSwitchingTabs = true
        activeTabID = id
        tabs[index].needsSnapshot = false
        let tab = tabs[index]
        openedURL = tab.url
        selectedElement = nil
        selectionPath = nil
        resetEditorHistoryState()

        if tab.mode == "html" {
            importHTML(tab.content, from: tab.url)
        } else {
            loadDeckJSON(tab.content)
        }

        isSwitchingTabs = false
    }

    private func resetEditorHistoryState() {
        updatePublished(\.canUndoEdit, to: false)
        updatePublished(\.canRedoEdit, to: false)
        updatePublished(\.undoDepth, to: 0)
        updatePublished(\.redoDepth, to: 0)
    }

    private func canOpenURL(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let allowedExtensions: Set<String> = ["html", "htm", "xhtml", "json", "aislide"]
        return allowedExtensions.contains(url.pathExtension.lowercased())
    }

    private func applyOpenTabReadResults(_ results: [OpenTabReadResult]) {
        var lastID: UUID?
        var lastFailure: String?
        var lastSafetyWarning: String?
        var lastBackupURL: URL?
        var openedCount = 0
        var reusedCount = 0

        for result in results {
            switch result {
            case .success(let payload):
                if let existingID = existingTabID(for: payload.url) {
                    lastID = existingID
                    reusedCount += 1
                    continue
                }

                var safety = OpenTabSafetyInfo(backupURL: nil, backupCreated: false, warning: nil)
                do {
                    let backup = try safeFileHistory.backupOriginalIfNeeded(
                        at: payload.url,
                        fallbackExtension: payload.mode == "html" ? "html" : "aislide"
                    )
                    safety.backupURL = backup?.url
                    safety.backupCreated = backup?.created == true
                    lastBackupURL = backup?.url
                } catch {
                    let message = "安全备份失败：\(payload.url.lastPathComponent) \(error.localizedDescription)"
                    safety.warning = message
                    lastSafetyWarning = message
                }

                let id = UUID()
                tabs.append(EditorTab(id: id, title: payload.title, url: payload.url, mode: payload.mode, content: payload.content, needsSnapshot: false))
                tabSafetyInfo[id] = safety
                lastID = id
                openedCount += 1

            case .failure(_, let message):
                lastFailure = message
            }
        }

        if let lastID {
            loadTab(id: lastID)
            let title = tabs.first(where: { $0.id == lastID })?.title ?? "文件"
            if results.count == 1, reusedCount == 1, openedCount == 0 {
                status = "已切换到已打开的 \(title)"
            } else if results.count == 1 {
                status = "已打开 \(title)"
            } else if openedCount == 0, reusedCount > 0 {
                status = "这些文件已经打开，已切换到 \(title)"
            } else {
                status = "已打开 \(openedCount) 个新文件"
            }

            if let lastSafetyWarning {
                status += " · \(lastSafetyWarning)"
            } else if openedCount > 0, let lastBackupURL {
                status += " · 已准备原始备份 \(lastBackupURL.lastPathComponent)"
            }
        } else {
            status = lastFailure ?? "没有可打开的文件"
        }
    }

    private func existingTabID(for url: URL) -> UUID? {
        guard let targetPath = normalizedFilePath(for: url) else { return nil }
        return tabs.first { tab in
            normalizedFilePath(for: tab.url) == targetPath
        }?.id
    }

    private func normalizedFilePath(for url: URL?) -> String? {
        guard let url, url.isFileURL else { return nil }
        return url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func updateActiveTabAfterSave(url: URL, mode: String, content: String) {
        guard let index = activeTabIndex else { return }
        tabs[index].url = url
        tabs[index].title = tabTitle(for: url)
        tabs[index].mode = mode
        tabs[index].content = content
        tabs[index].needsSnapshot = false
        clearEditorDirtyFlag()
    }

    private func tabTitle(for url: URL) -> String {
        let title = url.lastPathComponent
        return title.isEmpty ? "未命名" : title
    }

    private func frozenLayoutTitle() -> String {
        let baseTitle = activeTabIndex.flatMap { tabs.indices.contains($0) ? tabs[$0].title : nil } ?? "HTML 文档"
        let root = baseTitle
            .replacingOccurrences(of: " - 冻结版式", with: "")
            .replacingOccurrences(of: " - 可编辑版", with: "")
        var title = "\(root) - 可编辑版"
        var suffix = 2
        let existing = Set(tabs.map(\.title))
        while existing.contains(title) {
            title = "\(root) - 可编辑版 \(suffix)"
            suffix += 1
        }
        return title
    }

    private func prettyDeckJSON(from json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let deck = try? JSONDecoder().decode(EditorDeck.self, from: data),
              let encoded = try? encoder.encode(deck) else {
            return nil
        }

        return String(data: encoded, encoding: .utf8)
    }

}

private func readOpenTabPayload(_ url: URL) -> OpenTabReadResult {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer {
        if didAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }

    do {
        let content = try readTextFile(at: url)
        let ext = url.pathExtension.lowercased()
        let mode = ["html", "htm", "xhtml"].contains(ext) ? "html" : "deck"

        if mode == "deck" {
            guard let data = content.data(using: .utf8) else {
                return .failure(filename: url.lastPathComponent, message: "Could not read \(url.lastPathComponent)")
            }
            _ = try JSONDecoder().decode(EditorDeck.self, from: data)
        }

        let title = url.lastPathComponent.isEmpty ? "未命名" : url.lastPathComponent
        return .success(OpenTabPayload(title: title, url: url, mode: mode, content: content))
    } catch {
        return .failure(filename: url.lastPathComponent, message: "Open failed for \(url.lastPathComponent): \(error.localizedDescription)")
    }
}

private func readTextFile(at url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    for encoding in textFileEncodingCandidates {
        if let string = String(data: data, encoding: encoding) {
            return string
        }
    }

    throw CocoaError(.fileReadCorruptFile)
}

private let textFileEncodingCandidates: [String.Encoding] = [
    .utf8,
    .utf16,
    .utf16LittleEndian,
    .utf16BigEndian,
    .utf32,
    .utf32LittleEndian,
    .utf32BigEndian,
    .isoLatin1,
    .windowsCP1252,
    .ascii,
    String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
]

private extension Array where Element == OpenTabReadResult {
    var successCount: Int {
        reduce(0) { total, result in
            if case .success = result {
                return total + 1
            }
            return total
        }
    }
}

private enum RenderExportFormat {
    case pdf
    case pptx
}
