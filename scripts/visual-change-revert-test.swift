import AppKit
import Foundation
import WebKit

final class VisualChangeRevertTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?
    private var didStart = false

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "visualRevert")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 840), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 16) { [weak self] in
            self?.fail("Timed out waiting for visual change revert result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.runFixture()
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "visualRevert", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown visual revert failure.")
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            print(string)
        }
        exit(0)
    }

    private func runFixture() {
        guard !didStart else { return }
        didStart = true

        let base64 = Data(Self.fixtureHTML.utf8).base64EncodedString()
        let script = """
        void (async () => {
          const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));
          const editor = window.ChiseloEditor;
          await editor.openHTMLFromBase64('\(base64)', '');
          await sleep(520);

          editor.selectHTML('#title');
          editor.setSelectedHTMLText('Changed title');
          await sleep(180);
          let diagnostics = editor.getImportDiagnostics();
          const textItem = (diagnostics.visualChangeItems || []).find(item => item.kind === '文字' && item.canRevert === true);
          if (!textItem || !textItem.changeKey || textItem.canRevert !== true) {
            throw new Error(`Expected revertable text visual change, got ${JSON.stringify(diagnostics.visualChangeItems)}`);
          }
          if (!String(textItem.beforeValue || '').includes('Original title') || !String(textItem.afterValue || '').includes('Changed title')) {
            throw new Error(`Expected before/after text values, got ${JSON.stringify(textItem)}`);
          }
          if ((diagnostics.responsiveRuleCount || 0) < 1 || (diagnostics.responsiveLayoutRiskCount || 0) < 1) {
            throw new Error(`Expected responsive review diagnostics, got ${JSON.stringify(diagnostics)}`);
          }
          if ((diagnostics.inlineStyleChangeCount || 0) !== 0) {
            throw new Error(`Text-only edit should not count inline style changes, got ${diagnostics.inlineStyleChangeCount}`);
          }

          const revertResult = editor.revertVisualChange(textItem.changeKey);
          await sleep(220);
          if (!revertResult || revertResult.ok !== true) {
            throw new Error(`Expected successful revert, got ${JSON.stringify(revertResult)}`);
          }
          if (!editor.exportHTML().includes('Original title') || editor.exportHTML().includes('Changed title')) {
            throw new Error('Text visual change did not revert in exported HTML.');
          }

          editor.selectHTML('#card');
          editor.updateElement({ x: 92, y: 102, w: 240, h: 96, style: { fill: 'rgb(220, 252, 231)' } });
          await sleep(180);
          diagnostics = editor.getImportDiagnostics();
          const styleItem = (diagnostics.visualChangeItems || []).find(item => item.kind === '样式' || item.kind === '位置/尺寸');
          if (!styleItem || !styleItem.changeKey || styleItem.canRevert !== true) {
            throw new Error(`Expected revertable style or geometry change, got ${JSON.stringify(diagnostics.visualChangeItems)}`);
          }
          if (styleItem.writebackKind !== 'inline-style' || styleItem.writebackLabel !== 'inline style' || styleItem.writebackTarget !== 'style') {
            throw new Error(`Expected inline-style writeback metadata, got ${JSON.stringify(styleItem)}`);
          }
          if ((diagnostics.inlineStyleChangeCount || 0) < 1) {
            throw new Error(`Expected inline style change count after visual update, got ${diagnostics.inlineStyleChangeCount}`);
          }

          const styleRevertResult = editor.revertVisualChange(styleItem.changeKey);
          await sleep(220);
          if (!styleRevertResult || styleRevertResult.ok !== true) {
            throw new Error(`Expected successful style revert, got ${JSON.stringify(styleRevertResult)}`);
          }
          const exportHTML = editor.exportHTML();
          if (exportHTML.includes('rgb(220, 252, 231)')) {
            throw new Error('Style visual change did not revert in exported HTML.');
          }

          const ruleTarget = editor.selectHTML('.rule-card');
          if (!ruleTarget) throw new Error('Could not select stylesheet-backed rule card.');
          editor.updateElement({
            id: ruleTarget.id,
            x: ruleTarget.x,
            y: ruleTarget.y,
            w: ruleTarget.w,
            h: ruleTarget.h,
            style: {
              fill: 'rgb(254, 226, 226)',
              color: 'rgb(127, 29, 29)',
              radius: 24
            }
          });
          await sleep(220);
          diagnostics = editor.getImportDiagnostics();
          const ruleItem = (diagnostics.visualChangeItems || []).find(item => item.kind === '样式' && item.elementId === ruleTarget.id);
          if (!ruleItem || !ruleItem.changeKey || ruleItem.canRevert !== true || !String(ruleItem.detail || '').includes('样式表规则')) {
            throw new Error(`Expected revertable stylesheet-rule visual change, got ${JSON.stringify(diagnostics.visualChangeItems)}`);
          }
          if (ruleItem.writebackKind !== 'stylesheet-rule' || ruleItem.writebackLabel !== 'CSS 规则' || ruleItem.writebackTarget !== '.rule-card') {
            throw new Error(`Expected stylesheet-rule writeback metadata, got ${JSON.stringify(ruleItem)}`);
          }
          if ((diagnostics.stylesheetRuleWritebackCount || 0) < 1) {
            throw new Error(`Expected stylesheet rule writeback count after rule edit, got ${diagnostics.stylesheetRuleWritebackCount}`);
          }
          let ruleExport = editor.exportHTML();
          if (/<article[^>]*class="rule-card"[^>]*style=/i.test(ruleExport)) {
            throw new Error('Stylesheet-backed visual change should not add inline style.');
          }
          if (!/\\.rule-card\\s*\\{[^}]*background:\\s*rgb\\(254, 226, 226\\)/i.test(ruleExport)) {
            throw new Error('Stylesheet-backed visual change was not written into the CSS rule.');
          }

          const ruleRevertResult = editor.revertVisualChange(ruleItem.changeKey);
          await sleep(220);
          if (!ruleRevertResult || ruleRevertResult.ok !== true) {
            throw new Error(`Expected successful stylesheet-rule revert, got ${JSON.stringify(ruleRevertResult)}`);
          }
          ruleExport = editor.exportHTML();
          if (/rgb\\(254, 226, 226\\)/i.test(ruleExport) || /rgb\\(127, 29, 29\\)/i.test(ruleExport) || /border-radius:\\s*24px/i.test(ruleExport)) {
            throw new Error('Stylesheet-rule visual change did not revert in exported CSS.');
          }
          if (!/\\.rule-card\\s*\\{[^}]*background:\\s*rgb\\(240, 253, 244\\)/i.test(ruleExport) || !/\\.rule-card\\s*\\{[^}]*color:\\s*rgb\\(20, 83, 45\\)/i.test(ruleExport) || !/\\.rule-card\\s*\\{[^}]*border-radius:\\s*12px/i.test(ruleExport)) {
            throw new Error('Stylesheet-rule visual change did not restore original CSS rule values.');
          }

          window.webkit.messageHandlers.visualRevert.postMessage({
            type: 'result',
            textItem,
            styleItem,
            ruleItem,
            diagnostics: editor.getImportDiagnostics(),
            history: editor.getHistoryState()
          });
        })().catch(error => {
          window.webkit.messageHandlers.visualRevert.postMessage({
            type: 'error',
            message: String(error && error.message || error),
            stack: String(error && error.stack || '')
          });
        });
        """

        webView?.evaluateJavaScript(script) { [weak self] _, error in
            if let error {
                self?.fail("Could not run visual revert fixture: \(error.localizedDescription)")
            }
        }
    }

    private func fail(_ message: String) -> Never {
        fputs("Visual change revert test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        main { display: flex; gap: 24px; width: 960px; min-height: 540px; padding: 64px; box-sizing: border-box; background: #f8fafc; }
        #card { width: 220px; height: 92px; padding: 16px; background: #dbeafe; border-radius: 14px; box-sizing: border-box; }
        .rule-card { width: 180px; min-height: 92px; padding: 16px; background: rgb(240, 253, 244); color: rgb(20, 83, 45); border-radius: 12px; box-sizing: border-box; }
        @media (max-width: 700px) {
          main { width: 420px; flex-direction: column; }
          #card { width: 100%; }
          .rule-card { width: 100%; }
        }
      </style>
    </head>
    <body>
      <main>
        <h1 id="title">Original title</h1>
        <div id="card">Card copy</div>
        <article class="rule-card">Stylesheet rule card</article>
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

let test = VisualChangeRevertTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
