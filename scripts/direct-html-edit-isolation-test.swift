import AppKit
import Foundation
import WebKit

final class DirectHTMLEditIsolationTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let html: String
    private let baseHref: String
    private var webView: WKWebView?
    private var didStart = false

    init(editorURL: URL, html: String, baseHref: String = "") {
        self.editorURL = editorURL
        self.html = html
        self.baseHref = baseHref
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "editIsolation")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 900), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.fail("Timed out waiting for edit isolation result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !didStart else { return }
        didStart = true
        let base64 = Data(html.utf8).base64EncodedString()
        guard let literalData = try? JSONEncoder().encode(base64),
              let base64Literal = String(data: literalData, encoding: .utf8),
              let baseData = try? JSONEncoder().encode(baseHref),
              let baseLiteral = String(data: baseData, encoding: .utf8) else {
            fail("Could not encode fixture HTML for JavaScript.")
        }
        let script = """
        void (async () => {
          const editor = window.ChiseloEditor;
          const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));
          const computedStyleSnapshot = (node, pseudo = null) => {
            const style = node.ownerDocument.defaultView.getComputedStyle(node, pseudo);
            const values = {};
            for (const property of style) {
              values[property] = style.getPropertyValue(property);
            }
            return values;
          };
          const frame = (entry) => {
            const node = entry.node;
            const rect = node.getBoundingClientRect();
            return {
              x: rect.left,
              y: rect.top,
              w: rect.width,
              h: rect.height,
              tag: node.tagName.toLowerCase(),
              style: computedStyleSnapshot(node),
              beforeStyle: computedStyleSnapshot(node, '::before'),
              afterStyle: computedStyleSnapshot(node, '::after'),
              source: entry.compareSource ? node.outerHTML : null
            };
          };
          const snapshot = (entries) => entries.map(entry => frame(entry));
          const assertStyleSame = (label, index, pseudo, before, after) => {
            const properties = new Set([...Object.keys(before), ...Object.keys(after)]);
            for (const property of properties) {
              if (before[property] !== after[property]) {
                throw new Error(`${label} restyled peer ${index} ${pseudo}${property}: ${before[property]} -> ${after[property]}`);
              }
            }
          };
          const assertSame = (label, before, after, options = {}) => {
            for (let index = 0; index < before.length; index += 1) {
              if (index > 0 || options.allowTargetGeometryChange !== true) {
                for (const key of ['x', 'y', 'w', 'h']) {
                  if (Math.abs(before[index][key] - after[index][key]) > 0.5) {
                    throw new Error(`${label} moved peer ${index}.${key}: ${before[index][key]} -> ${after[index][key]}`);
                  }
                }
              }
              if (index > 0) {
                assertStyleSame(label, index, '', before[index].style, after[index].style);
                assertStyleSame(label, index, '::before ', before[index].beforeStyle, after[index].beforeStyle);
                assertStyleSame(label, index, '::after ', before[index].afterStyle, after[index].afterStyle);
              }
              if (before[index].source !== null && before[index].source !== after[index].source) {
                throw new Error(`${label} mutated unrelated peer ${index} source.`);
              }
            }
          };

          await editor.openHTMLFromBase64(\(base64Literal), \(baseLiteral));
          await wait(120);
          const iframe = document.querySelector('iframe.html-frame');
          const doc = iframe?.contentDocument;
          if (!doc) throw new Error('HTML frame is unavailable.');

          const visible = (node) => {
            const rect = node.getBoundingClientRect();
            const style = doc.defaultView.getComputedStyle(node);
            return rect.width > 24 && rect.height > 12 && style.display !== 'none' && style.visibility !== 'hidden';
          };
          const target = doc.querySelector('#target-title') || [...doc.querySelectorAll('h1,h2,h3,p,button,li')]
            .find(node => visible(node) && !node.closest('table') && String(node.textContent || '').trim().length > 0);
          if (!target) throw new Error('Could not find a real text target.');

          const peers = [...doc.body.querySelectorAll('*')]
            .filter(node => node !== target && !target.contains(node) && visible(node))
            .slice(0, 120)
            .map(node => ({ node, compareSource: !node.contains(target) }));
          if (!peers.some(entry => entry.compareSource)) {
            throw new Error('Real page did not expose an unrelated peer for isolation review.');
          }

          const entries = [{ node: target, compareSource: false }, ...peers];
          const initial = snapshot(entries);
          const targetId = target.getAttribute('data-chiselo-id');
          if (!targetId || !editor.selectHTMLById(targetId)) throw new Error('Could not select real text target.');
          editor.setSelectedHTMLText('A much longer replacement title that must remain inside its original object frame without moving any neighboring module');
          await wait(80);
          const afterText = snapshot(entries);
          assertSame('text edit', initial, afterText);

          const selectedTitle = editor.getSelection();
          editor.updateElement({
            ...selectedTitle,
            style: {
              ...selectedTitle.style,
              fontSize: 42,
              lineHeight: 1.05,
              paddingTop: 12,
              paddingBottom: 12
            }
          });
          await wait(80);
          const afterStyle = snapshot(entries);
          assertSame('style edit', afterText, afterStyle);

          const beforeMoveSelection = editor.getSelection();
          editor.updateElement({
            ...beforeMoveSelection,
            x: beforeMoveSelection.x + 13,
            y: beforeMoveSelection.y + 9
          });
          await wait(80);
          const afterMove = snapshot(entries);
          assertSame('geometry move', afterStyle, afterMove, { allowTargetGeometryChange: true });
          if (Math.abs(afterMove[0].x - afterStyle[0].x - 13) > 0.5 || Math.abs(afterMove[0].y - afterStyle[0].y - 9) > 0.5) {
            throw new Error(`geometry move did not move only the target by the requested delta: ${afterStyle[0].x},${afterStyle[0].y} -> ${afterMove[0].x},${afterMove[0].y}`);
          }

          const beforeResizeSelection = editor.getSelection();
          editor.updateElement({
            ...beforeResizeSelection,
            w: beforeResizeSelection.w + 24,
            h: beforeResizeSelection.h + 12
          });
          await wait(80);
          const afterResize = snapshot(entries);
          assertSame('geometry resize', afterMove, afterResize, { allowTargetGeometryChange: true });
          if (Math.abs(afterResize[0].w - afterMove[0].w - 24) > 1 || Math.abs(afterResize[0].h - afterMove[0].h - 12) > 1) {
            throw new Error(`geometry resize did not resize only the target by the requested delta: ${afterMove[0].w}x${afterMove[0].h} -> ${afterResize[0].w}x${afterResize[0].h}`);
          }

          const exported = editor.exportHTML();
          if (!exported.includes('A much longer replacement title')) {
            throw new Error('Edited source was not exported cleanly.');
          }
          if (exported.includes('data-chiselo-local-frame-locked')) {
            throw new Error('Edit isolation marker leaked into exported HTML.');
          }

          window.webkit.messageHandlers.editIsolation.postMessage({
            type: 'result',
            textStable: true,
            styleStable: true,
            geometryStable: true,
            peerCount: peers.filter(entry => entry.compareSource).length,
            comparedStylePropertyCount: Object.keys(afterStyle[0].style).length,
            targetTag: target.tagName.toLowerCase(),
            targetWidth: afterStyle[0].w,
            targetHeight: afterStyle[0].h
          });
        })().catch(error => {
          window.webkit.messageHandlers.editIsolation.postMessage({ type: 'error', message: `${error.message || String(error)}\n${error.stack || ''}` });
        });
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "editIsolation", let body = message.body as? [String: Any] else { return }
        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown edit isolation error.")
        }
        guard body["textStable"] as? Bool == true,
              body["styleStable"] as? Bool == true,
              body["geometryStable"] as? Bool == true else {
            fail("Edit isolation assertions were not satisfied: \(body)")
        }
        print("Direct HTML edit isolation test passed")
        exit(0)
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML edit isolation test failed: \(message)\n", stderr)
        exit(1)
    }

    static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        * { box-sizing: border-box; }
        body { margin: 0; padding: 32px; font-family: Arial, sans-serif; background: #f4f5f7; }
        .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; }
        .card { min-width: 0; padding: 20px; background: white; border: 1px solid #d5d8de; }
        .card h2 { margin: 0 0 12px; font-size: 22px; line-height: 1.2; }
        .card p { margin: 0; color: #4b5563; }
        #below { margin-top: 24px; height: 72px; padding: 20px; background: #dbeafe; }
      </style>
    </head>
    <body>
      <section class="grid">
        <article class="card" id="card-a"><h2 id="target-title">Short title</h2><p>Target module body</p></article>
        <article class="card" id="card-b"><h2>Stable B</h2><p>Must not move</p></article>
        <article class="card" id="card-c"><h2>Stable C</h2><p>Must not move</p></article>
      </section>
      <section id="below">The section below must not move.</section>
    </body>
    </html>
    """
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = root.appendingPathComponent("Chiselo/Resources/Editor/index.html")
guard FileManager.default.fileExists(atPath: editorURL.path) else {
    fputs("Editor resource missing: \(editorURL.path)\n", stderr)
    exit(1)
}

let inputURL = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0) }
let inputHTML: String
let baseHref: String
if let inputURL {
    do {
        inputHTML = try String(contentsOf: inputURL, encoding: .utf8)
        baseHref = inputURL.deletingLastPathComponent().absoluteString
    } catch {
        fputs("Could not read real-case HTML: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
} else {
    inputHTML = DirectHTMLEditIsolationTest.fixtureHTML
    baseHref = ""
}

let test = DirectHTMLEditIsolationTest(editorURL: editorURL, html: inputHTML, baseHref: baseHref)
test.start()
RunLoop.main.run()
