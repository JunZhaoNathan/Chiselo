import AppKit
import Foundation
import WebKit

final class ImportAdapterTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "adapter")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1400, height: 900), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let html = """
        <style>
          .pseudo-source::before {
            content: "AUTO";
            display: inline-block;
            padding: 4px 8px;
            border-radius: 12px;
            background: #0a84ff;
            color: white;
            font-weight: 800;
          }
        </style>
        <section class=slide style="position:relative;width:960px;height:540px">
          <h1>Adapter smoke</h1>
          <p class=pseudo-source> pseudo text host</p>
          <div class=gradient-box style="position:absolute;left:220px;top:130px;width:160px;height:80px;border-radius:18px;background:linear-gradient(135deg, #ff0066 0%, rgba(10, 132, 255, 0.72) 100%)"></div>
          <img class=bad src="missing-chiselo-image.png" style="width:180px;height:90px">
          <svg class=mark width=80 height=40><rect width=80 height=40 fill="#6a50ad"/></svg>
          <table id=spanTable border=1 cellpadding=2>
            <tr><td class=merged colspan=2>merged</td><td>C</td></tr>
            <tr><td>A</td><td>B</td><td>C</td></tr>
          </table>
        </section>
        """

        guard let data = html.data(using: .utf8) else {
            fail("Could not encode fixture.")
        }

        let base64 = data.base64EncodedString()
        let script = """
        void (async () => {
          const editor = window.ChiseloEditor;
          await editor.openHTMLFromBase64('\(base64)', '');
          await new Promise(resolve => setTimeout(resolve, 350));
          const before = editor.getImportDiagnostics();
          editor.setBackdropStyle('grid');
          const gridBackdropApplied = document.documentElement.dataset.backdrop === 'grid';
          editor.setBackdropStyle('dots');
          const dotsBackdropApplied = document.documentElement.dataset.backdrop === 'dots';
          editor.setBackdropStyle('clean');
          const cleanBackdropApplied = document.documentElement.dataset.backdrop === 'clean';

          editor.selectHTML('#spanTable .merged');
          const selectedBefore = editor.getSelection();
          editor.command('tableAddColumnAfter');
          const afterAdd = editor.exportHTML();
          const afterAddDiagnostics = editor.getImportDiagnostics();

          editor.command('tableDeleteColumn');
          const afterDelete = editor.exportHTML();
          const frozenDeck = await editor.importHTMLFromBase64('\(base64)', '');
          const frozenJSON = JSON.stringify(frozenDeck);
          const frozenExport = editor.exportHTML();
          const firstFrozenElement = frozenDeck.slides?.[0]?.elements?.[0];
          const selectedFrozenElement = firstFrozenElement ? editor.selectElementById(firstFrozenElement.id) : null;

          const minimalHTML = '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>Minimal</title></head><body><main><h1>Minimal diagnostics fixture</h1><p>No images, media, SVG, or tables.</p></main></body></html>';
          await editor.openHTMLFromBase64(btoa(minimalHTML), '');
          const minimalDiagnostics = editor.getImportDiagnostics();

          const assertions = {
            fragmentWrapped: editor.exportHTML().includes('<html'),
            imageDetected: before.imageCount === 1,
            brokenImageDetected: before.brokenImages === 1,
            svgDetected: before.svgCount === 1,
            tableDetected: before.tableCount === 1,
            backdropSwitcherWorks: gridBackdropApplied && dotsBackdropApplied && cleanBackdropApplied,
            spanTableDetected: before.spanTableCount === 1,
            mergedColumnExpanded: afterAdd.includes('colspan="3"'),
            mergedColumnRestored: afterDelete.includes('colspan="2"'),
            diagnosticsRemainClean: afterAddDiagnostics.cleanExport === true,
            cleanExport: !afterDelete.includes('data-chiselo'),
            pseudoElementFrozen: frozenJSON.includes('AUTO'),
            gradientFillFrozen: frozenJSON.includes('linear-gradient'),
            imageElementFrozen: frozenJSON.includes('"type":"image"'),
            imageSourcePreserved: frozenJSON.includes('missing-chiselo-image.png'),
            imageExportPreserved: frozenExport.includes('<img') && frozenExport.includes('missing-chiselo-image.png'),
            deckLayerSelectionWorks: Boolean(firstFrozenElement && selectedFrozenElement && selectedFrozenElement.id === firstFrozenElement.id),
            minimalDiagnosticsNoResourceTarget: minimalDiagnostics.imageCount === 0 && minimalDiagnostics.mediaCount === 0 && minimalDiagnostics.resourceElementId === null,
            minimalDiagnosticsNoTableTarget: minimalDiagnostics.tableCount === 0 && minimalDiagnostics.tableElementId === null,
            minimalDiagnosticsNoSvgTarget: minimalDiagnostics.svgCount === 0 && minimalDiagnostics.svgElementId === null
          };

          const failed = Object.entries(assertions).filter(([, value]) => !value);
          if (failed.length) {
            throw new Error(JSON.stringify({ failed, assertions, before, selectedBefore, afterAdd, afterDelete }));
          }

          window.webkit.messageHandlers.adapter.postMessage({
            type: 'result',
            assertions,
            before,
            afterAddDiagnostics,
            minimalDiagnostics
          });
        })().catch(error => {
          window.webkit.messageHandlers.adapter.postMessage({ type: 'error', message: String(error && error.message || error) });
        });
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error {
                self.fail("Script failed: \(error.localizedDescription)")
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            fail("Invalid bridge message.")
        }

        if type == "error" {
            fail(body["message"] as? String ?? "Unknown adapter failure.")
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
            print(String(data: data, encoding: .utf8) ?? "{}")
            exit(0)
        } catch {
            fail("Could not encode result: \(error.localizedDescription)")
        }
    }

    private func fail(_ message: String) -> Never {
        fputs("\(message)\n", stderr)
        exit(1)
    }
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = projectRoot
    .appendingPathComponent("Chiselo")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Editor")
    .appendingPathComponent("index.html")

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let test = ImportAdapterTest(editorURL: editorURL)
test.start()

app.run()
