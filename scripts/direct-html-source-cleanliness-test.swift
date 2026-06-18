import AppKit
import Foundation
import WebKit

final class DirectHTMLSourceCleanlinessTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "sourceCleanliness")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 840), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.fail("Timed out waiting for direct HTML source cleanliness result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let base64 = Data(Self.fixtureHTML.utf8).base64EncodedString()
        let script = """
        void (async () => {
          const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));
          const editor = window.ChiseloEditor;
          await editor.openHTMLFromBase64('\(base64)', '');
          await sleep(180);

          const selected = editor.selectHTML('#editable');
          if (!selected) throw new Error('Could not select editable fixture text.');
          editor.command('editText');
          await sleep(140);

          const frame = document.querySelector('iframe.html-frame');
          const doc = frame && frame.contentDocument;
          const node = doc && doc.querySelector('#editable');
          if (!node || node.getAttribute('contenteditable') !== 'true') {
            throw new Error('Fixture did not enter direct text editing.');
          }

          const exportedWhileEditing = editor.exportHTML();
          const diagnosticsWhileEditing = editor.getImportDiagnostics();
          const forbidden = [
            'data-chiselo',
            '--chiselo-edit-',
            'data-chiselo-base',
            'data-chiselo-style'
          ].filter(token => exportedWhileEditing.includes(token));

          const preservedOriginalEditable = exportedWhileEditing.includes('id="editable" contenteditable="plaintext-only" spellcheck="false"');
          const otherEditablePreserved = exportedWhileEditing.includes('id="native" contenteditable="true" spellcheck="false"');

          if (forbidden.length || !preservedOriginalEditable || !otherEditablePreserved || diagnosticsWhileEditing.cleanExport !== true || diagnosticsWhileEditing.exportArtifactCount !== 0 || diagnosticsWhileEditing.sourceCleanlinessScore !== 100) {
            throw new Error(JSON.stringify({
              forbidden,
              preservedOriginalEditable,
              otherEditablePreserved,
              cleanExport: diagnosticsWhileEditing.cleanExport,
              exportArtifactCount: diagnosticsWhileEditing.exportArtifactCount,
              sourceCleanlinessScore: diagnosticsWhileEditing.sourceCleanlinessScore,
              exportedSnippet: exportedWhileEditing.slice(0, 420)
            }));
          }

          node.blur();
          await sleep(120);
          const exportedAfterBlur = editor.exportHTML();
          if (!exportedAfterBlur.includes('id="editable" contenteditable="plaintext-only" spellcheck="false"') || exportedAfterBlur.includes('--chiselo-edit-') || exportedAfterBlur.includes('data-chiselo')) {
            throw new Error('Export after blur did not preserve original editable attributes cleanly.');
          }

          window.webkit.messageHandlers.sourceCleanliness.postMessage({
            type: 'result',
            cleanExport: diagnosticsWhileEditing.cleanExport,
            exportArtifactCount: diagnosticsWhileEditing.exportArtifactCount,
            sourceCleanlinessScore: diagnosticsWhileEditing.sourceCleanlinessScore,
            exportedLength: exportedWhileEditing.length
          });
        })().catch(error => {
          window.webkit.messageHandlers.sourceCleanliness.postMessage({
            type: 'error',
            message: String(error && error.message || error),
            stack: String(error && error.stack || '')
          });
        });
        """

        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error {
                self?.fail("JavaScript evaluation failed: \(error.localizedDescription)")
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "sourceCleanliness", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown source cleanliness error.")
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            print(string)
        }
        exit(0)
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML source cleanliness test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Source Cleanliness Fixture</title>
      <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        main { width: 720px; min-height: 320px; padding: 48px; }
        p { font-size: 24px; line-height: 1.3; }
      </style>
    </head>
    <body>
      <main>
        <p id="editable" contenteditable="plaintext-only" spellcheck="false">Editable source text</p>
        <p id="native" contenteditable="true" spellcheck="false">Native editable text</p>
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

let test = DirectHTMLSourceCleanlinessTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
