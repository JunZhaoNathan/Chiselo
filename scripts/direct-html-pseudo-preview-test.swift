import AppKit
import Foundation
import WebKit

final class DirectHTMLPseudoPreviewTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "pseudoPreview")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 920), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
            self?.fail("Timed out waiting for pseudo preview result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let html = """
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <title>Pseudo Preview Fixture</title>
          <style>
            body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: rgb(245, 247, 250); }
            .card { width: 360px; margin: 40px; padding: 24px; border-radius: 18px; background: rgb(240, 242, 247); }
            .card .copy { color: rgb(61, 72, 92); }
            .card:hover { background: rgb(255, 236, 179); }
            .card:hover .copy { color: rgb(180, 42, 42); }
            .field { display: block; width: 360px; margin: 16px 40px; padding: 14px 16px; border: 2px solid rgb(190, 198, 212); border-radius: 14px; background: rgb(255, 255, 255); }
            .field input { display: block; width: 100%; border: 0; outline: 0; background: transparent; color: rgb(23, 32, 51); }
            .field:focus-within { border-color: rgb(10, 132, 255); background: rgb(235, 244, 255); }
            .field input:focus { outline: 3px solid rgb(10, 132, 255); }
            .field input:focus-visible { color: rgb(92, 45, 180); }
          </style>
        </head>
        <body>
          <section id="card" class="card">
            <button id="cta">按钮</button>
            <p id="copy" class="copy">Hover copy</p>
          </section>
          <label id="field" class="field">
            <span>Field</span>
            <input id="name" value="focus target">
          </label>
        </body>
        </html>
        """

        guard let data = html.data(using: .utf8) else {
            fail("Could not encode pseudo preview fixture.")
        }

        let base64 = data.base64EncodedString()
        let script = """
        void window.ChiseloEditor.openHTMLFromBase64('\(base64)', '')
          .then(async () => {
            const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
            await sleep(220);
            const editor = window.ChiseloEditor;
            const iframe = document.querySelector('iframe.html-frame');
            const doc = iframe && iframe.contentDocument;
            const win = iframe && iframe.contentWindow;
            if (!editor || !doc || !win) throw new Error('Editor iframe is not ready.');

            const card = editor.selectHTML('#card');
            if (!card) throw new Error('Could not select #card');
            const cardNode = doc.querySelector('#card');
            const copyNode = doc.querySelector('#copy');
            const fieldSelection = editor.selectHTML('#field');
            if (!fieldSelection) throw new Error('Could not select #field');
            const fieldNode = doc.querySelector('#field');

            editor.selectHTML('#card');
            const hoverResult = editor.setPseudoPreviewState('hover');
            await sleep(40);
            const hoverBackground = win.getComputedStyle(cardNode).backgroundColor;
            const hoverCopyColor = win.getComputedStyle(copyNode).color;

            editor.selectHTML('#field');
            const focusResult = editor.setPseudoPreviewState('focus');
            await sleep(40);
            const focusBorder = win.getComputedStyle(fieldNode).borderTopColor;
            const focusBackground = win.getComputedStyle(fieldNode).backgroundColor;

            const clearResult = editor.setPseudoPreviewState('none');
            await sleep(40);
            const clearedBackground = win.getComputedStyle(cardNode).backgroundColor;
            const exported = editor.exportHTML();

            const pass = hoverResult?.ok === true
              && focusResult?.ok === true
              && clearResult?.ok === true
              && hoverBackground === 'rgb(255, 236, 179)'
              && hoverCopyColor === 'rgb(180, 42, 42)'
              && focusBorder === 'rgb(10, 132, 255)'
              && focusBackground === 'rgb(235, 244, 255)'
              && clearedBackground === 'rgb(240, 242, 247)'
              && !exported.includes('data-chiselo-force-hover')
              && !exported.includes('data-chiselo-force-focus')
              && !exported.includes('data-chiselo-pseudo-preview');

            if (!pass) {
              throw new Error(JSON.stringify({
                hoverResult,
                focusResult,
                clearResult,
                hoverBackground,
                hoverCopyColor,
                focusBorder,
                focusBackground,
                clearedBackground,
                exported
              }));
            }

            window.webkit.messageHandlers.pseudoPreview.postMessage({
              type: 'result',
              hoverBackground,
              hoverCopyColor,
              focusBorder,
              focusBackground,
              clearedBackground
            });
          })
          .catch(error => {
            window.webkit.messageHandlers.pseudoPreview.postMessage({
              type: 'error',
              message: error.message || String(error)
            });
          });
        """

        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "pseudoPreview",
              let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown pseudo preview error.")
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) {
            print(output)
            exit(0)
        }

        fail("Could not serialize pseudo preview result.")
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML pseudo preview test failed: \(message)\n", stderr)
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

let test = DirectHTMLPseudoPreviewTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
