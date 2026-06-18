import AppKit
import Foundation
import WebKit

final class DirectHTMLExternalStylesheetReviewTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "externalStylesheetReview")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 840), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.fail("Timed out waiting for external stylesheet review result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let base64 = Data(Self.fixtureHTML.utf8).base64EncodedString()
        let script = """
        void (async () => {
          const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));
          const editor = window.ChiseloEditor;
          await editor.openHTMLFromBase64('\(base64)', 'https://example.com/pages/');
          await sleep(260);

          const before = editor.getImportDiagnostics();
          const beforeExternalIssue = (before.issues || []).some(item => item.kind === 'stylesheet-edit-review');
          if ((before.externalStylesheetCount || 0) < 1 || (before.externalStylesheetAffectedChangeCount || 0) !== 0 || beforeExternalIssue) {
            throw new Error(`External stylesheet should not create a source review before edits: ${JSON.stringify(before)}`);
          }

          const card = editor.selectHTML('.profile-card');
          if (!card) throw new Error('Could not select external stylesheet fixture card.');
          editor.updateElement({
            id: card.id,
            x: card.x,
            y: card.y,
            w: card.w,
            h: card.h,
            style: {
              fill: 'rgb(239, 246, 255)'
            }
          });
          await sleep(180);

          const after = editor.getImportDiagnostics();
          const externalIssue = (after.issues || []).find(item => item.kind === 'stylesheet-edit-review');
          if ((after.externalStylesheetAffectedChangeCount || 0) < 1 || !externalIssue || externalIssue.elementId !== card.id) {
            throw new Error(`Expected changed class object to require external stylesheet review: ${JSON.stringify(after)}`);
          }

          window.webkit.messageHandlers.externalStylesheetReview.postMessage({
            type: 'result',
            externalStylesheetCount: after.externalStylesheetCount,
            externalStylesheetAffectedChangeCount: after.externalStylesheetAffectedChangeCount,
            issueTitle: externalIssue.title,
            issueElementId: externalIssue.elementId
          });
        })().catch(error => {
          window.webkit.messageHandlers.externalStylesheetReview.postMessage({
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
        guard message.name == "externalStylesheetReview", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown external stylesheet review error.")
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            print(string)
        }
        exit(0)
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML external stylesheet review test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>External Stylesheet Review Fixture</title>
      <link rel="stylesheet" href="https://cdn.example.test/site.css">
      <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        main { width: 720px; min-height: 320px; padding: 48px; }
        .profile-card { width: 360px; padding: 24px; border-radius: 18px; background: rgb(255, 255, 255); color: rgb(15, 23, 42); box-shadow: 0 10px 30px rgba(15, 23, 42, .12); }
        .profile-card h1 { margin: 0 0 8px; font-size: 34px; }
      </style>
    </head>
    <body>
      <main>
        <section class="profile-card">
          <h1>External CSS Profile</h1>
          <p>Class-backed content should stay quiet until it changes.</p>
        </section>
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

let test = DirectHTMLExternalStylesheetReviewTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
