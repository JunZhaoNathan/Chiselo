import AppKit
import Foundation
import WebKit

final class HTMLPrecisionEditingDiagnosticsTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let htmlURL: URL
    private var webView: WKWebView?

    init(editorURL: URL, htmlURL: URL) {
        self.editorURL = editorURL
        self.htmlURL = htmlURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "precisionDiagnostics")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 900), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.fail("Timed out waiting for precision editing diagnostics.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        do {
            let html = try String(contentsOf: htmlURL, encoding: .utf8)
            guard let data = html.data(using: .utf8) else {
                fail("Could not encode fixture HTML.")
            }

            let base64 = data.base64EncodedString()
            let baseHref = htmlURL.deletingLastPathComponent().absoluteString
            let baseLiteral = try jsStringLiteral(baseHref)
            let script = """
            void window.ChiseloEditor.openHTMLFromBase64('\(base64)', \(baseLiteral))
              .then(async () => {
                await new Promise((resolve) => setTimeout(resolve, 120));
                const diagnostics = window.ChiseloEditor.getImportDiagnostics();
                const clippedSelection = window.ChiseloEditor.selectHTML('.moved-chip', { reveal: false });
                const cellSelection = window.ChiseloEditor.selectHTML('td', { reveal: false });
                const managedSelection = window.ChiseloEditor.selectHTML('.managed-grid > div', { reveal: false });
                const freeSelection = window.ChiseloEditor.selectHTML('h1', { reveal: false });
                const issueKinds = new Set((diagnostics.issues || []).map((item) => item.kind));
                const assertions = {
                  clippedGeometryDetected: (diagnostics.clippedGeometryCount || 0) >= 1,
                  clippedGeometryTarget: typeof diagnostics.clippedGeometryElementId === 'string' && diagnostics.clippedGeometryElementId.length > 0,
                  clippedSafetyDetected: clippedSelection?.editSafetyLevel === 'danger' && typeof clippedSelection.editSafetyContainerId === 'string' && clippedSelection.editSafetyContainerId.length > 0,
                  clipContainerDetected: (diagnostics.clipContainerCount || 0) >= 2,
                  clippedContentDetected: (diagnostics.clippedContentCount || 0) >= 1,
                  tableClipRiskDetected: (diagnostics.tableClipRiskCount || 0) >= 1,
                  tableClipTarget: typeof diagnostics.tableClipRiskElementId === 'string' && diagnostics.tableClipRiskElementId.length > 0,
                  tableCellSafetyDetected: cellSelection?.editSafetyLevel === 'locked' && /表格/.test(cellSelection.editSafetyTitle || '') && typeof cellSelection.editSafetyContainerId === 'string',
                  layoutManagedDetected: (diagnostics.layoutManagedObjectCount || 0) >= 1,
                  layoutManagedSafetyDetected: managedSelection?.editSafetyLevel === 'caution' && /布局/.test(managedSelection.editSafetyTitle || ''),
                  freeSafetyDetected: freeSelection?.editSafetyLevel === 'free',
                  clipIssueDetected: issueKinds.has('clipped-geometry'),
                  tableIssueDetected: issueKinds.has('table-clip-risk'),
                  containerIssueDetected: issueKinds.has('clip-container-risk'),
                  clippedIssueRelatedTarget: (diagnostics.issues || []).some((item) => item.kind === 'clipped-geometry' && typeof item.relatedElementId === 'string' && item.relatedElementId.length > 0)
                };
                const failed = Object.entries(assertions)
                  .filter((entry) => entry[1] !== true)
                  .map((entry) => entry[0]);
                if (failed.length) {
                  throw new Error(JSON.stringify({ failed, assertions, diagnostics, clippedSelection, cellSelection, managedSelection, freeSelection }));
                }
                window.webkit.messageHandlers.precisionDiagnostics.postMessage({
                  type: 'result',
                  assertions,
                  diagnostics,
                  safety: {
                    clipped: clippedSelection,
                    cell: cellSelection,
                    managed: managedSelection,
                    free: freeSelection
                  }
                });
              })
              .catch(error => {
                window.webkit.messageHandlers.precisionDiagnostics.postMessage({
                  type: 'error',
                  message: String(error && error.message || error),
                  stack: String(error && error.stack || '')
                });
              });
            """

            webView.evaluateJavaScript(script) { _, error in
                if let error {
                    self.fail("JavaScript evaluation failed: \(error.localizedDescription)")
                }
            }
        } catch {
            fail("Could not read fixture HTML: \(error.localizedDescription)")
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "precisionDiagnostics", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown JavaScript error.")
            return
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) {
            print(output)
            exit(0)
        }

        fail("Could not serialize precision diagnostics result.")
    }

    private func jsStringLiteral(_ string: String) throws -> String {
        let data = try JSONEncoder().encode(string)
        return String(data: data, encoding: .utf8) ?? "\"\""
    }

    private func fail(_ message: String) -> Never {
        fputs("HTML precision editing diagnostics test failed: \(message)\n", stderr)
        exit(1)
    }
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = projectRoot
    .appendingPathComponent("Chiselo")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Editor")
    .appendingPathComponent("index.html")
let defaultHTMLURL = projectRoot
    .appendingPathComponent("scripts")
    .appendingPathComponent("fixtures")
    .appendingPathComponent("precision-editing-risk.html")
let htmlPath = CommandLine.arguments.dropFirst().first ?? defaultHTMLURL.path
let htmlURL = URL(fileURLWithPath: htmlPath)

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let test = HTMLPrecisionEditingDiagnosticsTest(editorURL: editorURL, htmlURL: htmlURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
