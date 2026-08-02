import AppKit
import Foundation
import WebKit

final class DirectHTMLTableCellGeometryLockTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let htmlURL: URL
    private var webView: WKWebView?

    init(editorURL: URL, htmlURL: URL) {
        self.editorURL = editorURL
        self.htmlURL = htmlURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "tableCellLock")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1440, height: 1000), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.fail("Timed out waiting for table cell geometry lock result.")
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

                const table = [...doc.querySelectorAll('table')].find((node) => node.textContent.includes('免费') || node.textContent.includes('引导注册'));
                if (!table) throw new Error('Could not find target pricing table.');
                window.ChiseloEditor.selectHTML('table:nth-of-type(2)');
                await sleep(80);
                const freeHandleCount = document.getElementById('selectionBox').querySelectorAll('.resize-handle').length;
                if (freeHandleCount === 0) throw new Error('Expected table selection to have resize handles before selecting a locked cell.');

                const cells = [...doc.querySelectorAll('td,th')];
                const cell = cells.find((node) => node.textContent.includes('免费') || node.textContent.includes('引导注册'));
                if (!cell) throw new Error('Could not find target pricing table cell.');

                const beforeRect = cell.getBoundingClientRect();
                const beforeText = cell.textContent;
                const startX = beforeRect.left + Math.min(24, beforeRect.width / 2);
                const startY = beforeRect.top + Math.min(18, beforeRect.height / 2);

                cell.dispatchEvent(new win.PointerEvent('pointerdown', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: startX,
                  clientY: startY,
                  pointerId: 77
                }));
                doc.dispatchEvent(new win.PointerEvent('pointermove', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: startX + 360,
                  clientY: startY + 20,
                  pointerId: 77
                }));
                doc.dispatchEvent(new win.PointerEvent('pointerup', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: startX + 360,
                  clientY: startY + 20,
                  pointerId: 77
                }));
                await sleep(120);

                const afterRect = cell.getBoundingClientRect();
                const selection = window.ChiseloEditor.getSelection();
                const selectionBox = document.getElementById('selectionBox');
                const handleCount = selectionBox.querySelectorAll('.resize-handle').length;
                const moved = Math.abs(afterRect.left - beforeRect.left) > 1 || Math.abs(afterRect.top - beforeRect.top) > 1;
                const transformed = Boolean(cell.style.transform || cell.style.position === 'absolute' || cell.dataset.chiseloTranslateX);
                const textIntact = cell.textContent === beforeText && cell.textContent.includes('免费');

                window.ChiseloEditor.updateElement({
                  ...selection,
                  x: selection.x + 180,
                  y: selection.y + 20,
                  w: Math.max(80, selection.w - 40),
                  h: Math.max(24, selection.h - 8)
                });
                await sleep(80);

                const afterPanelRect = cell.getBoundingClientRect();
                const panelMoved = Math.abs(afterPanelRect.left - beforeRect.left) > 1 || Math.abs(afterPanelRect.top - beforeRect.top) > 1;
                const panelTransformed = Boolean(cell.style.transform || cell.style.position === 'absolute' || cell.dataset.chiseloTranslateX);

                const safetyLocked = selection.editSafetyLevel === 'locked'
                  && /表格/.test(selection.editSafetyTitle || '')
                  && typeof selection.editSafetyContainerId === 'string'
                  && selection.editSafetyContainerId.length > 0;

                if (moved || transformed || panelMoved || panelTransformed || !textIntact || handleCount !== 0 || selection.layoutMode !== 'table-cell' || !safetyLocked) {
                  throw new Error(JSON.stringify({
                    moved,
                    transformed,
                    panelMoved,
                    panelTransformed,
                    textIntact,
                    handleCount,
                    safetyLocked,
                    selection
                  }));
                }

                window.ChiseloEditor.command('selectTable');
                await sleep(80);
                const tableSelection = window.ChiseloEditor.getSelection();
                const tableHandleCount = document.getElementById('selectionBox').querySelectorAll('.resize-handle').length;
                if (!tableSelection || tableSelection.tagName !== 'table' || tableHandleCount === 0) {
                  throw new Error(`Safe whole-table selection did not activate: ${JSON.stringify({ tableSelection, tableHandleCount })}`);
                }

                window.webkit.messageHandlers.tableCellLock.postMessage({
                  type: 'result',
                  text: cell.textContent,
                  selection,
                  tableSelection,
                  handleCount,
                  before: { x: beforeRect.left, y: beforeRect.top, w: beforeRect.width, h: beforeRect.height },
                  after: { x: afterRect.left, y: afterRect.top, w: afterRect.width, h: afterRect.height }
                });
              })
              .catch(error => {
                window.webkit.messageHandlers.tableCellLock.postMessage({
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
        guard message.name == "tableCellLock", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown JavaScript error.")
            return
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) {
            print(output)
            exit(0)
        }

        fail("Could not serialize table cell geometry lock test result.")
    }

    private func jsStringLiteral(_ string: String) throws -> String {
        let data = try JSONEncoder().encode(string)
        return String(data: data, encoding: .utf8) ?? "\"\""
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML table cell geometry lock test failed: \(message)\n", stderr)
        exit(1)
    }
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = projectRoot
    .appendingPathComponent("Chiselo")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Editor")
    .appendingPathComponent("index.html")

let defaultHTMLURL = projectRoot
    .appendingPathComponent("scripts")
    .appendingPathComponent("fixtures")
    .appendingPathComponent("table-cell-geometry-lock.html")
let htmlPath = CommandLine.arguments.dropFirst().first ?? defaultHTMLURL.path
let htmlURL = URL(fileURLWithPath: htmlPath)

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let test = DirectHTMLTableCellGeometryLockTest(editorURL: editorURL, htmlURL: htmlURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
