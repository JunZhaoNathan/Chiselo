import SwiftUI
import WebKit

struct WebEditorView: NSViewRepresentable {
    @EnvironmentObject private var model: EditorModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "chiselo")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController

        let webView = DropAwareWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.editorModel = model
        context.coordinator.editorURL = editorIndexURL()
        webView.allowsMagnification = false
        webView.setValue(false, forKey: "drawsBackground")

        model.attachWebView(webView)

        if let url = editorIndexURL() {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            model.status = "Editor resource missing"
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "chiselo")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private weak var model: EditorModel?

        init(model: EditorModel) {
            self.model = model
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "chiselo",
                  let body = message.body as? [String: Any],
                  let model else {
                return
            }

            Task { @MainActor in
                model.handleBridgeMessage(body)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                guard let model else { return }
                model.status = model.hasOpenDocument ? "编辑器已就绪" : "打开项目或拖入 HTML 文件开始"
            }
        }

        var editorURL: URL?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let editorWebView = webView as? DropAwareWebView else {
                decisionHandler(.cancel)
                return
            }
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false
            let allowed = HTMLRuntimeSecurityPolicy.allowsNavigation(
                to: navigationAction.request.url,
                isMainFrame: isMainFrame,
                mode: editorWebView.runtimeSecurityMode,
                editorURL: editorURL
            )
            decisionHandler(allowed ? .allow : .cancel)
        }
    }
}

final class DropAwareWebView: WKWebView {
    weak var editorModel: EditorModel?
    private let runtimeSecurityController = HTMLRuntimeSecurityController()
    private(set) var runtimeSecurityMode: HTMLRuntimeSecurityMode = .isolated

    private let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        registerForDraggedTypes([.fileURL, filenamesType])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, filenamesType])
    }

    func applyRuntimeSecurity(
        _ mode: HTMLRuntimeSecurityMode,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        runtimeSecurityController.apply(mode, to: configuration.userContentController) { [weak self] result in
            if case .success = result {
                self?.runtimeSecurityMode = mode
            }
            completion(result)
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let acceptsDrop = !fileURLs(from: sender.draggingPasteboard).isEmpty
        setDropTargeted(acceptsDrop)
        return acceptsDrop ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let acceptsDrop = !fileURLs(from: sender.draggingPasteboard).isEmpty
        setDropTargeted(acceptsDrop)
        return acceptsDrop ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setDropTargeted(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        setDropTargeted(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            setDropTargeted(false)
            return false
        }

        let model = editorModel
        Task { @MainActor in
            model?.openDroppedURLs(urls)
        }
        return true
    }

    private func setDropTargeted(_ targeted: Bool) {
        let model = editorModel
        Task { @MainActor in
            model?.setFileDropTargeted(targeted)
        }
    }

    private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        var urls: [URL] = []

        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) ?? []
        for object in objects {
            if let url = object as? URL {
                urls.append(url)
            } else if let url = object as? NSURL {
                urls.append(url as URL)
            }
        }

        if let filenames = pasteboard.propertyList(forType: filenamesType) as? [String] {
            urls.append(contentsOf: filenames.map { URL(fileURLWithPath: $0) })
        }

        var seen = Set<String>()
        return urls.filter { url in
            guard url.isFileURL else { return false }
            let key = url.standardizedFileURL.path
            return seen.insert(key).inserted
        }
    }
}

private func editorIndexURL() -> URL? {
    let resourceBundleURL = Bundle.main.resourceURL?
        .appendingPathComponent("Chiselo_Chiselo.bundle")

    let appBundleCandidates = [
        resourceBundleURL?.appendingPathComponent("Editor").appendingPathComponent("index.html"),
        resourceBundleURL?.appendingPathComponent("index.html")
    ]

    for candidate in appBundleCandidates.compactMap({ $0 }) {
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
    }

    return Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "Editor")
        ?? Bundle.module.url(forResource: "index", withExtension: "html")
}
