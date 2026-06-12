import AppKit
import Foundation
import WebKit

final class EditableLayoutIRTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?
    private var didStart = false

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "ir")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 860), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 24) { [weak self] in
            self?.fail("Timed out waiting for editable Layout IR result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.runFixture()
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            fail("Invalid bridge message.")
        }

        if type == "error" {
            fail(body["message"] as? String ?? "Unknown Layout IR failure.")
        }

        if type == "progress" {
            if let step = body["step"] as? String {
                print("Progress: \(step)")
            }
            return
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
          const editor = window.ChiseloEditor;
          const progress = (step) => window.webkit.messageHandlers.ir.postMessage({ type: 'progress', step });
          progress('bridge-ready');
          const deck = await editor.importHTMLFromBase64('\(base64)', '');
          progress('imported');
          const elements = deck.slides.flatMap(slide => slide.elements);
          const text = elements.find(element => element.text === 'Runtime Editable Title');
          const card = elements.find(element => element.semanticRole === 'card' || element.semanticRole === 'module');
          const iframe = elements.find(element => element.tagName === 'iframe');
          const canvas = elements.find(element => element.tagName === 'canvas');
          const pseudo = elements.find(element => element.sourceKind === 'pseudo-element' && element.text === 'AUTO');
          const groupedCardObjects = elements.filter(element => element.groupId && element.groupId === text?.groupId);
          const beforeMoveDeck = editor.getDeck();
          const beforeMoveElements = beforeMoveDeck.slides.flatMap(slide => slide.elements);
          const beforeMoveGroup = beforeMoveElements.filter(element => element.groupId && element.groupId === text?.groupId);
          const beforeMoveOutside = beforeMoveElements.find(element => element.tagName === 'iframe');
          const moduleSelection = text?.groupId ? editor.selectGroupById(text.groupId) : null;
          editor.command('nudgeRightBig');
          const afterMoveDeck = editor.getDeck();
          const afterMoveElements = afterMoveDeck.slides.flatMap(slide => slide.elements);
          const afterMoveGroup = afterMoveElements.filter(element => element.groupId && element.groupId === text?.groupId);
          const afterMoveOutside = afterMoveElements.find(element => element.id === beforeMoveOutside?.id);
          const movedGroupSelection = editor.getSelection();
          const moduleDeck = {
            version: 1,
            irVersion: 'layout-ir-v1',
            sourceKind: 'runtime-html-snapshot',
            canvas: { width: 640, height: 360, background: '#ffffff' },
            slides: [{
              id: 'module-slide',
              title: 'Module Internal Alignment',
              elements: [
                { id: 'metric-a', type: 'rect', groupId: 'metrics', groupRole: 'module', groupLabel: '指标模块', x: 40, y: 60, w: 70, h: 42, rotation: 0, z: 1, style: { fill: '#dbeafe', radius: 8 } },
                { id: 'metric-b', type: 'rect', groupId: 'metrics', groupRole: 'module', groupLabel: '指标模块', x: 170, y: 80, w: 92, h: 50, rotation: 0, z: 2, style: { fill: '#dcfce7', radius: 8 } },
                { id: 'metric-c', type: 'rect', groupId: 'metrics', groupRole: 'module', groupLabel: '指标模块', x: 345, y: 108, w: 56, h: 36, rotation: 0, z: 3, style: { fill: '#fee2e2', radius: 8 } },
                { id: 'outside', type: 'rect', x: 510, y: 60, w: 46, h: 40, rotation: 0, z: 4, style: { fill: '#f8fafc', radius: 6 } }
              ]
            }]
          };
          editor.loadDeck(moduleDeck);
          editor.selectElementById('metric-b');
          const internalSelection = editor.selectGroupById('metrics');
          editor.command('matchWidth');
          editor.command('matchHeight');
          editor.command('distributeHorizontal');
          editor.command('distributeVertical');
          const internalDeck = editor.getDeck();
          const internalElements = internalDeck.slides[0].elements;
          const metricA = internalElements.find(element => element.id === 'metric-a');
          const metricB = internalElements.find(element => element.id === 'metric-b');
          const metricC = internalElements.find(element => element.id === 'metric-c');
          const outside = internalElements.find(element => element.id === 'outside');
          const horizontalGapAB = metricB.x - (metricA.x + metricA.w);
          const horizontalGapBC = metricC.x - (metricB.x + metricB.w);
          const verticalGapAB = metricB.y - (metricA.y + metricA.h);
          const verticalGapBC = metricC.y - (metricB.y + metricB.h);
          const exportHTML = editor.exportHTML();

          const assertions = {
            deckMarkedAsIR: deck.irVersion === 'layout-ir-v1' && deck.sourceKind === 'runtime-html-snapshot',
            dynamicTextCaptured: Boolean(text && text.type === 'text' && text.editability === 'text-editable' && text.fidelity === 'native'),
            visualObjectCaptured: Boolean(card && card.editability === 'style-editable'),
            cardObjectsGrouped: Boolean(text?.groupId && groupedCardObjects.length >= 4 && groupedCardObjects.some(element => element.type === 'rect') && groupedCardObjects.some(element => element.text === '96%')),
            moduleGroupSelectable: Boolean(moduleSelection && moduleSelection.type === 'deck-group' && moduleSelection.groupId === text?.groupId && moduleSelection.w > 300 && moduleSelection.h > 100),
            moduleGroupNudgesTogether: Boolean(beforeMoveGroup.length >= 4 && beforeMoveGroup.every(before => {
              const after = afterMoveGroup.find(element => element.id === before.id);
              return after && after.x === before.x + 10 && after.y === before.y;
            })),
            moduleGroupSelectionPersists: Boolean(movedGroupSelection && movedGroupSelection.type === 'deck-group' && movedGroupSelection.x === moduleSelection.x + 10),
            moduleGroupNudgeKeepsOutsideObjectsStable: Boolean(beforeMoveOutside && afterMoveOutside && afterMoveOutside.x === beforeMoveOutside.x && afterMoveOutside.y === beforeMoveOutside.y),
            moduleGroupInternalSizeMatch: Boolean(internalSelection && [metricA, metricB, metricC].every(element => element.w === metricB.w && element.h === metricB.h)),
            moduleGroupInternalDistribute: Boolean(Math.abs(horizontalGapAB - horizontalGapBC) <= 1 && Math.abs(verticalGapAB - verticalGapBC) <= 1),
            moduleGroupInternalKeepsOutsideStable: Boolean(outside.x === 510 && outside.y === 60 && outside.w === 46 && outside.h === 40),
            iframeFallbackCaptured: Boolean(iframe && iframe.editability === 'whole-object' && iframe.fidelity === 'fallback'),
            canvasFallbackCaptured: Boolean(canvas && canvas.editability === 'whole-object' && ['snapshot', 'fallback'].includes(canvas.fidelity)),
            pseudoExtracted: Boolean(pseudo && pseudo.fidelity === 'approximated'),
            cleanStaticExport: exportHTML.includes('Module Internal Alignment') && !exportHTML.includes('data-chiselo')
          };

          const failed = Object.entries(assertions).filter(([, value]) => !value);
          if (failed.length) {
            throw new Error(JSON.stringify({ failed, assertions, deck, exportHTML }));
          }

          window.webkit.messageHandlers.ir.postMessage({
            type: 'result',
            assertions,
            counts: {
              slides: deck.slides.length,
              elements: elements.length,
              text: elements.filter(element => element.type === 'text').length,
              images: elements.filter(element => element.type === 'image').length,
              wholeObjects: elements.filter(element => element.editability === 'whole-object').length,
              groups: new Set(elements.map(element => element.groupId).filter(Boolean)).size
            }
          });
        })().catch(error => {
          window.webkit.messageHandlers.ir.postMessage({ type: 'error', message: String(error && error.message || error) });
        });
        """

        webView?.evaluateJavaScript(script) { [weak self] _, error in
            if let error {
                self?.fail("Could not run Layout IR fixture: \(error.localizedDescription)")
            }
        }
    }

    private func fail(_ message: String) -> Never {
        fputs("Editable Layout IR test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Editable Layout IR Fixture</title>
      <style>
        html, body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        #app { width: 960px; height: 540px; position: relative; background: #f8fafc; overflow: hidden; }
        .badge::before { content: "AUTO"; display: inline-block; padding: 4px 8px; border-radius: 999px; background: #2563eb; color: #fff; font-weight: 800; }
        .card { position: absolute; left: 64px; top: 72px; width: 430px; padding: 28px; background: white; border: 1px solid #dbe3ef; border-radius: 18px; box-shadow: 0 18px 44px rgba(15,23,42,.14); }
        .metricValue { font-size: 34px; font-weight: 800; color: #0f172a; }
        iframe { position: absolute; right: 50px; top: 68px; width: 260px; height: 150px; border: 0; }
        canvas { position: absolute; right: 70px; bottom: 72px; width: 220px; height: 118px; background: #0f172a; }
      </style>
    </head>
    <body>
      <div id="app"></div>
      <script>
        setTimeout(() => {
          const app = document.getElementById('app');
          app.innerHTML = `
            <section class="card">
              <span class="badge"></span>
              <h1>Runtime Editable Title</h1>
              <p>Dify-style runtime content becomes deterministic editable objects.</p>
              <div class="metricValue">96%</div>
            </section>
            <iframe src="https://example.com/embed"></iframe>
            <canvas width="220" height="118"></canvas>
          `;
          const canvas = app.querySelector('canvas');
          const ctx = canvas.getContext('2d');
          ctx.fillStyle = '#38bdf8';
          ctx.fillRect(24, 28, 170, 44);
        }, 80);
      </script>
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

let test = EditableLayoutIRTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
