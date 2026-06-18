import AppKit
import Foundation
import WebKit

final class VisualChangeAddedRevertTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?
    private var didStart = false

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "addedRevert")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 980, height: 760), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.fail("Timed out waiting for added visual change revert result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.runFixture()
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "addedRevert", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown added visual revert failure.")
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            print(string)
        }
        exit(0)
    }

    private func runFixture() {
        guard !didStart else { return }
        didStart = true

        let base64 = Data(Self.fixtureHTML.utf8).base64EncodedString()
        let script = """
        void (async () => {
          const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));
          const editor = window.ChiseloEditor;
          await editor.openHTMLFromBase64('\(base64)', '');
          await sleep(520);

          const source = editor.selectHTML('#duplicateMe');
          if (!source) throw new Error('Could not select duplicate fixture object.');
          editor.command('duplicate');
          await sleep(260);

          let diagnostics = editor.getImportDiagnostics();
          const addedItem = (diagnostics.visualChangeItems || []).find(item => item.kind === '新增对象' && item.canRevert === true && String(item.label || '').includes('Duplicate me'));
          if (!addedItem || !addedItem.changeKey || !addedItem.elementId) {
            throw new Error(`Expected revertable added-object visual change, got ${JSON.stringify(diagnostics.visualChangeItems)}`);
          }
          if (!String(addedItem.detail || '').includes('移除')) {
            throw new Error(`Expected added-object detail to explain removal, got ${JSON.stringify(addedItem)}`);
          }

          const beforeCount = (editor.exportHTML().match(/Duplicate me safely/g) || []).length;
          if (beforeCount < 2) {
            throw new Error(`Duplicated object did not appear in exported HTML before revert. Count: ${beforeCount}`);
          }

          const revertResult = editor.revertVisualChange(addedItem.changeKey);
          await sleep(260);
          if (!revertResult || revertResult.ok !== true || revertResult.kind !== '新增对象') {
            throw new Error(`Expected successful added-object revert, got ${JSON.stringify(revertResult)}`);
          }

          const afterCount = (editor.exportHTML().match(/Duplicate me safely/g) || []).length;
          if (afterCount !== 1) {
            throw new Error(`Added object was not removed from exported HTML after revert. Count: ${afterCount}`);
          }

          diagnostics = editor.getImportDiagnostics();
          if ((diagnostics.visualChangeItems || []).some(item => item.kind === '新增对象' && String(item.label || '').includes('Duplicate me'))) {
            throw new Error(`Added-object visual change should clear after revert, got ${JSON.stringify(diagnostics.visualChangeItems)}`);
          }

          window.webkit.messageHandlers.addedRevert.postMessage({
            type: 'result',
            addedItem,
            diagnostics,
            history: editor.getHistoryState()
          });
        })().catch(error => {
          window.webkit.messageHandlers.addedRevert.postMessage({
            type: 'error',
            message: String(error && error.message || error),
            stack: String(error && error.stack || '')
          });
        });
        """

        webView?.evaluateJavaScript(script) { [weak self] _, error in
            if let error {
                self?.fail("Could not run added visual revert fixture: \(error.localizedDescription)")
            }
        }
    }

    private func fail(_ message: String) -> Never {
        fputs("Visual change added revert test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        main { width: 680px; min-height: 360px; padding: 56px; box-sizing: border-box; background: #f8fafc; }
        #duplicateMe { width: 260px; min-height: 96px; padding: 18px; background: #fff7ed; color: #9a3412; border-radius: 16px; box-sizing: border-box; }
      </style>
    </head>
    <body>
      <main>
        <section id="duplicateMe">Duplicate me safely</section>
      </main>
    </body>
    </html>
    """
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = projectRoot
    .appendingPathComponent("Chiselo")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Editor")
    .appendingPathComponent("index.html")

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let test = VisualChangeAddedRevertTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
