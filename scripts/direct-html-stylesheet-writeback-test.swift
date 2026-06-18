import AppKit
import Foundation
import WebKit

final class DirectHTMLStylesheetWritebackTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "stylesheetWriteback")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 840), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.fail("Timed out waiting for stylesheet writeback result.")
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
          if (!title) throw new Error('Could not select unique class title.');
          const titleWritebackOk = title.style?.writebackKind === 'stylesheet-rule' && title.style?.writebackTarget === '.hero-title' && String(title.style?.writebackDetail || '').includes('CSS');
          editor.updateElement({
            id: title.id,
            x: title.x,
            y: title.y,
            w: title.w,
            h: title.h,
            style: {
              color: 'rgb(12, 34, 56)',
              fill: 'rgb(240, 249, 255)',
              fontSize: 42,
              fontWeight: 800
            }
          });
          await sleep(180);

          const cta = editor.selectHTML('button.cta-button');
          if (!cta) throw new Error('Could not select tag.class CTA.');
          editor.updateElement({
            id: cta.id,
            x: cta.x,
            y: cta.y,
            w: cta.w,
            h: cta.h,
            style: {
              color: 'rgb(255, 255, 255)',
              fill: 'rgb(37, 99, 235)',
              radius: 16
            }
          });
          await sleep(180);

          const scoped = editor.selectHTML('.hero .scoped-copy');
          if (!scoped) throw new Error('Could not select scoped descendant copy.');
          editor.updateElement({
            id: scoped.id,
            x: scoped.x,
            y: scoped.y,
            w: scoped.w,
            h: scoped.h,
            style: {
              color: 'rgb(79, 70, 229)',
              textAlign: 'center'
            }
          });
          await sleep(180);

          const idTarget = editor.selectHTML('#idOnly');
          if (!idTarget) throw new Error('Could not select id-only target.');
          editor.updateElement({
            id: idTarget.id,
            x: idTarget.x,
            y: idTarget.y,
            w: idTarget.w,
            h: idTarget.h,
            style: {
              fill: 'rgb(236, 253, 245)'
            }
          });
          await sleep(180);

          const shared = editor.selectHTML('.shared-card');
          if (!shared) throw new Error('Could not select shared class card.');
          const sharedWritebackOk = shared.style?.writebackKind === 'inline-style' && shared.style?.writebackTarget === 'style' && String(shared.style?.writebackDetail || '').includes('误改同类对象');
          editor.updateElement({
            id: shared.id,
            x: shared.x,
            y: shared.y,
            w: shared.w,
            h: shared.h,
            style: {
              fill: 'rgb(254, 242, 242)'
            }
          });
          await sleep(180);

          const exported = editor.exportHTML();
          const diagnostics = editor.getImportDiagnostics();
          const titleHasInlineStyle = /<h1[^>]*class="hero-title"[^>]*style=/i.test(exported);
          const ruleColorWritten = /\\.hero-title\\s*\\{[^}]*color:\\s*rgb\\(12, 34, 56\\)/i.test(exported);
          const ruleFillWritten = /\\.hero-title\\s*\\{[^}]*background:\\s*rgb\\(240, 249, 255\\)/i.test(exported);
          const ruleFontWritten = /\\.hero-title\\s*\\{[^}]*font-size:\\s*42px/i.test(exported) && /\\.hero-title\\s*\\{[^}]*font-weight:\\s*800/i.test(exported);
          const tagClassWritten = /button\\.cta-button\\s*\\{[^}]*background:\\s*rgb\\(37, 99, 235\\)/i.test(exported) && /button\\.cta-button\\s*\\{[^}]*border-radius:\\s*16px/i.test(exported);
          const descendantWritten = /\\.hero \\.scoped-copy\\s*\\{[^}]*color:\\s*rgb\\(79, 70, 229\\)/i.test(exported) && /\\.hero \\.scoped-copy\\s*\\{[^}]*text-align:\\s*center/i.test(exported);
          const idRuleWritten = /#idOnly\\s*\\{[^}]*background:\\s*rgb\\(236, 253, 245\\)/i.test(exported);
          const complexTargetsHaveNoInline = !/<button[^>]*class="cta-button"[^>]*style=/i.test(exported) && !/<p[^>]*class="scoped-copy"[^>]*style=/i.test(exported) && !/<aside[^>]*id="idOnly"[^>]*style=/i.test(exported);
          const sharedInlineFallback = /<article[^>]*class="shared-card"[^>]*style="[^"]*background:\\s*rgb\\(254, 242, 242\\)/i.test(exported);

          const writebackSelectors = diagnostics.stylesheetRuleWritebackSelectors || [];
          const selectorTargetsDetected = ['.hero-title', 'button.cta-button', '.hero .scoped-copy', '#idOnly'].every(selector => writebackSelectors.includes(selector));

          if (!titleWritebackOk || !sharedWritebackOk || titleHasInlineStyle || !ruleColorWritten || !ruleFillWritten || !ruleFontWritten || !tagClassWritten || !descendantWritten || !idRuleWritten || !complexTargetsHaveNoInline || !sharedInlineFallback || (diagnostics.stylesheetRuleWritebackCount || 0) < 4 || !selectorTargetsDetected || (diagnostics.inlineStyleChangeCount || 0) < 1) {
            throw new Error(JSON.stringify({
              titleWriteback: title.style,
              titleWritebackOk,
              sharedWriteback: shared.style,
              sharedWritebackOk,
              titleHasInlineStyle,
              ruleColorWritten,
              ruleFillWritten,
              ruleFontWritten,
              tagClassWritten,
              descendantWritten,
              idRuleWritten,
              complexTargetsHaveNoInline,
              sharedInlineFallback,
              stylesheetRuleWritebackCount: diagnostics.stylesheetRuleWritebackCount,
              stylesheetRuleWritebackSelectors: diagnostics.stylesheetRuleWritebackSelectors,
              selectorTargetsDetected,
              inlineStyleChangeCount: diagnostics.inlineStyleChangeCount,
              exportedSnippet: exported.slice(0, 780)
            }));
          }

          window.webkit.messageHandlers.stylesheetWriteback.postMessage({
            type: 'result',
            titleWriteback: title.style,
            sharedWriteback: shared.style,
            stylesheetRuleWritebackCount: diagnostics.stylesheetRuleWritebackCount,
            stylesheetRuleWritebackSelectors: diagnostics.stylesheetRuleWritebackSelectors,
            inlineStyleChangeCount: diagnostics.inlineStyleChangeCount,
            cleanExport: diagnostics.cleanExport,
            sourceCleanlinessScore: diagnostics.sourceCleanlinessScore
          });
        })().catch(error => {
          window.webkit.messageHandlers.stylesheetWriteback.postMessage({
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
        guard message.name == "stylesheetWriteback", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown stylesheet writeback error.")
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            print(string)
        }
        exit(0)
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML stylesheet writeback test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Stylesheet Writeback Fixture</title>
      <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        main { width: 760px; min-height: 420px; padding: 48px; }
        .hero-title { color: rgb(15, 23, 42); background: rgb(255, 255, 255); font-size: 36px; font-weight: 700; }
        button.cta-button { color: rgb(15, 23, 42); background: rgb(226, 232, 240); border-radius: 8px; }
        .hero .scoped-copy { color: rgb(71, 85, 105); text-align: left; }
        #idOnly { background: rgb(255, 255, 255); padding: 14px; }
        .shared-card { background: rgb(248, 250, 252); padding: 18px; border: 1px solid rgb(203, 213, 225); }
      </style>
    </head>
    <body>
      <main>
        <section class="hero">
          <h1 class="hero-title">Precise HTML editing</h1>
          <p class="scoped-copy">Scoped copy target</p>
          <button class="cta-button">Call to action</button>
        </section>
        <aside id="idOnly">ID selector target</aside>
        <article class="shared-card">First shared card</article>
        <article class="shared-card">Second shared card</article>
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

let test = DirectHTMLStylesheetWritebackTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
