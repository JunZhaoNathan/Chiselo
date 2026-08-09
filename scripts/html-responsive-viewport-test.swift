import AppKit
import Foundation
import WebKit

final class HTMLResponsiveViewportTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?
    private var didStart = false

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "responsiveViewport")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 820), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
            self?.fail("Timed out waiting for responsive viewport result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !didStart else { return }
        didStart = true
        let html = Self.fixtureHTML
        let base64 = Data(html.utf8).base64EncodedString()
        guard let encodedHTML = try? JSONEncoder().encode(html),
              let htmlLiteral = String(data: encodedHTML, encoding: .utf8) else {
            fail("Could not encode the responsive fixture as a JavaScript string.")
        }
        let script = """
        void (async () => {
          const editor = window.ChiseloEditor;
          const wait = () => new Promise(resolve => setTimeout(resolve, 120));
          const inspect = () => {
            const frame = document.querySelector('iframe.html-frame');
            const target = frame?.contentDocument?.querySelector('#responsive-target');
            return {
              viewportWidth: frame?.contentWindow?.innerWidth || 0,
              color: target ? frame.contentWindow.getComputedStyle(target).color : '',
              history: editor.getHistoryState()
            };
          };

          await editor.openHTMLFromBase64('\(base64)', '', { originalSourceBase64: '\(base64)' });
          await wait();
          const openedViewport = editor.getViewportState();
          const openedFrame = document.querySelector('iframe.html-frame');
          const openedFrameRect = openedFrame?.getBoundingClientRect();
          const openedCSSPixelWidth = openedFrame?.contentWindow?.innerWidth || 0;
          editor.setHTMLPreviewWidth(1440);
          await wait();
          const desktop = inspect();
          editor.setHTMLPreviewWidth(768);
          await wait();
          const tablet = inspect();
          editor.setHTMLPreviewWidth(390);
          await wait();
          const mobile = inspect();
          const exportedAtMobile = editor.exportHTML();
          editor.selectHTML('#responsive-target');
          editor.setSelectedHTMLText('Changed temporarily');
          await wait();
          await editor.command('undo');
          await wait();
          const afterUndo = inspect();
          const original = editor.setHTMLPreviewWidth(null);
          await wait();

          const assertions = {
            opensAtActualSize: Math.abs(openedViewport.scale - 1) < 0.001
              && Math.abs(openedViewport.fitScale - 1) < 0.001
              && Math.abs(openedViewport.userZoom - 1) < 0.001,
            openedFrameUsesCSSPixels: Boolean(openedFrameRect && openedCSSPixelWidth > 0
              && Math.abs(openedFrameRect.width - openedCSSPixelWidth) < 3),
            desktopWidth: desktop.viewportWidth === 1440,
            desktopRule: desktop.color === 'rgb(200, 20, 30)',
            tabletWidth: tablet.viewportWidth === 768,
            tabletRule: tablet.color === 'rgb(20, 120, 40)',
            mobileWidth: mobile.viewportWidth === 390,
            mobileRule: mobile.color === 'rgb(20, 60, 200)',
            previewDoesNotCreateHistory: [desktop, tablet, mobile].every(item => item.history?.undoDepth === 0 && item.history?.redoDepth === 0),
            previewDoesNotRewriteHTML: exportedAtMobile === \(htmlLiteral),
            undoPreservesPreviewWidth: afterUndo.viewportWidth === 390,
            originalModeRestored: original?.mode === 'original' && original?.width === null
          };
          const failed = Object.entries(assertions).filter(([, passed]) => !passed);
          if (failed.length) throw new Error(JSON.stringify({ failed, assertions, desktop, tablet, mobile, original, exportedAtMobile }));
          window.webkit.messageHandlers.responsiveViewport.postMessage({ type: 'result', assertions, desktop, tablet, mobile });
        })().catch(error => {
          window.webkit.messageHandlers.responsiveViewport.postMessage({ type: 'error', message: String(error?.message || error) });
        });
        """
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error { self?.fail("Could not evaluate responsive test: \(error.localizedDescription)") }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "responsiveViewport", let body = message.body as? [String: Any] else { return }
        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown responsive viewport error.")
        }
        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) { print(output) }
        exit(0)
    }

    private func fail(_ message: String) -> Never {
        fputs("HTML responsive viewport test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html><head><meta charset="utf-8"><style>
      #responsive-target { color: rgb(200, 20, 30); }
      @media (max-width: 900px) { #responsive-target { color: rgb(20, 120, 40); } }
      @media (max-width: 500px) { #responsive-target { color: rgb(20, 60, 200); } }
    </style></head><body><main id="responsive-target">Responsive</main></body></html>
    """
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = root.appendingPathComponent("Chiselo/Resources/Editor/index.html")
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let test = HTMLResponsiveViewportTest(editorURL: editorURL)
DispatchQueue.main.async { test.start() }
app.run()
