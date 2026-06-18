import AppKit
import Foundation
import WebKit

final class DirectHTMLResponsiveChangeReviewTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "responsiveChangeReview")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 840), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.fail("Timed out waiting for responsive change review result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let base64 = Data(Self.fixtureHTML.utf8).base64EncodedString()
        let script = """
        void (async () => {
          const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));
          const editor = window.ChiseloEditor;
          await editor.openHTMLFromBase64('\(base64)', '');
          await sleep(320);

          const target = editor.selectHTML('.feature-card');
          if (!target) throw new Error('Could not select responsive feature card.');
          editor.updateElement({
            id: target.id,
            x: target.x,
            y: target.y,
            w: target.w,
            h: target.h,
            style: {
              fill: 'rgb(219, 234, 254)',
              color: 'rgb(30, 64, 175)'
            }
          });
          await sleep(260);

          const diagnostics = editor.getImportDiagnostics();
          const targetIds = diagnostics.responsiveChangeElementIds || [];
          const items = diagnostics.responsiveChangeItems || [];
          const issue = (diagnostics.issues || []).find(item => item.kind === 'responsive-review');
          const item = items[0] || {};
          const matchedTarget = targetIds.includes(target.id) && diagnostics.responsiveChangeElementId === target.id;
          const hasReason = String(item.detail || '').includes('不同宽度') && String(item.afterValue || '').includes('布局');

          if ((diagnostics.responsiveRuleCount || 0) < 1 || (diagnostics.responsiveLayoutRiskCount || 0) < 1 || (diagnostics.responsiveChangeCount || 0) < 1 || !matchedTarget || items.length < 1 || !hasReason || !issue || issue.elementId !== target.id) {
            throw new Error(JSON.stringify({
              responsiveRuleCount: diagnostics.responsiveRuleCount,
              responsiveLayoutRiskCount: diagnostics.responsiveLayoutRiskCount,
              responsiveChangeCount: diagnostics.responsiveChangeCount,
              responsiveChangeElementId: diagnostics.responsiveChangeElementId,
              targetId: target.id,
              targetIds,
              items,
              issue
            }));
          }

          window.webkit.messageHandlers.responsiveChangeReview.postMessage({
            type: 'result',
            responsiveRuleCount: diagnostics.responsiveRuleCount,
            responsiveLayoutRiskCount: diagnostics.responsiveLayoutRiskCount,
            responsiveChangeCount: diagnostics.responsiveChangeCount,
            responsiveChangeElementIds: targetIds,
            issueElementId: issue.elementId,
            cleanExport: diagnostics.cleanExport
          });
        })().catch(error => {
          window.webkit.messageHandlers.responsiveChangeReview.postMessage({
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
        guard message.name == "responsiveChangeReview", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown responsive change review error.")
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            print(string)
        }
        exit(0)
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML responsive change review test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Responsive Change Review Fixture</title>
      <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        main { width: 900px; min-height: 520px; padding: 48px; }
        .feature-grid { display: flex; gap: 20px; align-items: stretch; }
        .feature-card { flex: 1 1 0; min-width: 180px; padding: 22px; background: rgb(248, 250, 252); color: rgb(15, 23, 42); border: 1px solid rgb(203, 213, 225); }
        .plain-note { margin-top: 28px; width: 280px; padding: 18px; background: rgb(241, 245, 249); }
        @media (max-width: 620px) {
          main { width: 100%; padding: 24px; }
          .feature-grid { flex-direction: column; }
          .feature-card { min-width: 0; }
        }
      </style>
    </head>
    <body>
      <main>
        <section class="feature-grid">
          <article class="feature-card">Responsive card A</article>
          <article class="feature-card">Responsive card B</article>
        </section>
        <p class="plain-note">Plain note outside the edited target.</p>
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

let test = DirectHTMLResponsiveChangeReviewTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
