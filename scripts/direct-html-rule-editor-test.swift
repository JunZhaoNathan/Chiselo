import AppKit
import Foundation
import WebKit

final class DirectHTMLRuleEditorTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "ruleEditor")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 840), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 16) { [weak self] in
            self?.fail("Timed out waiting for rule editor result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let base64 = Data(Self.fixtureHTML.utf8).base64EncodedString()
        let script = """
        void (async () => {
          const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));
          const editor = window.ChiseloEditor;
          await editor.openHTMLFromBase64('\(base64)', '');
          await sleep(220);

          const title = editor.selectHTML('.hero-title');
          if (!title) throw new Error('Could not select .hero-title');
          const originalRule = String(title.style?.writebackRuleSnippet || '');
          if (!originalRule.includes('.hero-title')) throw new Error(`Missing initial rule snippet: ${originalRule}`);

          const invalidSelector = editor.validateSelectedStylesheetRule(originalRule.replace('.hero-title', '.wrong-title'));
          if (invalidSelector?.ok !== false) throw new Error(`Expected selector validation failure, got ${JSON.stringify(invalidSelector)}`);

          const invalidAtRule = editor.validateSelectedStylesheetRule('@media (max-width: 600px) { .hero-title { color: red; } }');
          if (invalidAtRule?.ok !== false) throw new Error(`Expected at-rule validation failure, got ${JSON.stringify(invalidAtRule)}`);

          const editedRule = originalRule
            .replace('color: rgb(15, 23, 42);', 'color: rgb(180, 42, 42);')
            .replace('font-size: 36px;', 'font-size: 44px;');
          const applyResult = editor.applySelectedStylesheetRule(editedRule);
          await sleep(120);
          if (applyResult?.ok !== true) throw new Error(`Rule apply failed: ${JSON.stringify(applyResult)}`);

          const matchSelection = editor.selectNodesForSelectedStylesheetRule();
          await sleep(40);
          if (matchSelection?.ok !== true || Number(matchSelection?.count || 0) !== 1 || String(matchSelection?.selector || '') !== '.hero-title') {
            throw new Error(`Rule match selection failed: ${JSON.stringify(matchSelection)}`);
          }

          const selected = editor.getSelection();
          const exported = editor.exportHTML();
          const colorWritten = /\\.hero-title\\s*\\{[^}]*color:\\s*rgb\\(180, 42, 42\\)/i.test(exported);
          const sizeWritten = /\\.hero-title\\s*\\{[^}]*font-size:\\s*44px/i.test(exported);
          const targetStable = selected?.style?.writebackTarget === '.hero-title';
          const snippetUpdated = String(selected?.style?.writebackRuleSnippet || '').includes('rgb(180, 42, 42)')
            && String(selected?.style?.writebackRuleSnippet || '').includes('44px');
          const lineAvailable = Number(selected?.style?.writebackRuleLine || 0) >= 1;
          const matchSummary = selected?.style?.writebackMatchSummary || null;
          const matchSummaryOk = matchSummary
            && String(matchSummary.selector || '') === '.hero-title'
            && Number(matchSummary.count || 0) === 1
            && Array.isArray(matchSummary.items)
            && matchSummary.items.length === 1
            && String(matchSummary.items[0]?.tagName || '').toLowerCase() === 'h1';
          const exportClean = !exported.includes('data-chiselo');

          if (!colorWritten || !sizeWritten || !targetStable || !snippetUpdated || !lineAvailable || !matchSummaryOk || !exportClean) {
            throw new Error(JSON.stringify({
              applyResult,
              matchSelection,
              selectedStyle: selected?.style,
              colorWritten,
              sizeWritten,
              targetStable,
              snippetUpdated,
              lineAvailable,
              matchSummary,
              matchSummaryOk,
              exportClean,
              exported
            }));
          }

          window.webkit.messageHandlers.ruleEditor.postMessage({
            type: 'result',
            selectedStyle: selected?.style,
            colorWritten,
            sizeWritten
          });
        })().catch(error => {
          window.webkit.messageHandlers.ruleEditor.postMessage({
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
        guard message.name == "ruleEditor", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown rule editor error.")
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            print(string)
        }
        exit(0)
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML rule editor test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Rule Editor Fixture</title>
      <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        main { width: 760px; min-height: 320px; padding: 48px; }
        .hero-title { color: rgb(15, 23, 42); background: rgb(255, 255, 255); font-size: 36px; font-weight: 700; }
      </style>
    </head>
    <body>
      <main>
        <h1 class="hero-title">Rule editor target</h1>
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

let test = DirectHTMLRuleEditorTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
