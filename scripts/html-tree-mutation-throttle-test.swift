import AppKit
import Foundation
import WebKit

final class HTMLTreeMutationThrottleTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let htmlURL: URL
    private var webView: WKWebView?
    private var didStartLoad = false
    private var treeMessageCount = 0
    private var styleBaseline = 0
    private var textBaseline = 0
    private var directTypingBaseline = 0

    init(editorURL: URL, htmlURL: URL) {
        self.editorURL = editorURL
        self.htmlURL = htmlURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "chiselo")
        controller.add(self, name: "treeMutationTest")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 900), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            self?.fail("Timed out waiting for mutation throttle result.")
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }

        if message.name == "chiselo" {
            handleEditorMessage(body)
            return
        }

        guard message.name == "treeMutationTest", let type = body["type"] as? String else { return }
        switch type {
        case "loaded":
            waitThenRunStyleMutation()
        case "styleApplied":
            waitThenCheckStyleMutation()
        case "textApplied":
            waitThenCheckTextMutation()
        case "directTyped":
            waitThenCheckDirectTyping()
        case "directBlurred":
            waitThenCheckDirectBlur()
        case "error":
            fail(body["message"] as? String ?? "Unknown JavaScript error.")
        default:
            break
        }
    }

    private func handleEditorMessage(_ body: [String: Any]) {
        let type = body["type"] as? String
        if type == "htmlTreeChanged" {
            treeMessageCount += 1
        }

        if type == "bridgeReady", !didStartLoad {
            didStartLoad = true
            loadSampleHTML()
        }
    }

    private func loadSampleHTML() {
        do {
            let html = try String(contentsOf: htmlURL, encoding: .utf8)
            let base64 = Data(html.utf8).base64EncodedString()
            let baseLiteral = try jsStringLiteral(htmlURL.deletingLastPathComponent().absoluteString)
            let script = """
            void window.ChiseloEditor.openHTMLFromBase64('\(base64)', \(baseLiteral))
              .then(() => window.webkit.messageHandlers.treeMutationTest.postMessage({ type: 'loaded' }))
              .catch(error => window.webkit.messageHandlers.treeMutationTest.postMessage({
                type: 'error',
                message: String(error && error.message || error)
              }));
            """
            webView?.evaluateJavaScript(script)
        } catch {
            fail("Could not read sample HTML: \(error.localizedDescription)")
        }
    }

    private func waitThenRunStyleMutation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self else { return }
            styleBaseline = treeMessageCount
            let script = """
            (() => {
              const selected = window.ChiseloEditor.selectHTML('h1');
              if (!selected) throw new Error('Could not select h1.');
              window.ChiseloEditor.updateElement({
                ...selected,
                x: selected.x + 3,
                y: selected.y + 2,
                style: {
                  ...selected.style,
                  fill: 'rgb(248, 250, 252)',
                  color: 'rgb(10, 11, 12)'
                }
              });
              window.webkit.messageHandlers.treeMutationTest.postMessage({ type: 'styleApplied' });
            })();
            """
            webView?.evaluateJavaScript(script) { _, error in
                if let error {
                    self.fail("Style mutation script failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func waitThenCheckStyleMutation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            guard let self else { return }
            let afterStyle = treeMessageCount
            guard afterStyle == styleBaseline else {
                fail("Style-only mutation refreshed HTML tree. baseline=\(styleBaseline), after=\(afterStyle)")
            }

            textBaseline = treeMessageCount
            let script = """
            (() => {
              const result = window.ChiseloEditor.setSelectedHTMLText('CHISELO_TREE_REFRESH_TEST');
              if (!result) throw new Error('Could not update selected text.');
              window.webkit.messageHandlers.treeMutationTest.postMessage({ type: 'textApplied' });
            })();
            """
            webView?.evaluateJavaScript(script) { _, error in
                if let error {
                    self.fail("Text mutation script failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func waitThenCheckTextMutation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            guard let self else { return }
            let afterText = treeMessageCount
            guard afterText > textBaseline else {
                fail("Text mutation did not refresh HTML tree. baseline=\(textBaseline), after=\(afterText)")
            }

            directTypingBaseline = treeMessageCount
            let script = """
            void (async () => {
              const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
              const frame = document.querySelector('.html-frame');
              if (!frame?.contentDocument) throw new Error('HTML iframe not found.');
              const doc = frame.contentDocument;
              const win = frame.contentWindow;
              const target = doc.querySelector('h1');
              if (!target) throw new Error('Direct edit h1 target not found.');

              const rect = target.getBoundingClientRect();
              const x = rect.left + Math.min(28, Math.max(6, rect.width / 4));
              const y = rect.top + Math.min(16, Math.max(6, rect.height / 2));
              const dispatchTarget = doc.elementFromPoint(x, y) || target;
              dispatchTarget.dispatchEvent(new win.MouseEvent('dblclick', {
                bubbles: true,
                cancelable: true,
                clientX: x,
                clientY: y,
                detail: 2
              }));
              await sleep(180);

              if (doc.activeElement !== target || target.getAttribute('contenteditable') !== 'true') {
                throw new Error(`Direct edit did not start. active=${doc.activeElement && doc.activeElement.tagName}, editable=${target.getAttribute('contenteditable')}`);
              }

              doc.execCommand('insertText', false, 'CHISELO_DIRECT_TYPING_REFRESH_TEST');
              await sleep(700);
              const box = document.querySelector('#selectionBox');
              const stage = document.querySelector('#stage');
              const rectOf = (node) => {
                const rect = node?.getBoundingClientRect?.();
                return rect ? { x: rect.x, y: rect.y, w: rect.width, h: rect.height } : null;
              };
              const stableSnapshot = {
                target: rectOf(target),
                box: rectOf(box),
                peer: rectOf(doc.querySelector('.band-subtitle')),
                stageTransform: stage?.style.transform || '',
                stageWidth: stage?.style.width || '',
                stageHeight: stage?.style.height || ''
              };
              window.webkit.messageHandlers.treeMutationTest.postMessage({ type: 'directTyped' });
              window.__chiseloTypingSnapshot = stableSnapshot;
            })().catch(error => window.webkit.messageHandlers.treeMutationTest.postMessage({
              type: 'error',
              message: String(error && error.message || error)
            }));
            """
            webView?.evaluateJavaScript(script) { _, error in
                if let error {
                    self.fail("Direct typing script failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func waitThenCheckDirectTyping() {
        let afterTyping = treeMessageCount
        guard afterTyping == directTypingBaseline else {
            fail("Direct text editing refreshed HTML tree while typing. baseline=\(directTypingBaseline), after=\(afterTyping)")
        }

        let script = """
        (() => {
          const frame = document.querySelector('.html-frame');
          const doc = frame?.contentDocument;
          if (!doc) throw new Error('HTML iframe not found for blur.');
          const active = doc.activeElement;
          if (!active || active === doc.body) throw new Error('No direct editing element is active.');
          const before = window.__chiseloTypingSnapshot;
          if (!before) throw new Error('Typing stability snapshot is unavailable.');
          const box = document.querySelector('#selectionBox');
          const stage = document.querySelector('#stage');
          const rectOf = (node) => {
            const rect = node?.getBoundingClientRect?.();
            return rect ? { x: rect.x, y: rect.y, w: rect.width, h: rect.height } : null;
          };
          const after = {
            target: rectOf(active),
            box: rectOf(box),
            peer: rectOf(doc.querySelector('.band-subtitle')),
            stageTransform: stage?.style.transform || '',
            stageWidth: stage?.style.width || '',
            stageHeight: stage?.style.height || ''
          };
          const close = (left, right, tolerance = 0.5) => left && right && ['x', 'y', 'w', 'h'].every((key) => Math.abs(left[key] - right[key]) <= tolerance);
          if (!close(before.target, after.target) || !close(before.box, after.box) || !close(before.peer, after.peer)) {
            throw new Error(`Direct typing moved geometry: before=${JSON.stringify(before)}, after=${JSON.stringify(after)}`);
          }
          if (before.stageTransform !== after.stageTransform || before.stageWidth !== after.stageWidth || before.stageHeight !== after.stageHeight) {
            throw new Error(`Direct typing changed canvas view: before=${JSON.stringify(before)}, after=${JSON.stringify(after)}`);
          }
          active.blur();
          window.webkit.messageHandlers.treeMutationTest.postMessage({ type: 'directBlurred' });
        })();
        """
        webView?.evaluateJavaScript(script) { _, error in
            if let error {
                self.fail("Direct blur script failed: \(error.localizedDescription)\n\(error)")
            }
        }
    }

    private func waitThenCheckDirectBlur() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
            guard let self else { return }
            let afterBlur = treeMessageCount
            guard afterBlur > directTypingBaseline else {
                fail("Direct text editing did not refresh HTML tree after blur. baseline=\(directTypingBaseline), after=\(afterBlur)")
            }

            let result: [String: Any] = [
                "type": "result",
                "styleBaseline": styleBaseline,
                "afterStyle": textBaseline,
                "textBaseline": textBaseline,
                "afterText": directTypingBaseline,
                "directTypingBaseline": directTypingBaseline,
                "afterDirectTyping": directTypingBaseline,
                "afterDirectBlur": afterBlur
            ]

            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]),
               let output = String(data: data, encoding: .utf8) {
                print(output)
            }
            exit(0)
        }
    }

    private func jsStringLiteral(_ string: String) throws -> String {
        let data = try JSONEncoder().encode(string)
        return String(data: data, encoding: .utf8) ?? "\"\""
    }

    private func fail(_ message: String) -> Never {
        fputs("HTML tree mutation throttle test failed: \(message)\n", stderr)
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

let test = HTMLTreeMutationThrottleTest(editorURL: editorURL, htmlURL: htmlURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
