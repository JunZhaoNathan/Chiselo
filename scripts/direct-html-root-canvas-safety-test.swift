import AppKit
import Foundation
import WebKit

final class DirectHTMLRootCanvasSafetyTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?
    private var started = false

    init(editorURL: URL) { self.editorURL = editorURL }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "rootCanvasSafety")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 820), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            self?.fail("Timed out waiting for root/canvas safety result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !started else { return }
        started = true
        let html = """
        <!doctype html><html><head><meta charset="utf-8"><style>
        body { margin: 0; } #container { width: 640px; padding: 20px; }
        #hidden, script { display: none; } #bottom { margin-top: 1200px; height: 160px; }
        </style></head><body><main id="container"><span id="hidden">hidden</span><p id="visible">Visible child</p><script>ignored()</script><p id="next">Next sibling</p></main><section id="bottom">Bottom content</section></body></html>
        """
        let base64 = Data(html.utf8).base64EncodedString()
        guard let encoded = try? JSONEncoder().encode(base64),
              let base64Literal = String(data: encoded, encoding: .utf8) else {
            fail("Could not encode fixture HTML.")
        }
        let script = """
        void (async () => {
          const editor = window.ChiseloEditor;
          const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));
          await editor.openHTMLFromBase64(\(base64Literal), '');
          await wait(160);
          const beforeExport = editor.exportHTML();
          const bodySelection = editor.selectHTML('body');
          const htmlSelection = editor.selectHTML('html');
          const rejectedText = editor.setSelectedHTMLText('MUST NOT REPLACE BODY');
          const afterRejectedExport = editor.exportHTML();
          const container = editor.selectHTML('#container');
          editor.command('selectFirstChild');
          await wait(50);
          const child = editor.getSelection();
          editor.command('selectNextSibling');
          await wait(50);
          const sibling = editor.getSelection();
          const beforeDelete = editor.getViewportState();
          editor.selectHTML('#bottom');
          editor.command('delete');
          await wait(140);
          const afterDelete = editor.getViewportState();
          const result = {
            bodyRejected: bodySelection === null,
            htmlRejected: htmlSelection === null,
            textRejected: rejectedText === null,
            exportUnchanged: beforeExport === afterRejectedExport,
            childSkippedHidden: String(child?.htmlPath || '').endsWith('p#visible'),
            siblingSkippedHiddenAndScript: String(sibling?.htmlPath || '').includes('p#next'),
            childId: child?.id || null,
            siblingId: sibling?.id || null,
            childPath: child?.htmlPath || null,
            siblingPath: sibling?.htmlPath || null,
            canvasShrankAfterElementDelete: afterDelete.stageHeight < beforeDelete.stageHeight,
            beforeHeight: beforeDelete.stageHeight,
            afterHeight: afterDelete.stageHeight
          };
          if (Object.values(result).some(value => value === false)) throw new Error(JSON.stringify(result));
          window.webkit.messageHandlers.rootCanvasSafety.postMessage({ type: 'result', ...result });
        })().catch(error => window.webkit.messageHandlers.rootCanvasSafety.postMessage({ type: 'error', message: String(error?.message || error) }));
        """
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error { self?.fail("JavaScript evaluation failed: \(error.localizedDescription)") }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "rootCanvasSafety", let body = message.body as? [String: Any] else { return }
        if body["type"] as? String == "error" { fail(body["message"] as? String ?? "Unknown root/canvas safety error.") }
        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) { print(output) }
        exit(0)
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML root/canvas safety test failed: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = root.appendingPathComponent("Chiselo/Resources/Editor/index.html")
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let test = DirectHTMLRootCanvasSafetyTest(editorURL: editorURL)
DispatchQueue.main.async { test.start() }
app.run()
