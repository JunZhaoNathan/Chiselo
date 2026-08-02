import AppKit
import Foundation
import WebKit

final class HTMLRuntimeSafetyTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?
    private var didStart = false

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "runtimeSafety")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 960, height: 720), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.fail("Timed out waiting for runtime safety result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !didStart else { return }
        didStart = true
        let base64 = Data(Self.fixtureHTML.utf8).base64EncodedString()
        let script = """
        void (async () => {
          const editor = window.ChiseloEditor;
          const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));

          await editor.openHTMLFromBase64('\(base64)');
          await wait(250);
          const safeFrame = document.querySelector('iframe.html-frame');
          const safeDocument = safeFrame?.contentDocument;
          const safeSandbox = safeFrame?.getAttribute('sandbox') || '';
          const safeScript = safeDocument?.querySelector('script');
          const safeBody = safeDocument?.body;
          const safeLink = safeDocument?.querySelector('#javascript-link');
          const safeRefresh = safeDocument?.querySelector('meta[content]');
          const safeNestedFrame = safeDocument?.querySelector('#nested-frame');
          const selected = editor.selectHTML('#source-content');
          editor.setSelectedHTMLText('Edited safely');
          await wait(80);
          const safeExport = editor.exportHTML();
          const safeAssertions = {
            runtimeMode: safeFrame?.dataset.runtimeMode === 'safe',
            editorScriptsEnabled: safeSandbox.split(/\\s+/).includes('allow-scripts'),
            formsBlocked: !safeSandbox.split(/\\s+/).includes('allow-forms'),
            sourcePreserved: Boolean(safeDocument?.querySelector('#source-content')),
            scriptMadeInert: safeScript?.type === 'application/x-chiselo-blocked',
            scriptDidNotRun: !safeDocument?.querySelector('#script-created'),
            inlineEventsMadeInert: !safeBody?.hasAttribute('onload') && !safeLink?.hasAttribute('onclick'),
            javascriptURLMadeInert: !safeLink?.hasAttribute('href'),
            refreshMadeInert: !safeRefresh?.hasAttribute('http-equiv'),
            nestedFrameSandboxed: safeNestedFrame?.hasAttribute('sandbox') && safeNestedFrame?.getAttribute('sandbox') === '',
            safeModeRemainsEditable: Boolean(selected && safeDocument?.querySelector('#source-content')?.textContent === 'Edited safely'),
            activeSourceRestoredOnExport: safeExport.includes('<script>')
              && safeExport.includes('onload=')
              && safeExport.includes('onclick=')
              && safeExport.includes('javascript:')
              && safeExport.includes('http-equiv="refresh"')
              && !safeExport.includes('data-chiselo-safe-')
          };

          await editor.openHTMLFromBase64('\(base64)', '', { runtimeMode: 'live' });
          await wait(250);
          const liveFrame = document.querySelector('iframe.html-frame');
          const liveSandbox = liveFrame?.getAttribute('sandbox') || '';
          const liveAssertions = {
            runtimeMode: liveFrame?.dataset.runtimeMode === 'live',
            pageScriptsEnabled: liveSandbox.split(/\\s+/).includes('allow-scripts'),
            formsEnabled: liveSandbox.split(/\\s+/).includes('allow-forms'),
            scriptRanAfterOptIn: Boolean(liveFrame?.contentDocument?.querySelector('#script-created'))
          };

          const assertions = { ...safeAssertions, ...liveAssertions };
          const failed = Object.entries(assertions).filter(([, passed]) => !passed);
          if (failed.length) throw new Error(JSON.stringify({ failed, safeSandbox, liveSandbox }));
          window.webkit.messageHandlers.runtimeSafety.postMessage({ type: 'result', assertions });
        })().catch(error => {
          window.webkit.messageHandlers.runtimeSafety.postMessage({
            type: 'error',
            message: String(error?.message || error)
          });
        });
        """
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error { self?.fail("Could not evaluate runtime safety script: \(error.localizedDescription)") }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "runtimeSafety", let body = message.body as? [String: Any] else { return }
        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown runtime safety error.")
        }
        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) {
            print(output)
        }
        exit(0)
    }

    private func fail(_ message: String) -> Never {
        fputs("HTML runtime safety test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta http-equiv="refresh" content="3600; url=https://example.com/refresh">
      <title>Runtime safety</title>
    </head>
    <body onload="window.bodyLoadRan = true">
      <main id="source-content">Source content</main>
      <a id="javascript-link" href="javascript:window.javascriptURLRan=true" onclick="window.inlineHandlerRan=true">Unsafe link</a>
      <iframe id="nested-frame" srcdoc="<script>parent.window.nestedScriptRan=true</script>"></iframe>
      <script>
        const created = document.createElement('p');
        created.id = 'script-created';
        created.textContent = 'Script executed';
        document.body.appendChild(created);
      </script>
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
let test = HTMLRuntimeSafetyTest(editorURL: editorURL)
DispatchQueue.main.async { test.start() }
app.run()
