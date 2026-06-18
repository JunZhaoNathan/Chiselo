import AppKit
import Foundation
import WebKit

final class HistoryStateTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let htmlURL: URL
    private var webView: WKWebView?

    init(editorURL: URL, htmlURL: URL) {
        self.editorURL = editorURL
        self.htmlURL = htmlURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "historyState")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 900), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 18) { [weak self] in
            self?.fail("Timed out waiting for history state result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        do {
            let html = try String(contentsOf: htmlURL, encoding: .utf8)
            let base64 = Data(html.utf8).base64EncodedString()
            let baseLiteral = try jsStringLiteral(htmlURL.deletingLastPathComponent().absoluteString)
            let script = """
            void window.ChiseloEditor.openHTMLFromBase64('\(base64)', \(baseLiteral))
              .then(async () => {
                const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
                const editor = window.ChiseloEditor;
                const states = [];
                const capture = (label) => {
                  const state = editor.getHistoryState();
                  states.push({ label, ...state });
                  return state;
                };
                const expectState = (label, expected) => {
                  const state = capture(label);
                  for (const [key, value] of Object.entries(expected)) {
                    if (state[key] !== value) {
                      throw new Error(`${label}: expected ${key}=${value}, got ${state[key]} in ${JSON.stringify(state)}`);
                    }
                  }
                  return state;
                };

                expectState('opened', { canUndo: false, canRedo: false, undoDepth: 0, redoDepth: 0 });
                const selected = editor.selectHTML('h1');
                if (!selected) throw new Error('Could not select h1.');
                const originalText = selected.text;
                editor.setSelectedHTMLText('CHISELO_HISTORY_TEST');
                await sleep(120);
                expectState('afterTextEdit', { canUndo: true, canRedo: false, undoDepth: 1, redoDepth: 0 });
                if (!editor.exportHTML().includes('CHISELO_HISTORY_TEST')) {
                  throw new Error('Edited text was not present before undo.');
                }

                editor.command('undo');
                await sleep(180);
                expectState('afterUndo', { canUndo: false, canRedo: true, undoDepth: 0, redoDepth: 1 });
                const afterUndo = editor.selectHTML('h1');
                if (!afterUndo || afterUndo.text !== originalText) {
                  throw new Error(`Undo did not restore original text: ${afterUndo && afterUndo.text}`);
                }

                editor.command('redo');
                await sleep(180);
                expectState('afterRedo', { canUndo: true, canRedo: false, undoDepth: 1, redoDepth: 0 });
                const afterRedo = editor.selectHTML('h1');
                if (!afterRedo || afterRedo.text !== 'CHISELO_HISTORY_TEST') {
                  throw new Error(`Redo did not restore edited text: ${afterRedo && afterRedo.text}`);
                }

                window.webkit.messageHandlers.historyState.postMessage({
                  type: 'result',
                  originalText,
                  finalText: afterRedo.text,
                  states
                });
              })
              .catch(error => {
                window.webkit.messageHandlers.historyState.postMessage({
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
        } catch {
            fail("Could not read HTML: \(error.localizedDescription)")
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "historyState", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown JavaScript error.")
            return
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) {
            print(output)
            exit(0)
        }

        fail("Could not serialize history state result.")
    }

    private func jsStringLiteral(_ string: String) throws -> String {
        let data = try JSONEncoder().encode(string)
        return String(data: data, encoding: .utf8) ?? "\"\""
    }

    private func fail(_ message: String) -> Never {
        fputs("History state test failed: \(message)\n", stderr)
        exit(1)
    }
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = projectRoot
    .appendingPathComponent("Chiselo")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Editor")
    .appendingPathComponent("index.html")

let htmlPath = CommandLine.arguments.dropFirst().first
    ?? projectRoot.appendingPathComponent("examples").appendingPathComponent("sample-html-page.html").path
let htmlURL = URL(fileURLWithPath: htmlPath)

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let test = HistoryStateTest(editorURL: editorURL, htmlURL: htmlURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
