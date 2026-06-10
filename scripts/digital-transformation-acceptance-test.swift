import AppKit
import Foundation
import WebKit

final class DigitalTransformationAcceptanceTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let inputURL: URL
    private let outputURL: URL
    private var webView: WKWebView?

    init(editorURL: URL, inputURL: URL, outputURL: URL) {
        self.editorURL = editorURL
        self.inputURL = inputURL
        self.outputURL = outputURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "acceptance")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1440, height: 940), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        do {
            let html = try String(contentsOf: inputURL, encoding: .utf8)
            guard let data = html.data(using: .utf8) else {
                fail("Could not encode input HTML.")
            }

            let base64 = data.base64EncodedString()
            let baseHref = inputURL.deletingLastPathComponent().absoluteString
            let baseLiteral = try jsStringLiteral(baseHref)
            let script = """
            void window.ChiseloEditor.openHTMLFromBase64('\(base64)', \(baseLiteral))
              .then(async () => {
                const editor = window.ChiseloEditor;
                const before = editor.getHTMLSummary();
                const visualSVG = '<svg xmlns="http://www.w3.org/2000/svg" width="960" height="540" viewBox="0 0 960 540"><rect width="960" height="540" rx="42" fill="#4b3b78"/><rect x="88" y="82" width="260" height="112" rx="28" fill="#ffffff"/><rect x="398" y="82" width="474" height="112" rx="28" fill="#f5efff"/><rect x="88" y="254" width="374" height="154" rx="28" fill="#ffc107"/><rect x="512" y="254" width="360" height="154" rx="28" fill="#c62828"/><text x="128" y="148" font-family="Arial" font-size="38" font-weight="800" fill="#15151b">Edited</text><text x="438" y="148" font-family="Arial" font-size="38" font-weight="800" fill="#15151b">by Chiselo</text><text x="128" y="342" font-family="Arial" font-size="34" font-weight="800" fill="#15151b">Digital Core</text><text x="552" y="342" font-family="Arial" font-size="34" font-weight="800" fill="#fff">AI Workflow</text></svg>';
                const visualBase64 = btoa(visualSVG);

                const title = editor.selectHTML('.hero-title');
                if (!title) throw new Error('Missing hero title');
                editor.command('setLayoutTransform');
                editor.setSelectedHTMLText('数字化转型路线图：调整版');
                const editedTitle = editor.getSelection();
                editor.updateElement({
                  ...editedTitle,
                  x: title.x + 8,
                  y: title.y + 4,
                  w: 720,
                  h: 170,
                  style: {
                    ...editedTitle.style,
                    color: 'rgb(75, 59, 120)',
                    fontSize: 60,
                    lineHeight: 1.05
                  }
                });

                const subtitle = editor.selectHTML('.subtitle');
                if (!subtitle) throw new Error('Missing subtitle');
                editor.updateElement({
                  ...subtitle,
                  y: subtitle.y + 56,
                  w: 650,
                  style: {
                    ...subtitle.style,
                    fontSize: 25,
                    lineHeight: 1.42
                  }
                });

                const pills = editor.selectHTML('.pill-row');
                if (!pills) throw new Error('Missing cover pill row');
                editor.command('setLayoutTransform');
                editor.updateElement({
                  ...pills,
                  y: pills.y + 42
                });

                const image = editor.selectHTML('img.hero-visual');
                if (!image) throw new Error('Missing hero visual');
                let replaced = editor.replaceSelectedImageFromBase64('image/svg+xml', visualBase64);
                if (!replaced) throw new Error('Image replacement failed');
                replaced = await editor.settleSelectedImage();
                if (!replaced) throw new Error('Replaced image did not settle');
                editor.command('setLayoutFree');
                editor.updateElement({
                  ...replaced,
                  x: 754,
                  y: 262,
                  w: 430,
                  h: 244,
                  style: {
                    ...replaced.style,
                    stroke: 'rgb(109, 80, 180)',
                    strokeWidth: 4,
                    radius: 28
                  }
                });

                const firstMetric = editor.selectHTML('.metric-card:nth-of-type(1)');
                if (!firstMetric) throw new Error('Missing metric card');
                editor.command('selectSameClass');
                const metricGroup = editor.getSelection();
                if (!metricGroup || metricGroup.type !== 'html-group') throw new Error('Metric group selection failed');
                editor.command('nudgeDownBig');
                editor.command('snapToGrid');
                editor.updateElement({
                  ...metricGroup,
                  x: metricGroup.x + 10,
                  w: metricGroup.w + 22
                });

                const tableStatus = editor.selectHTML('.roadmap-table tbody tr:nth-child(2) td:last-child');
                if (!tableStatus) throw new Error('Missing roadmap status cell');
                editor.setSelectedHTMLText('试点周期缩短 25%');
                editor.command('tableAddRowAfter');
                editor.setSelectedHTMLText('治理节奏月度复盘');
                editor.command('tableAddColumnAfter');
                editor.setSelectedHTMLText('负责人');
                editor.command('cellAlignCenter');
                editor.command('cellStyleHeader');

                const capability = editor.selectHTML('.capability-card:nth-of-type(1)');
                if (!capability) throw new Error('Missing capability card');
                editor.command('selectSameClass');
                const capabilityGroup = editor.getSelection();
                editor.command('duplicate');
                const duplicatedCapabilityGroup = editor.getSelection();

                const exported = editor.exportHTML();
                const after = editor.getHTMLSummary();
                const assertions = {
                  hasTenSlides: (exported.match(/class="slide/g) || []).length >= 10,
                  editedTitle: exported.includes('数字化转型路线图：调整版'),
                  imageReplaced: exported.includes('data:image/svg+xml;base64') && exported.includes(visualBase64),
                  imageStyled: exported.includes('rgb(109, 80, 180)') && exported.includes('border-radius: 28px'),
                  metricGroup: metricGroup.type === 'html-group' && /3/.test(metricGroup.text || ''),
                  tableEdited: exported.includes('试点周期缩短 25%') && exported.includes('治理节奏月度复盘') && exported.includes('负责人'),
                  cellStyled: exported.includes('font-weight: 700') && exported.includes('text-align: center'),
                  duplicatedCapability: (exported.match(/class="capability-card"/g) || []).length >= 8,
                  cleanExport: !exported.includes('data-chiselo')
                };

                const failed = Object.entries(assertions).filter(([, value]) => !value);
                if (failed.length) {
                  throw new Error(JSON.stringify({ failed, assertions }));
                }

                window.webkit.messageHandlers.acceptance.postMessage({
                  type: 'result',
                  before,
                  after,
                  assertions,
                  metricGroup,
                  duplicatedCapabilityGroup,
                  exported
                });
              })
              .catch(error => {
                window.webkit.messageHandlers.acceptance.postMessage({
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
            fail("Could not run acceptance test: \(error.localizedDescription)")
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "acceptance", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown JavaScript error.")
        }

        guard let exported = body["exported"] as? String else {
            fail("No exported HTML returned.")
        }

        do {
            try exported.write(to: outputURL, atomically: true, encoding: .utf8)
        } catch {
            fail("Could not write output HTML: \(error.localizedDescription)")
        }

        var summary = body
        summary.removeValue(forKey: "exported")

        if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) {
            print(output)
            print("Wrote: \(outputURL.path)")
            exit(0)
        }

        fail("Could not serialize acceptance result.")
    }

    private func jsStringLiteral(_ string: String) throws -> String {
        let data = try JSONEncoder().encode(string)
        return String(data: data, encoding: .utf8) ?? "\"\""
    }

    private func fail(_ message: String) -> Never {
        fputs("Acceptance test failed: \(message)\n", stderr)
        exit(1)
    }
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = projectRoot
    .appendingPathComponent("Chiselo")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Editor")
    .appendingPathComponent("index.html")

let outputsRoot = projectRoot.appendingPathComponent("outputs", isDirectory: true)
try? FileManager.default.createDirectory(at: outputsRoot, withIntermediateDirectories: true)

let defaultInput = outputsRoot.appendingPathComponent("digital-transformation-10-slides.html").path
let defaultOutput = outputsRoot.appendingPathComponent("digital-transformation-10-slides-edited.html").path
let inputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? defaultInput)
let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().dropFirst().first ?? defaultOutput)

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let test = DigitalTransformationAcceptanceTest(editorURL: editorURL, inputURL: inputURL, outputURL: outputURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
