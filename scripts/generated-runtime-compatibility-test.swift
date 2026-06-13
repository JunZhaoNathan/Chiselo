import AppKit
import Foundation
import WebKit

final class GeneratedRuntimeCompatibilityTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?
    private var didStart = false

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "runtime")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 840), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.fail("Timed out waiting for generated runtime compatibility result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.loadFixtureHTML()
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            fail("Invalid bridge message.")
        }

        if type == "error" {
            fail(body["message"] as? String ?? "Unknown runtime compatibility failure.")
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            print(string)
        }
        exit(0)
    }

    private func loadFixtureHTML() {
        guard !didStart else { return }
        didStart = true

        let base64 = Data(Self.fixtureHTML.utf8).base64EncodedString()
        let script = """
        void (async () => {
          const editor = window.ChiseloEditor;
          await editor.openHTMLFromBase64('\(base64)', '');
          await new Promise(resolve => setTimeout(resolve, 450));

          const diagnostics = editor.getImportDiagnostics();
          const issues = diagnostics.issues || [];
          const issueKinds = new Set(issues.map(issue => issue.kind));
          const exportHTML = editor.exportHTML();
          const selectedFallback = editor.selectHTMLById(diagnostics.pptxFallbackElementId || '');
          const selectedSecondFallback = editor.selectHTMLById(diagnostics.pptxFallbackElementIds?.[1] || diagnostics.pptxFallbackElementId || '');
          const selectedTitle = editor.selectHTML('#generated-title');
          const overlay = editor.selectHTML('.transparent-hit-layer');
          const overlayNode = document.querySelector('iframe.html-frame')?.contentDocument?.querySelector('.transparent-hit-layer');

          const assertions = {
            runtimeRiskDetected: diagnostics.runtimeRiskCount >= 4,
            scriptDetected: diagnostics.scriptCount >= 1,
            runtimeRootDetected: diagnostics.runtimeRootCount >= 1,
            iframeDetected: diagnostics.iframeCount === 1,
            canvasDetected: diagnostics.canvasCount === 1,
            overlayDetected: diagnostics.overlayBlockerCount >= 1,
            externalResourceDetected: diagnostics.externalResourceCount >= 1,
            pptxFallbackMappingDetected: diagnostics.pptxFallbackObjectCount >= 3 && typeof diagnostics.pptxFallbackElementId === 'string' && diagnostics.pptxFallbackElementId.length > 0,
            pptxFallbackTargetListDetected: Array.isArray(diagnostics.pptxFallbackElementIds) && diagnostics.pptxFallbackElementIds.length >= 3,
            pptxFallbackTargetSelectable: Boolean(selectedFallback && selectedFallback.id === diagnostics.pptxFallbackElementId),
            pptxSecondFallbackTargetSelectable: Boolean(selectedSecondFallback && diagnostics.pptxFallbackElementIds.includes(selectedSecondFallback.id)),
            issueKindsDetected: ['runtime-rendered', 'iframe-content', 'canvas-content', 'selection-overlay', 'external-runtime-resource'].every(kind => issueKinds.has(kind)),
            runtimeTargetClickable: typeof diagnostics.runtimeRiskElementId === 'string' && diagnostics.runtimeRiskElementId.length > 0,
            dynamicTitleSelectable: Boolean(selectedTitle && selectedTitle.text.includes('Runtime Generated Title')),
            overlayMarkedForEditing: Boolean(overlay && overlay.id && overlayNode?.dataset.chiseloSelectionPassThrough === 'true'),
            cleanExport: diagnostics.cleanExport === true && !exportHTML.includes('data-chiselo')
          };

          const failed = Object.entries(assertions).filter(([, value]) => !value);
          if (failed.length) {
            throw new Error(JSON.stringify({ failed, assertions, diagnostics, selectedTitle, overlay, exportHTML }));
          }

          window.webkit.messageHandlers.runtime.postMessage({
            type: 'result',
            assertions,
            diagnostics
          });
        })().catch(error => {
          window.webkit.messageHandlers.runtime.postMessage({ type: 'error', message: String(error && error.message || error) });
        });
        """

        webView?.evaluateJavaScript(script) { [weak self] _, error in
            if let error {
                self?.fail("Could not load runtime fixture: \(error.localizedDescription)")
            }
        }
    }

    private func fail(_ message: String) -> Never {
        fputs("Generated runtime compatibility test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Dify-like runtime fixture</title>
      <style>
        html, body { margin: 0; width: 100%; min-height: 100%; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        #app { position: relative; width: 960px; height: 540px; overflow: hidden; background: #f8fafc; }
        .transparent-hit-layer { position: fixed; inset: 0; opacity: 0; background: rgba(0,0,0,0); z-index: 9999; }
        .panel { position: absolute; left: 64px; top: 54px; width: 500px; padding: 28px; background: white; border: 1px solid #dbe3ef; }
        iframe { position: absolute; right: 44px; top: 48px; width: 260px; height: 160px; border: 0; }
        canvas { position: absolute; right: 64px; bottom: 54px; width: 220px; height: 120px; background: #0f172a; }
      </style>
    </head>
    <body>
      <div id="app"></div>
      <div class="transparent-hit-layer"></div>
      <script>
        setTimeout(() => {
          const app = document.getElementById('app');
          app.innerHTML = `
            <section class="panel">
              <h1 id="generated-title">Runtime Generated Title</h1>
              <p>Dify-style generated content should remain selectable after scripts run.</p>
            </section>
            <iframe src="https://example.com/embed"></iframe>
            <canvas width="220" height="120"></canvas>
          `;
        }, 80);
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

let test = GeneratedRuntimeCompatibilityTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
