import AppKit
import Foundation
import WebKit

final class DirectHTMLCanvasInteractionTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let htmlURL: URL
    private var webView: WKWebView?

    init(editorURL: URL, htmlURL: URL) {
        self.editorURL = editorURL
        self.htmlURL = htmlURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "directInteraction")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 900), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 75) { [weak self] in
            self?.fail("Timed out waiting for direct interaction result.")
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
                const progress = (step) => window.webkit.messageHandlers.directInteraction.postMessage({ type: 'progress', step });
                const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
                progress('loaded');
                const iframe = document.querySelector('iframe.html-frame');
                const doc = iframe && iframe.contentDocument;
                const win = iframe && iframe.contentWindow;
                if (!doc || !win) throw new Error('Direct HTML iframe is missing.');

                const elementLayer = document.getElementById('elementLayer');
                const layerPointerEvents = getComputedStyle(elementLayer).pointerEvents;
                if (layerPointerEvents !== 'none') {
                  throw new Error(`HTML element layer is blocking direct canvas clicks: pointer-events=${layerPointerEvents}`);
                }
                progress('html-layer-pass-through');

                const target = doc.querySelector('h1') || doc.body.querySelector('*');
                if (!target) throw new Error('No clickable body target found.');
                const rect = target.getBoundingClientRect();
                const x = rect.left + Math.min(24, Math.max(4, rect.width / 4));
                const y = rect.top + Math.min(24, Math.max(4, rect.height / 2));

                target.dispatchEvent(new win.PointerEvent('pointerdown', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: x,
                  clientY: y,
                  pointerId: 7
                }));
                doc.dispatchEvent(new win.PointerEvent('pointerup', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: x,
                  clientY: y,
                  pointerId: 7
                }));
                await sleep(80);

                const selected = window.ChiseloEditor.getSelection();
                if (!selected || selected.tagName !== target.tagName.toLowerCase()) {
                  throw new Error(`Body click did not select target. selected=${selected && selected.tagName}, target=${target.tagName.toLowerCase()}`);
                }
                progress('body-click-selected');

                const beforeZoom = window.ChiseloEditor.getViewportState();
                doc.dispatchEvent(new win.WheelEvent('wheel', {
                  bubbles: true,
                  cancelable: true,
                  metaKey: true,
                  deltaY: -420,
                  clientX: x,
                  clientY: y
                }));
                await sleep(80);

                const afterZoom = window.ChiseloEditor.getViewportState();
                const handle = document.querySelector('#selectionBox .resize-handle[data-handle="se"]');
                const handleRect = handle && handle.getBoundingClientRect();
                const handleWidth = handleRect ? handleRect.width : 0;

                if (!(afterZoom.userZoom > beforeZoom.userZoom && afterZoom.scale > beforeZoom.scale)) {
                  throw new Error(`Command-wheel zoom did not increase scale. before=${JSON.stringify(beforeZoom)}, after=${JSON.stringify(afterZoom)}`);
                }
                if (handleWidth < 10) {
                  throw new Error(`Resize handle is too small after zoom compensation: ${handleWidth}`);
                }
                progress('zoom-checked');

                const zoomLockedBeforeClick = window.ChiseloEditor.getViewportState();
                const clickTarget = doc.querySelector('p') || target;
                const clickRect = clickTarget.getBoundingClientRect();
                const clickX = clickRect.left + Math.min(24, Math.max(4, clickRect.width / 4));
                const clickY = clickRect.top + Math.min(12, Math.max(4, clickRect.height / 2));
                clickTarget.dispatchEvent(new win.PointerEvent('pointerdown', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: clickX,
                  clientY: clickY,
                  pointerId: 8
                }));
                doc.dispatchEvent(new win.PointerEvent('pointerup', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: clickX,
                  clientY: clickY,
                  pointerId: 8
                }));
                await sleep(80);
                const zoomLockedAfterClick = window.ChiseloEditor.getViewportState();
                if (Math.abs(zoomLockedAfterClick.scale - zoomLockedBeforeClick.scale) > 0.001) {
                  throw new Error(`Selecting after zoom changed scale. before=${JSON.stringify(zoomLockedBeforeClick)}, after=${JSON.stringify(zoomLockedAfterClick)}`);
                }
                progress('zoom-preserved-after-selection');

                async function assertDoubleClickTextEdit(label, node, replacementText = null) {
                  if (!node) throw new Error(`${label} target not found.`);
                  const nodeRect = node.getBoundingClientRect();
                  const nodeX = nodeRect.left + Math.min(24, Math.max(4, nodeRect.width / 4));
                  const nodeY = nodeRect.top + Math.min(12, Math.max(4, nodeRect.height / 2));
                  return assertDoubleClickTextEditAtPoint(label, node, nodeX, nodeY, replacementText);
                }

                async function assertDoubleClickTextEditAtPoint(label, expectedNode, nodeX, nodeY, replacementText = null) {
                  const dispatchTarget = doc.elementFromPoint(nodeX, nodeY) || expectedNode;
                  dispatchTarget.dispatchEvent(new win.MouseEvent('dblclick', {
                    bubbles: true,
                    cancelable: true,
                    clientX: nodeX,
                    clientY: nodeY,
                    detail: 2
                  }));
                  await sleep(160);

                  const active = doc.activeElement;
                  const selectedText = String(win.getSelection()).trim();
                  if (active !== expectedNode || expectedNode.getAttribute('contenteditable') !== 'true') {
                    throw new Error(`${label} did not enter text editing. active=${active && active.tagName}, target=${dispatchTarget && dispatchTarget.tagName}, editable=${expectedNode.getAttribute('contenteditable')}`);
                  }
                  if (expectedNode.getAttribute('data-chiselo-edit-font-lock') !== 'true') {
                    throw new Error(`${label} did not lock computed typography while editing.`);
                  }
                  if (!expectedNode.style.getPropertyValue('--chiselo-edit-font-family') || !expectedNode.style.getPropertyValue('--chiselo-edit-font-size')) {
                    throw new Error(`${label} did not expose typography lock variables.`);
                  }
                  if (!selectedText) {
                    throw new Error(`${label} entered text editing without selecting text.`);
                  }

                  if (replacementText) {
                    doc.execCommand('insertText', false, replacementText);
                    await sleep(40);
                    if (!expectedNode.textContent.includes(replacementText)) {
                      throw new Error(`${label} did not accept inserted text.`);
                    }
                  }

                  expectedNode.blur();
                  await sleep(50);
                  if (expectedNode.hasAttribute('data-chiselo-edit-font-lock') || expectedNode.style.getPropertyValue('--chiselo-edit-font-family')) {
                    throw new Error(`${label} leaked temporary typography lock into the document.`);
                  }
                  return selectedText;
                }

                const heading = doc.querySelector('h1');
                const subtitle = doc.querySelector('.band-subtitle') || doc.querySelector('p');
                const headingSelectedText = await assertDoubleClickTextEdit('Heading', heading);
                const subtitleSelectedText = await assertDoubleClickTextEdit('Paragraph', subtitle);
                progress('basic-double-clicks');

                const listItem = [...doc.querySelectorAll('li')]
                  .find((item) => item.textContent.includes('衬砌台车弧形模板'));
                if (!listItem) throw new Error('Engineering equipment list item not found.');
                const listSelectedText = await assertDoubleClickTextEdit('List item', listItem, 'CHISELO_TEXT_EDIT_TEST');
                progress('list-edit');

                const headingRect = heading.getBoundingClientRect();
                const svgOverlay = doc.createElementNS('http://www.w3.org/2000/svg', 'svg');
                svgOverlay.setAttribute('class', 'cap watermark');
                svgOverlay.setAttribute('aria-hidden', 'true');
                svgOverlay.setAttribute('width', String(Math.min(headingRect.width, 360)));
                svgOverlay.setAttribute('height', String(Math.max(headingRect.height, 56)));
                svgOverlay.style.cssText = [
                  'position:absolute',
                  `left:${headingRect.left + win.scrollX}px`,
                  `top:${headingRect.top + win.scrollY}px`,
                  `width:${Math.min(headingRect.width, 360)}px`,
                  `height:${Math.max(headingRect.height, 56)}px`,
                  'z-index:2147483646',
                  'pointer-events:auto'
                ].join(';');
                const svgRect = doc.createElementNS('http://www.w3.org/2000/svg', 'rect');
                svgRect.setAttribute('x', '0');
                svgRect.setAttribute('y', '0');
                svgRect.setAttribute('width', '100%');
                svgRect.setAttribute('height', '100%');
                svgRect.setAttribute('fill', 'transparent');
                svgOverlay.appendChild(svgRect);
                doc.body.appendChild(svgOverlay);
                const overlayClickX = headingRect.left + 34;
                const overlayClickY = headingRect.top + Math.max(10, headingRect.height / 2);
                window.ChiseloEditor.selectHTMLAtPoint(overlayClickX, overlayClickY);
                await sleep(100);
                const svgOverlaySelection = window.ChiseloEditor.getSelection();
                if (!svgOverlaySelection || svgOverlaySelection.tagName !== 'h1') {
                  throw new Error(`SVG overlay click did not select underlying heading: ${JSON.stringify(svgOverlaySelection)}`);
                }
                svgOverlay.remove();
                progress('svg-overlay-selection');

                const overlay = doc.createElement('div');
                overlay.setAttribute('aria-hidden', 'true');
                overlay.style.cssText = [
                  'position:absolute',
                  `left:${headingRect.left + win.scrollX}px`,
                  `top:${headingRect.top + win.scrollY}px`,
                  `width:${Math.min(headingRect.width, 340)}px`,
                  `height:${headingRect.height}px`,
                  'z-index:2147483647',
                  'background:transparent',
                  'pointer-events:auto'
                ].join(';');
                doc.body.appendChild(overlay);
                window.ChiseloEditor.selectHTMLAtPoint(
                  headingRect.left + 32,
                  headingRect.top + Math.max(10, headingRect.height / 2)
                );
                await sleep(100);
                const transparentOverlaySelection = window.ChiseloEditor.getSelection();
                if (!transparentOverlaySelection || transparentOverlaySelection.tagName !== 'h1') {
                  throw new Error(`Transparent aria-hidden overlay click did not select underlying heading: ${JSON.stringify(transparentOverlaySelection)}`);
                }
                const overlaySelectedText = transparentOverlaySelection.text;
                overlay.remove();
                progress('transparent-overlay-selection');

                window.webkit.messageHandlers.directInteraction.postMessage({
                  type: 'result',
                  selected,
                  beforeZoom,
                  afterZoom,
                  zoomLockedAfterClick,
                  handleWidth,
                  headingSelectedText,
                  subtitleSelectedText,
                  svgOverlaySelectionText: svgOverlaySelection.text,
                  overlaySelectedText,
                  listSelectedText,
                  editedListText: listItem.textContent
                });
              })
              .catch(error => {
                window.webkit.messageHandlers.directInteraction.postMessage({
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
        guard message.name == "directInteraction", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown JavaScript error.")
            return
        }

        if body["type"] as? String == "progress" {
            if let step = body["step"] as? String {
                print("Progress: \(step)")
            }
            return
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) {
            print(output)
            exit(0)
        }

        fail("Could not serialize direct interaction test result.")
    }

    private func jsStringLiteral(_ string: String) throws -> String {
        let data = try JSONEncoder().encode(string)
        return String(data: data, encoding: .utf8) ?? "\"\""
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML canvas interaction test failed: \(message)\n", stderr)
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

let test = DirectHTMLCanvasInteractionTest(editorURL: editorURL, htmlURL: htmlURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
