import AppKit
import Foundation
import WebKit

final class EditableTextCaptureTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let dashboardHTML: String
    private let dashboardBaseHref: String
    private var webView: WKWebView?
    private var didStart = false

    init(editorURL: URL, dashboardHTML: String, dashboardBaseHref: String) {
        self.editorURL = editorURL
        self.dashboardHTML = dashboardHTML
        self.dashboardBaseHref = dashboardBaseHref
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "editableTextCapture")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1440, height: 940), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.fail("Timed out waiting for editable text capture result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !didStart else { return }
        didStart = true

        let dashboardBase64 = Data(dashboardHTML.utf8).base64EncodedString()
        let nestedBase64 = Data(Self.nestedFixtureHTML.utf8).base64EncodedString()
        guard let baseData = try? JSONEncoder().encode(dashboardBaseHref),
              let baseLiteral = String(data: baseData, encoding: .utf8) else {
            fail("Could not encode dashboard base URL.")
        }

        let script = """
        void (async () => {
          const editor = window.ChiseloEditor;
          const assert = (condition, message, details = {}) => {
            if (!condition) throw new Error(JSON.stringify({ message, ...details }));
          };
          const textElements = (deck) => deck.slides.flatMap((slide) => slide.elements).filter((element) => element.type === 'text');
          const exactCount = (elements, text) => elements.filter((element) => element.text === text).length;

          const dashboard = await editor.importHTMLFromBase64('\(dashboardBase64)', \(baseLiteral));
          const dashboardText = textElements(dashboard);
          const metricPairs = [
            ['94%', '关键里程碑按期完成，较上周提升 6 个百分点。'],
            ['18', '待处理异常工单，其中 5 条需要产品负责人确认。'],
            ['2.7h', '平均响应时长，目标值为 4 小时以内。'],
            ['31', '本周完成交付物校验，覆盖 HTML / PDF / PPTX。']
          ];

          for (const [value, detail] of metricPairs) {
            assert(exactCount(dashboardText, value) === 1, 'Metric value was not captured exactly once.', { value, matches: dashboardText.filter((item) => item.text.includes(value)) });
            assert(exactCount(dashboardText, detail) === 1, 'Metric detail was not captured exactly once.', { detail, matches: dashboardText.filter((item) => item.text.includes(detail.slice(0, 8))) });
            assert(!dashboardText.some((item) => item.text.includes(value) && item.text.includes(detail)), 'Metric parent duplicated child text.', { value, detail });
          }

          const metricValue = dashboardText.find((element) => element.text === '94%');
          assert(metricValue?.tagName === 'b', 'Metric value did not preserve the leaf text element.', { metricValue });
          assert(Math.abs((metricValue?.style?.fontSize || 0) - 34) < 0.5, 'Metric value lost its computed font size.', { metricValue });

          const beforeSelection = JSON.stringify(editor.getDeck());
          assert(Boolean(metricValue && editor.selectElementById(metricValue.id)), 'Could not select converted metric value.', { metricValue });
          const afterSelection = JSON.stringify(editor.getDeck());
          assert(beforeSelection === afterSelection, 'Selecting one converted object mutated the deck.', {});

          const nested = await editor.importHTMLFromBase64('\(nestedBase64)', '');
          const nestedText = textElements(nested);
          const expectedFragments = ['Before', 'bold', 'after', 'Submit', '42', 'Answer'];
          for (const fragment of expectedFragments) {
            assert(exactCount(nestedText, fragment) === 1, 'Nested text fragment was not captured exactly once.', { fragment, nestedText });
          }
          assert(!nestedText.some((item) => item.text === 'Before bold after'), 'Inline parent and child text were captured twice.', { nestedText });
          assert(!nestedText.some((item) => item.text.includes('42') && item.text.includes('Answer')), 'Named container duplicated its child text.', { nestedText });
          assert(nestedText.some((item) => item.text === 'Before' && item.sourceKind === 'text-fragment'), 'Mixed inline text did not use fragment capture.', { nestedText });

          window.webkit.messageHandlers.editableTextCapture.postMessage({
            type: 'result',
            dashboardTextCount: dashboardText.length,
            nestedTextCount: nestedText.length,
            assertions: {
              metricTextUnique: true,
              metricStylePreserved: true,
              selectionPure: true,
              nestedTextUnique: true,
              mixedInlineFragmentsPreserved: true
            }
          });
        })().catch((error) => {
          window.webkit.messageHandlers.editableTextCapture.postMessage({
            type: 'error',
            message: String(error?.message || error),
            stack: String(error?.stack || '')
          });
        });
        """

        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error {
                self?.fail("Could not evaluate text capture test: \(error.localizedDescription)")
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "editableTextCapture", let body = message.body as? [String: Any] else { return }
        if body["type"] as? String == "error" {
            fail([body["message"] as? String, body["stack"] as? String].compactMap { $0 }.joined(separator: "\n"))
        }
        guard let assertions = body["assertions"] as? [String: Any],
              assertions.values.allSatisfy({ ($0 as? Bool) == true }) else {
            fail("Editable text capture assertions were not satisfied: \(body)")
        }
        print("Editable text capture test passed")
        exit(0)
    }

    private func fail(_ message: String) -> Never {
        fputs("Editable text capture test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let nestedFixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { margin: 0; padding: 32px; font: 18px/1.4 Arial, sans-serif; }
        .page { width: 720px; min-height: 420px; }
        .copy { width: 420px; }
        .copy strong { color: rgb(180, 20, 40); }
        .metric { margin-top: 24px; padding: 20px; border: 1px solid #ccd4dd; }
        .metric b { display: block; font-size: 32px; color: rgb(10, 110, 90); }
        .metric span { display: block; color: rgb(80, 90, 100); }
      </style>
    </head>
    <body>
      <main class="page">
        <p class="copy">Before <strong>bold</strong> after</p>
        <button><span>Submit</span></button>
        <article class="metric"><b>42</b><span>Answer</span></article>
      </main>
    </body>
    </html>
    """
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = root.appendingPathComponent("Chiselo/Resources/Editor/index.html")
let dashboardURL = root.appendingPathComponent("examples/test-html-pages/01-operations-dashboard.html")

guard let dashboardHTML = try? String(contentsOf: dashboardURL, encoding: .utf8) else {
    fputs("Could not read operations dashboard fixture.\n", stderr)
    exit(1)
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let test = EditableTextCaptureTest(
    editorURL: editorURL,
    dashboardHTML: dashboardHTML,
    dashboardBaseHref: dashboardURL.deletingLastPathComponent().absoluteString
)
DispatchQueue.main.async { test.start() }
app.run()
