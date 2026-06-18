import AppKit
import Foundation
import WebKit

final class DirectHTMLSourceSyncTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "sourceSync")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 840), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.fail("Timed out waiting for source sync result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let base64 = Data(Self.fixtureHTML.utf8).base64EncodedString()
        let script = """
        void (async () => {
          const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));
          const editor = window.ChiseloEditor;
          await editor.openHTMLFromBase64('\(base64)', '');
          await sleep(260);

          const selected = editor.selectHTML('#sourceTarget');
          if (!selected) throw new Error('Could not select source sync fixture.');
          const snippet = String(selected.sourceSnippet || '');
          const lineCount = Number(selected.sourceSnippetLineCount || 0);
          const sourceHasTag = snippet.includes('<article') && snippet.includes('id="sourceTarget"');
          const sourceHasChildren = snippet.includes('<h2>Synced title</h2>') && snippet.includes('<strong>real source</strong>');
          const sourceClean = !snippet.includes('data-chiselo') && !snippet.includes('__chiselo') && !snippet.includes('chiselo-edit');
          const sourceFormatted = snippet.includes('\\n  <h2>');
          const reselected = editor.selectHTMLById(selected.id);
          const reselectedSame = reselected && reselected.id === selected.id && String(reselected.sourceSnippet || '').includes('Synced title');

          if (!sourceHasTag || !sourceHasChildren || !sourceClean || !sourceFormatted || lineCount < 4 || !reselectedSame) {
            throw new Error(JSON.stringify({
              sourceHasTag,
              sourceHasChildren,
              sourceClean,
              sourceFormatted,
              lineCount,
              reselectedSame,
              selected,
              snippet
            }));
          }

          window.webkit.messageHandlers.sourceSync.postMessage({
            type: 'result',
            id: selected.id,
            lineCount,
            snippet
          });
        })().catch(error => {
          window.webkit.messageHandlers.sourceSync.postMessage({
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
        guard message.name == "sourceSync", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown source sync error.")
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            print(string)
        }
        exit(0)
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML source sync test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Source Sync Fixture</title>
      <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        main { width: 720px; padding: 48px; }
        .source-card { padding: 24px; border: 1px solid rgb(203, 213, 225); background: rgb(248, 250, 252); }
      </style>
    </head>
    <body>
      <main>
        <article id="sourceTarget" class="source-card" aria-label="Source card">
          <h2>Synced title</h2>
          <p>This is <strong>real source</strong> mapped to a visual object.</p>
        </article>
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

let test = DirectHTMLSourceSyncTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
