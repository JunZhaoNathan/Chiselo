import AppKit
import Foundation
import WebKit

final class DirectHTMLAttributesInsertTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?
    private var receivedDiagnosticsMessage = false

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "chiselo")
        controller.add(self, name: "htmlAttributesInsert")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 900), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.fail("Timed out waiting for HTML attributes and insert result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let base64 = Data(Self.fixtureHTML.utf8).base64EncodedString()
        let script = """
        void (async () => {
          const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));
          const editor = window.ChiseloEditor;
          await editor.openHTMLFromBase64('\(base64)', '');
          await sleep(1500);

          const initialDiagnostics = editor.getImportDiagnostics();
          const hero = editor.selectHTML('#hero', { reveal: false });
          const attrResult = editor.applySelectedHTMLAttributes({
            className: 'hero edited-hero',
            inlineStyle: 'color: rgb(196, 38, 45); padding: 12px; margin-top: 4px;',
            linkHref: '',
            linkTarget: ''
          });
          const editedHero = editor.getSelection();
          const unsafeCSS = editor.applySelectedHTMLAttributes({
            className: 'hero',
            inlineStyle: 'background: url(javascript:alert(1));',
            linkHref: '',
            linkTarget: ''
          });

          const linkSelection = editor.selectHTML('#go', { reveal: false });
          const linkResult = editor.applySelectedHTMLAttributes({
            className: 'primary-link',
            inlineStyle: 'color: #0a84ff; text-decoration: underline;',
            linkHref: 'docs/start.html',
            linkTarget: '_blank'
          });

          editor.selectHTML('#mount', { reveal: false });
          editor.command('insertDiv');
          const divSelection = editor.getSelection();
          editor.command('insertParagraph');
          const paragraphSelection = editor.getSelection();
          editor.command('insertImage');
          const imageSelection = editor.getSelection();
          editor.command('insertLink');
          const insertedLinkSelection = editor.getSelection();
          editor.command('insertTable');
          const tableSelection = editor.getSelection();

          const exported = editor.exportHTML();
          const doc = document.querySelector('iframe.html-frame')?.contentDocument;
          const assertions = {
            diagnosticsAvailable: initialDiagnostics
              && typeof initialDiagnostics.cleanExport === 'boolean'
              && Array.isArray(initialDiagnostics.issues),
            selectedHeroPayload: hero?.id === editedHero?.id && hero?.className === 'hero',
            attributesApplied: attrResult?.ok === true
              && editedHero?.className === 'hero edited-hero'
              && String(editedHero?.inlineStyle || '').includes('padding')
              && exported.includes('edited-hero'),
            unsafeCSSRejected: unsafeCSS?.ok === false,
            linkPayloadVisible: linkSelection?.linkHref === '#start',
            linkApplied: linkResult?.ok === true
              && linkResult?.element?.linkHref === 'docs/start.html'
              && linkResult?.element?.linkTarget === '_blank'
              && exported.includes('href="docs/start.html"')
              && exported.includes('target="_blank"'),
            divInserted: divSelection?.tagName === 'div' && exported.includes('新建模块'),
            paragraphInserted: paragraphSelection?.tagName === 'p' && exported.includes('新段落文字'),
            imageInserted: imageSelection?.tagName === 'img' && String(imageSelection?.imageSource || '').startsWith('data:image/svg+xml'),
            linkInserted: insertedLinkSelection?.tagName === 'a' && exported.includes('新链接'),
            tableInserted: tableSelection?.tagName === 'table' && exported.includes('<table'),
            insertedNodesPrepared: !!doc && [...doc.querySelectorAll('[data-chiselo-id]')].length >= 8,
            exportClean: !exported.includes('data-chiselo') && !exported.includes('__chiselo')
          };
          const failed = Object.entries(assertions).filter((entry) => entry[1] !== true).map((entry) => entry[0]);
          if (failed.length) {
            throw new Error(JSON.stringify({
              failed,
              assertions,
              initialDiagnostics,
              hero,
              attrResult,
              editedHero,
              unsafeCSS,
              linkSelection,
              linkResult,
              divSelection,
              paragraphSelection,
              imageSelection,
              insertedLinkSelection,
              tableSelection,
              exported
            }));
          }

          window.webkit.messageHandlers.htmlAttributesInsert.postMessage({
            type: 'result',
            assertions,
            diagnostics: initialDiagnostics
          });
        })().catch(error => {
          window.webkit.messageHandlers.htmlAttributesInsert.postMessage({
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
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "chiselo" {
            if let body = message.body as? [String: Any],
               body["type"] as? String == "htmlDiagnosticsChanged" {
                receivedDiagnosticsMessage = true
            }
            return
        }

        guard message.name == "htmlAttributesInsert", let body = message.body as? [String: Any] else { return }
        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown JavaScript error.")
            return
        }

        guard receivedDiagnosticsMessage else {
            fail("Expected htmlDiagnosticsChanged bridge message after opening HTML.")
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) {
            print(output)
            exit(0)
        }

        fail("Could not serialize HTML attributes and insert result.")
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML attributes and insert test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>HTML Attributes Insert Fixture</title>
      <style>
        body { margin: 0; padding: 32px; font-family: -apple-system, BlinkMacSystemFont, sans-serif; color: #111827; }
        main { max-width: 720px; margin: 0 auto; }
        .hero { padding: 20px; border: 1px solid #d9e1e8; border-radius: 12px; background: #f8fafc; }
        #mount { margin-top: 24px; min-height: 80px; border: 1px dashed #cbd5e1; padding: 12px; }
      </style>
    </head>
    <body>
      <main>
        <section id="hero" class="hero">
          <h1>Fixture</h1>
          <p><a id="go" href="#start">Start link</a></p>
        </section>
        <div id="mount">Mount point</div>
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

let test = DirectHTMLAttributesInsertTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
