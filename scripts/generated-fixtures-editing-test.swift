import AppKit
import Foundation
import WebKit

final class GeneratedFixturesEditingTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let payloadJSON: String
    private let outputDirectory: URL
    private var webView: WKWebView?

    init(editorURL: URL, payloadJSON: String, outputDirectory: URL) {
        self.editorURL = editorURL
        self.payloadJSON = payloadJSON
        self.outputDirectory = outputDirectory
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "generatedFixtures")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1440, height: 940), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.fail("Timed out waiting for generated fixture editing test.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let script = """
        void (async () => {
          const payload = \(payloadJSON);
          const editor = window.ChiseloEditor;
          const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
          const assert = (condition, message, extra = {}) => {
            if (!condition) throw new Error(JSON.stringify({ message, ...extra }));
          };
          const replacementSVG = '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360"><rect width="640" height="360" rx="32" fill="#0f766e"/><circle cx="130" cy="112" r="52" fill="#facc15"/><rect x="242" y="82" width="260" height="36" rx="18" fill="#ecfeff"/><rect x="242" y="146" width="318" height="28" rx="14" fill="#99f6e4"/><rect x="242" y="198" width="286" height="28" rx="14" fill="#5eead4"/><text x="56" y="304" font-family="Arial, sans-serif" font-size="38" font-weight="700" fill="#ffffff">CHISELO_REPLACED_IMAGE</text></svg>';
          const replacementBase64 = btoa(replacementSVG);
          const htmlOutputs = [];

          for (const fixture of payload.htmlFixtures) {
            await editor.openHTMLFromBase64(fixture.base64, fixture.baseHref);
            await sleep(180);

            const before = editor.getHTMLSummary();
            const title = editor.selectHTML('h1');
            assert(title && title.tagName === 'h1', 'Could not select h1', { fixture: fixture.name, title });
            editor.command('setLayoutTransform');
            editor.updateElement({
              ...title,
              x: title.x + fixture.titleMove.x,
              y: title.y + fixture.titleMove.y,
              style: {
                ...title.style,
                color: 'rgb(18, 59, 99)',
                fontSize: Math.max(28, Math.round(title.style.fontSize + fixture.titleFontDelta)),
                lineHeight: 1.08
              }
            });
            editor.setSelectedHTMLText(fixture.editedTitle);

            const image = editor.selectHTML('img');
            assert(image && image.tagName === 'img', 'Could not select image', { fixture: fixture.name, image });
            let replacedImage = editor.replaceSelectedImageFromBase64('image/svg+xml', replacementBase64);
            assert(replacedImage && replacedImage.imageSource && replacedImage.imageSource.includes(replacementBase64), 'Could not replace image', { fixture: fixture.name, replacedImage });
            replacedImage = await editor.settleSelectedImage();
            assert(replacedImage && replacedImage.imageSource && replacedImage.imageSource.includes(replacementBase64), 'Image replacement did not settle', { fixture: fixture.name, replacedImage });
            editor.command('setLayoutFree');
            editor.updateElement({
              ...replacedImage,
              x: replacedImage.x + 18,
              y: replacedImage.y + 16,
              w: replacedImage.w + 28,
              h: replacedImage.h + 14,
              style: {
                ...replacedImage.style,
                stroke: 'rgb(31, 138, 112)',
                strokeWidth: 5,
                radius: 14
              }
            });

            const module = editor.selectHTML(fixture.moduleSelector);
            assert(module, 'Could not select movable module', { fixture: fixture.name, selector: fixture.moduleSelector });
            editor.command('setLayoutTransform');
            editor.command('nudgeRightBig');
            editor.command('nudgeDown');
            const nudgedModule = editor.getSelection();
            editor.updateElement({
              ...nudgedModule,
              x: nudgedModule.x + fixture.moduleMove.x,
              y: nudgedModule.y + fixture.moduleMove.y,
              w: Math.max(96, nudgedModule.w + fixture.moduleResize.w),
              h: Math.max(56, nudgedModule.h + fixture.moduleResize.h),
              style: {
                ...nudgedModule.style,
                fill: 'rgb(250, 250, 210)',
                stroke: 'rgb(12, 34, 56)',
                strokeWidth: 2,
                radius: 12
              }
            });

            const tableCell = editor.selectHTML(fixture.tableSelector);
            assert(tableCell && ['td', 'th'].includes(tableCell.tagName), 'Could not select table cell', { fixture: fixture.name, tableCell });
            editor.setSelectedHTMLText('Chiselo 表格已修改');
            editor.command('tableAddRowAfter');
            editor.setSelectedHTMLText('Chiselo 新增行');
            editor.command('cellAlignCenter');
            editor.command('cellStyleSoft');

            const exported = editor.exportHTML();
            const after = editor.getHTMLSummary();
            const assertions = {
              titleEdited: exported.includes(fixture.editedTitle),
              imageReplaced: exported.includes(replacementBase64),
              moduleRestyled: exported.includes('rgb(12, 34, 56)') && exported.includes('rgb(250, 250, 210)'),
              tableEdited: exported.includes('Chiselo 表格已修改') && exported.includes('Chiselo 新增行'),
              cleanExport: !exported.includes('data-chiselo'),
              exportedStillHTML: exported.includes('<html') && exported.includes('</html>')
            };
            const failed = Object.entries(assertions).filter(([, value]) => !value);
            assert(failed.length === 0, 'HTML fixture assertions failed', { fixture: fixture.name, failed, assertions });

            htmlOutputs.push({
              name: fixture.name,
              outputName: fixture.outputName,
              before,
              after,
              assertions,
              exported
            });
          }

          editor.loadDeckFromBase64(payload.deck.base64);
          await sleep(80);

          editor.selectSlide(0);
          const deckTitle = editor.selectElementById('s01-title');
          assert(deckTitle && deckTitle.type === 'text', 'Could not select deck title', { deckTitle });
          editor.updateElement({
            ...deckTitle,
            x: deckTitle.x + 18,
            y: deckTitle.y + 12,
            text: 'Chiselo 已修改 Deck 标题',
            style: {
              ...deckTitle.style,
              color: '#0f766e',
              fontSize: 60
            }
          });

          const deckImage = editor.selectElementById('s01-visual');
          assert(deckImage && deckImage.type === 'image', 'Could not select deck image', { deckImage });
          editor.updateElement({
            ...deckImage,
            x: deckImage.x - 22,
            y: deckImage.y + 20,
            w: deckImage.w + 24,
            h: deckImage.h + 12,
            imageSource: `data:image/svg+xml;base64,${replacementBase64}`,
            imageAlt: 'Replaced by generated fixtures editing test',
            style: {
              ...deckImage.style,
              stroke: '#dc2626',
              strokeWidth: 5,
              radius: 16
            }
          });

          editor.selectSlide(1);
          const deckCard = editor.selectElementById('s02-card-1');
          assert(deckCard && deckCard.type === 'rect', 'Could not select deck card', { deckCard });
          const deckCardOriginal = { x: deckCard.x, y: deckCard.y };
          editor.command('nudgeRightBig');
          editor.command('nudgeDown');
          const deckCardNudged = editor.getSelection();
          editor.updateElement({
            ...deckCardNudged,
            w: deckCardNudged.w + 26,
            h: deckCardNudged.h + 18,
            style: {
              ...deckCardNudged.style,
              fill: '#fff7ed',
              stroke: '#ea580c',
              strokeWidth: 3,
              radius: 18
            }
          });

          const deckText = editor.selectElementById('s02-text-1');
          assert(deckText && deckText.type === 'text', 'Could not select deck text', { deckText });
          editor.updateElement({
            ...deckText,
            text: 'HTML 页面\\n已移动模块并重写文本。',
            style: {
              ...deckText.style,
              color: '#ea580c'
            }
          });

          const duplicateSource = editor.selectElementById('s02-card-2');
          assert(duplicateSource, 'Could not select deck duplicate source', { duplicateSource });
          editor.command('duplicate');
          const duplicate = editor.getSelection();
          assert(duplicate && duplicate.id !== duplicateSource.id && duplicate.x === duplicateSource.x + 18, 'Deck duplicate did not offset selection', { duplicateSource, duplicate });
          editor.command('delete');
          const deckAfterDelete = editor.getDeck();
          assert(!deckAfterDelete.slides.flatMap((slide) => slide.elements).some((element) => element.id === duplicate.id), 'Deck delete did not remove duplicate', { duplicate });

          editor.selectSlide(8);
          const deckMetric = editor.selectElementById('s09-metric-3');
          assert(deckMetric && deckMetric.type === 'text', 'Could not select deck metric', { deckMetric });
          editor.updateElement({
            ...deckMetric,
            text: 'OK\\nobjects',
            style: {
              ...deckMetric.style,
              color: '#0f766e'
            }
          });

          const editedDeck = editor.getDeck();
          const deckHTML = editor.exportHTML();
          const allElements = editedDeck.slides.flatMap((slide) => slide.elements);
          const deckAssertions = {
            slideCount: editedDeck.slides.length === 10,
            titleEdited: allElements.some((element) => element.id === 's01-title' && element.text === 'Chiselo 已修改 Deck 标题'),
            imageReplaced: allElements.some((element) => element.id === 's01-visual' && element.imageSource && element.imageSource.includes(replacementBase64)),
            cardMoved: allElements.some((element) => element.id === 's02-card-1' && element.x === deckCardOriginal.x + 10 && element.y === deckCardOriginal.y + 1),
            textEdited: allElements.some((element) => element.id === 's02-text-1' && element.text.includes('已移动模块')),
            duplicateDeleted: !allElements.some((element) => element.id === duplicate.id),
            metricEdited: allElements.some((element) => element.id === 's09-metric-3' && element.text === 'OK\\nobjects'),
            htmlExported: deckHTML.includes('Chiselo 已修改 Deck 标题') && deckHTML.includes(replacementBase64)
          };
          const deckFailed = Object.entries(deckAssertions).filter(([, value]) => !value);
          assert(deckFailed.length === 0, 'Deck assertions failed', { deckFailed, deckAssertions });

          window.webkit.messageHandlers.generatedFixtures.postMessage({
            type: 'result',
            htmlOutputs,
            deckOutputName: payload.deck.outputName,
            deckHTMLOutputName: payload.deck.htmlOutputName,
            deckJSON: JSON.stringify(editedDeck, null, 2),
            deckHTML,
            deckAssertions
          });
        })().catch(error => {
          window.webkit.messageHandlers.generatedFixtures.postMessage({
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
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "generatedFixtures",
              let body = message.body as? [String: Any] else {
            return
        }

        if body["type"] as? String == "error" {
            let message = body["message"] as? String ?? "Unknown generated fixture failure."
            let stack = body["stack"] as? String ?? ""
            fail(message + "\n" + stack)
        }

        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

            guard let htmlOutputs = body["htmlOutputs"] as? [[String: Any]] else {
                fail("Result did not include HTML outputs.")
            }

            var reportHTML: [[String: Any]] = []
            for output in htmlOutputs {
                guard let outputName = output["outputName"] as? String,
                      let exported = output["exported"] as? String else {
                    fail("HTML output was missing outputName/exported.")
                }

                let url = outputDirectory.appendingPathComponent(outputName)
                try exported.write(to: url, atomically: true, encoding: .utf8)

                var summary = output
                summary.removeValue(forKey: "exported")
                summary["path"] = url.path
                reportHTML.append(summary)
            }

            guard let deckOutputName = body["deckOutputName"] as? String,
                  let deckHTMLOutputName = body["deckHTMLOutputName"] as? String,
                  let deckJSON = body["deckJSON"] as? String,
                  let deckHTML = body["deckHTML"] as? String else {
                fail("Result did not include deck outputs.")
            }

            let deckURL = outputDirectory.appendingPathComponent(deckOutputName)
            let deckHTMLURL = outputDirectory.appendingPathComponent(deckHTMLOutputName)
            try deckJSON.write(to: deckURL, atomically: true, encoding: .utf8)
            try deckHTML.write(to: deckHTMLURL, atomically: true, encoding: .utf8)

            let report: [String: Any] = [
                "type": "result",
                "html": reportHTML,
                "deck": [
                    "path": deckURL.path,
                    "htmlPath": deckHTMLURL.path,
                    "assertions": body["deckAssertions"] ?? [:]
                ]
            ]

            let reportData = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            let reportURL = outputDirectory.appendingPathComponent("generated-fixtures-editing-report.json")
            try reportData.write(to: reportURL)

            print(String(data: reportData, encoding: .utf8) ?? "{}")
            print("Wrote report: \(reportURL.path)")
            exit(0)
        } catch {
            fail("Could not write generated fixture outputs: \(error.localizedDescription)")
        }
    }

    private func fail(_ message: String) -> Never {
        fputs("Generated fixtures editing test failed: \(message)\n", stderr)
        exit(1)
    }
}

private func payloadJSON(projectRoot: URL) throws -> String {
    let htmlFixtures: [[String: Any]] = [
        [
            "name": "operations-dashboard",
            "path": "examples/test-html-pages/01-operations-dashboard.html",
            "outputName": "01-operations-dashboard-edited.html",
            "editedTitle": "Chiselo 已修改：运营交付仪表盘",
            "moduleSelector": ".metric:nth-child(2)",
            "tableSelector": "table tbody tr:first-child td:last-child",
            "titleMove": ["x": 18, "y": 10],
            "titleFontDelta": 2,
            "moduleMove": ["x": 22, "y": 14],
            "moduleResize": ["w": 18, "h": 10]
        ],
        [
            "name": "editorial-brief",
            "path": "examples/test-html-pages/02-editorial-brief.html",
            "outputName": "02-editorial-brief-edited.html",
            "editedTitle": "Chiselo 已修改：图文简报",
            "moduleSelector": ".sidebox",
            "tableSelector": "table tbody tr:first-child td:last-child",
            "titleMove": ["x": 24, "y": 12],
            "titleFontDelta": -3,
            "moduleMove": ["x": -16, "y": 18],
            "moduleResize": ["w": 24, "h": 18]
        ],
        [
            "name": "delivery-form",
            "path": "examples/test-html-pages/03-delivery-form.html",
            "outputName": "03-delivery-form-edited.html",
            "editedTitle": "Chiselo 已修改：交付验收表",
            "moduleSelector": ".stamp",
            "tableSelector": "table tbody tr:first-child td:last-child",
            "titleMove": ["x": 16, "y": 8],
            "titleFontDelta": 4,
            "moduleMove": ["x": 18, "y": 18],
            "moduleResize": ["w": 20, "h": 12]
        ]
    ]

    var encodedHTMLFixtures: [[String: Any]] = []
    for fixture in htmlFixtures {
        guard let relativePath = fixture["path"] as? String else { continue }
        let url = projectRoot.appendingPathComponent(relativePath)
        let html = try String(contentsOf: url, encoding: .utf8)
        var next = fixture
        next["base64"] = Data(html.utf8).base64EncodedString()
        next["baseHref"] = url.deletingLastPathComponent().absoluteString
        encodedHTMLFixtures.append(next)
    }

    let deckURL = projectRoot.appendingPathComponent("examples/test-10-slide-deck.aislide")
    let deck = try String(contentsOf: deckURL, encoding: .utf8)
    let payload: [String: Any] = [
        "htmlFixtures": encodedHTMLFixtures,
        "deck": [
            "base64": Data(deck.utf8).base64EncodedString(),
            "outputName": "test-10-slide-deck-edited.aislide",
            "htmlOutputName": "test-10-slide-deck-edited.html"
        ]
    ]

    let data = try JSONSerialization.data(withJSONObject: payload, options: [])
    return String(data: data, encoding: .utf8) ?? "{}"
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = projectRoot
    .appendingPathComponent("Chiselo")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Editor")
    .appendingPathComponent("index.html")
let outputDirectory = projectRoot
    .appendingPathComponent("outputs", isDirectory: true)
    .appendingPathComponent("generated-fixture-edits", isDirectory: true)

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

do {
    let test = try GeneratedFixturesEditingTest(
        editorURL: editorURL,
        payloadJSON: payloadJSON(projectRoot: projectRoot),
        outputDirectory: outputDirectory
    )
    DispatchQueue.main.async {
        test.start()
    }
    app.run()
} catch {
    fputs("Could not prepare generated fixture editing test: \(error.localizedDescription)\n", stderr)
    exit(1)
}
