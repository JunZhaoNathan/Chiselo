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
          const reviewWidths = diagnostics.responsiveReviewWidths || [];
          const issue = (diagnostics.issues || []).find(item => item.kind === 'responsive-review');
          const item = items[0] || {};
          const matchedTarget = targetIds.includes(target.id) && diagnostics.responsiveChangeElementId === target.id;
          const hasBreakpointWidths = [619, 620, 621].every(width => reviewWidths.includes(width));
          const hasStructuredReason = String(item.responsiveReason || '').includes('布局') && String(item.responsiveLayoutKind || '').includes('布局') && Array.isArray(item.responsiveReviewWidths) && item.responsiveReviewWidths.includes(620);
          const hasReason = String(item.detail || '').includes('断点附近宽度') && String(item.afterValue || '').includes('布局') && hasStructuredReason && hasBreakpointWidths;

          const appMain = editor.selectHTML('.mock-main');
          if (!appMain) throw new Error('Could not select mock app main pane.');
          const appDoc = document.querySelector('iframe.html-frame')?.contentDocument;
          const appMainNode = appDoc?.querySelector('.mock-main');
          const appAsideNode = appDoc?.querySelector('.mock-ai');
          const beforeMainRect = appMainNode?.getBoundingClientRect?.();
          const beforeAsideRect = appAsideNode?.getBoundingClientRect?.();
          editor.command('setLayoutTransform');
          editor.updateElement({
            id: appMain.id,
            x: appMain.x,
            y: appMain.y,
            w: appMain.w + 120,
            h: appMain.h + 40
          });
          await sleep(180);
          const afterMainRect = appMainNode?.getBoundingClientRect?.();
          const afterAsideRect = appAsideNode?.getBoundingClientRect?.();
          const mainStyleAttr = appMainNode?.getAttribute('style') || '';
          const appSidebarStayedRight = beforeMainRect && beforeAsideRect && afterMainRect && afterAsideRect
            && afterAsideRect.top < afterMainRect.bottom - 24
            && afterAsideRect.left >= afterMainRect.right - 2;
          const flowSizePreserved = appMainNode
            && !/width\\s*:/.test(mainStyleAttr)
            && !/height\\s*:/.test(mainStyleAttr)
            && Math.abs(afterMainRect.width - beforeMainRect.width) < 2
            && Math.abs(afterMainRect.height - beforeMainRect.height) < 2;

          if ((diagnostics.responsiveRuleCount || 0) < 1 || (diagnostics.responsiveLayoutRiskCount || 0) < 1 || (diagnostics.responsiveChangeCount || 0) < 1 || !matchedTarget || items.length < 1 || !hasReason || !issue || issue.elementId !== target.id || !appSidebarStayedRight || !flowSizePreserved) {
            throw new Error(JSON.stringify({
              responsiveRuleCount: diagnostics.responsiveRuleCount,
              responsiveLayoutRiskCount: diagnostics.responsiveLayoutRiskCount,
              responsiveReviewWidths: reviewWidths,
              responsiveChangeCount: diagnostics.responsiveChangeCount,
              responsiveChangeElementId: diagnostics.responsiveChangeElementId,
              targetId: target.id,
              targetIds,
              items,
              issue,
              appSidebarStayedRight,
              flowSizePreserved,
              beforeMainRect: beforeMainRect ? { x: beforeMainRect.x, y: beforeMainRect.y, width: beforeMainRect.width, height: beforeMainRect.height } : null,
              afterMainRect: afterMainRect ? { x: afterMainRect.x, y: afterMainRect.y, width: afterMainRect.width, height: afterMainRect.height } : null,
              beforeAsideRect: beforeAsideRect ? { x: beforeAsideRect.x, y: beforeAsideRect.y, width: beforeAsideRect.width, height: beforeAsideRect.height } : null,
              afterAsideRect: afterAsideRect ? { x: afterAsideRect.x, y: afterAsideRect.y, width: afterAsideRect.width, height: afterAsideRect.height } : null,
              mainStyleAttr
            }));
          }

          window.webkit.messageHandlers.responsiveChangeReview.postMessage({
            type: 'result',
            responsiveRuleCount: diagnostics.responsiveRuleCount,
            responsiveLayoutRiskCount: diagnostics.responsiveLayoutRiskCount,
            responsiveReviewWidths: reviewWidths,
            responsiveChangeCount: diagnostics.responsiveChangeCount,
            responsiveChangeElementIds: targetIds,
            issueElementId: issue.elementId,
            appSidebarStayedRight,
            flowSizePreserved,
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
        .mock-app { display: flex; flex-wrap: wrap; gap: 16px; width: 1040px; margin-top: 42px; padding: 16px; background: rgb(15, 23, 42); color: rgb(226, 232, 240); box-sizing: border-box; }
        .mock-main { flex: 1 1 0; min-width: 0; min-height: 280px; padding: 18px; border: 1px solid rgb(51, 65, 85); box-sizing: border-box; }
        .mock-ai { flex: 0 0 330px; min-height: 280px; padding: 18px; border: 1px solid rgb(20, 184, 166); box-sizing: border-box; }
        @media (max-width: 620px) {
          main { width: 100%; padding: 24px; }
          .feature-grid { flex-direction: column; }
          .feature-card { min-width: 0; }
          .mock-app { width: 100%; }
          .mock-ai { flex-basis: 100%; }
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
        <section class="mock-app">
          <div class="mock-main">
            <h2>Main editor</h2>
            <p>Code, preview, log and editing controls stay in the main pane.</p>
          </div>
          <aside class="mock-ai">
            <h2>AI panel</h2>
            <p>This sidebar must stay on the right after object adjustment.</p>
          </aside>
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

let test = DirectHTMLResponsiveChangeReviewTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
