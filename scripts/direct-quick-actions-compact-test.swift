import AppKit
import Foundation
import WebKit

final class DirectQuickActionsCompactTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let htmlURL: URL
    private var webView: WKWebView?

    init(editorURL: URL, htmlURL: URL) {
        self.editorURL = editorURL
        self.htmlURL = htmlURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "quickActions")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 900), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.fail("Timed out waiting for quick actions compact result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        do {
            let html = try String(contentsOf: htmlURL, encoding: .utf8)
            guard let data = html.data(using: .utf8) else {
                fail("Could not encode HTML as UTF-8.")
            }

            let base64 = data.base64EncodedString()
            let baseHref = htmlURL.deletingLastPathComponent().absoluteString
            let baseLiteral = try jsStringLiteral(baseHref)
            let script = """
            void window.ChiseloEditor.openHTMLFromBase64('\(base64)', \(baseLiteral))
              .then(async () => {
                const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
                const iframe = document.querySelector('iframe.html-frame');
                const doc = iframe && iframe.contentDocument;
                const win = iframe && iframe.contentWindow;
                if (!doc || !win) throw new Error('Direct HTML iframe is missing.');

                const target = doc.querySelector('h1') || doc.body.querySelector('*');
                if (!target) throw new Error('No selectable target found.');
                const rect = target.getBoundingClientRect();
                const x = rect.left + Math.min(24, Math.max(4, rect.width / 4));
                const y = rect.top + Math.min(24, Math.max(4, rect.height / 2));

                target.dispatchEvent(new win.PointerEvent('pointerdown', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: x,
                  clientY: y,
                  pointerId: 31
                }));
                doc.dispatchEvent(new win.PointerEvent('pointerup', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: x,
                  clientY: y,
                  pointerId: 31
                }));
                await sleep(80);

                const selected = window.ChiseloEditor.getSelection();
                if (!selected || selected.tagName !== target.tagName.toLowerCase()) {
                  throw new Error(`Target was not selected. selected=${selected && selected.tagName}`);
                }

                const quickBar = document.querySelector('#selectionBox .quick-action-bar');
                const quickChip = quickBar && quickBar.querySelector(':scope > .quick-chip');
                const quickMenu = quickBar && quickBar.querySelector(':scope > .quick-action-menu');
                const quickToggle = quickBar && quickBar.querySelector(':scope > .quick-action-menu-toggle');
                if (!quickBar || !quickChip || !quickMenu || !quickToggle) {
                  throw new Error('Compact quick actions chrome is incomplete.');
                }
                if (!quickMenu.hidden || quickBar.classList.contains('is-open')) {
                  throw new Error('Quick actions should be collapsed by default.');
                }
                if (quickBar.querySelector(':scope > .quick-action')) {
                  throw new Error('Action buttons should not be direct children in the collapsed toolbar.');
                }

                const collapsedRect = quickBar.getBoundingClientRect();
                if (collapsedRect.width > 280 || collapsedRect.height > 48) {
                  throw new Error(`Collapsed quick actions are too large: ${collapsedRect.width}x${collapsedRect.height}`);
                }

                quickToggle.click();
                await sleep(40);
                if (quickMenu.hidden || !quickBar.classList.contains('is-open') || !quickMenu.querySelector('.quick-action')) {
                  throw new Error('Quick actions menu did not expand on demand.');
                }
                const parentAction = [...quickMenu.querySelectorAll('.quick-action')]
                  .find((button) => button.textContent === '父级');
                if (!parentAction) {
                  throw new Error('Quick actions menu did not include parent selection.');
                }

                quickToggle.click();
                await sleep(40);
                if (!quickMenu.hidden || quickBar.classList.contains('is-open')) {
                  throw new Error('Quick actions menu did not collapse after toggling.');
                }

                quickToggle.click();
                await sleep(40);
                parentAction.click();
                await sleep(80);
                const parentSelection = window.ChiseloEditor.getSelection();
                if (!parentSelection || parentSelection.tagName !== 'header') {
                  throw new Error(`Parent quick action did not select the wrapping header: ${parentSelection && parentSelection.tagName}`);
                }

                window.webkit.messageHandlers.quickActions.postMessage({
                  type: 'result',
                  selectedTag: selected.tagName,
                  parentSelectedTag: parentSelection.tagName,
                  collapsedWidth: collapsedRect.width,
                  collapsedHeight: collapsedRect.height,
                  chipText: quickChip.textContent || ''
                });
              })
              .catch(error => {
                window.webkit.messageHandlers.quickActions.postMessage({
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
        guard message.name == "quickActions", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown JavaScript error.")
            return
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) {
            print(output)
            exit(0)
        }

        fail("Could not serialize quick actions compact result.")
    }

    private func jsStringLiteral(_ string: String) throws -> String {
        let data = try JSONEncoder().encode(string)
        return String(data: data, encoding: .utf8) ?? "\"\""
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct quick actions compact test failed: \(message)\n", stderr)
        exit(1)
    }
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = projectRoot
    .appendingPathComponent("Chiselo")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Editor")
    .appendingPathComponent("index.html")
let htmlURL = projectRoot
    .appendingPathComponent("examples")
    .appendingPathComponent("sample-html-page.html")

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let test = DirectQuickActionsCompactTest(editorURL: editorURL, htmlURL: htmlURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
