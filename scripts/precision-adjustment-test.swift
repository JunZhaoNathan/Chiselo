import AppKit
import Foundation
import WebKit

final class PrecisionAdjustmentTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let outputURL: URL
    private let reportURL: URL
    private var webView: WKWebView?

    init(editorURL: URL, outputURL: URL) {
        self.editorURL = editorURL
        self.outputURL = outputURL
        self.reportURL = outputURL
            .deletingLastPathComponent()
            .appendingPathComponent("precision-adjustment-report.json")
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "precision")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1440, height: 940), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        do {
            let html = precisionFixtureHTML
            guard let data = html.data(using: .utf8) else {
                fail("Could not encode precision fixture.")
            }

            let base64 = data.base64EncodedString()
            let script = """
            void window.ChiseloEditor.openHTMLFromBase64('\(base64)', '')
              .then(() => {
                const editor = window.ChiseloEditor;
                const results = [];
                const tolerance = 1;

                const close = (actual, expected, tol = tolerance) => Math.abs(actual - expected) <= tol;
                const assertRect = (name, rect, expected, tol = tolerance) => {
                  const fields = ['x', 'y', 'w', 'h'];
                  const failures = fields
                    .filter((field) => expected[field] !== undefined)
                    .filter((field) => !close(rect[field], expected[field], tol))
                    .map((field) => ({ field, actual: rect[field], expected: expected[field], delta: Number((rect[field] - expected[field]).toFixed(3)) }));
                  results.push({ name, rect, expected, tolerance: tol, pass: failures.length === 0, failures });
                };
                const assertTrue = (name, pass, detail = {}) => {
                  results.push({ name, pass, ...detail });
                };
                const select = (selector) => {
                  const item = editor.selectHTML(selector);
                  if (!item) throw new Error(`Missing ${selector}`);
                  return item;
                };

                let box = select('#box');
                editor.command('setLayoutFree');
                editor.updateElement({ ...box, x: 321, y: 147, w: 233, h: 91 });
                assertRect('free absolute x/y/w/h', editor.getSelection(), { x: 321, y: 147, w: 233, h: 91 });

                editor.command('nudgeRightBig');
                editor.command('nudgeDown');
                assertRect('nudge 10px + 1px', editor.getSelection(), { x: 331, y: 148, w: 233, h: 91 });

                let align = select('#align');
                editor.command('setLayoutFree');
                editor.updateElement({ ...align, x: 80, y: 80, w: 180, h: 90 });
                editor.command('alignCenter');
                editor.command('alignMiddle');
                assertRect('align center/middle to slide', editor.getSelection(), { x: 640 - 90, y: 360 - 45, w: 180, h: 90 });

                let flow = select('#flow-title');
                editor.command('setLayoutTransform');
                editor.updateElement({ ...flow, x: flow.x + 37, y: flow.y + 19, w: flow.w + 24, h: flow.h + 8 });
                assertRect('transform move/resize flow element', editor.getSelection(), {
                  x: flow.x + 37,
                  y: flow.y + 19,
                  w: flow.w + 24,
                  h: flow.h + 8
                }, 2);

                let groupFirst = select('#g1');
                editor.command('setLayoutFree');
                editor.command('selectSameClass');
                const group = editor.getSelection();
                if (!group || group.type !== 'html-group') throw new Error('Group selection failed');
                editor.updateElement({ ...group, x: 720, y: 420, w: 360, h: 150 });
                assertRect('multi-select group boundary', editor.getSelection(), { x: 720, y: 420, w: 360, h: 150 }, 1);

                const scaledG1 = select('#g1');
                const scaledG2 = select('#g2');
                const scaledG3 = select('#g3');
                const childChecks = [
                  { name: 'group child g1 remains inside', rect: scaledG1 },
                  { name: 'group child g2 remains inside', rect: scaledG2 },
                  { name: 'group child g3 remains inside', rect: scaledG3 }
                ].map((item) => ({
                  name: item.name,
                  rect: item.rect,
                  pass: item.rect.x >= 719 && item.rect.y >= 419 && item.rect.x + item.rect.w <= 1081 && item.rect.y + item.rect.h <= 571
                }));
                results.push(...childChecks);

                const reference = select('#g1');
                editor.command('selectSameClass');
                editor.command('matchWidth');
                editor.command('matchHeight');
                editor.command('distributeHorizontal');
                const horizontalG1 = select('#g1');
                const horizontalG2 = select('#g2');
                const horizontalG3 = select('#g3');
                const horizontalGap12 = Math.round(horizontalG2.x - (horizontalG1.x + horizontalG1.w));
                const horizontalGap23 = Math.round(horizontalG3.x - (horizontalG2.x + horizontalG2.w));
                assertTrue('multi-select match width/height', close(horizontalG1.w, reference.w) && close(horizontalG2.w, reference.w) && close(horizontalG3.w, reference.w) && close(horizontalG1.h, reference.h) && close(horizontalG2.h, reference.h) && close(horizontalG3.h, reference.h), {
                  rects: [horizontalG1, horizontalG2, horizontalG3],
                  reference: { w: reference.w, h: reference.h }
                });
                assertTrue('multi-select distribute horizontal gaps', close(horizontalGap12, horizontalGap23), {
                  gaps: [horizontalGap12, horizontalGap23]
                });

                select('#g1');
                editor.command('selectSameClass');
                editor.command('distributeVertical');
                const verticalG1 = select('#g1');
                const verticalG2 = select('#g2');
                const verticalG3 = select('#g3');
                const verticalOrdered = [verticalG1, verticalG2, verticalG3].sort((a, b) => a.y - b.y);
                const verticalGap12 = Math.round(verticalOrdered[1].y - (verticalOrdered[0].y + verticalOrdered[0].h));
                const verticalGap23 = Math.round(verticalOrdered[2].y - (verticalOrdered[1].y + verticalOrdered[1].h));
                assertTrue('multi-select distribute vertical gaps', close(verticalGap12, verticalGap23), {
                  gaps: [verticalGap12, verticalGap23]
                });

                const exported = editor.exportHTML();
                const failed = results.filter((item) => !item.pass);
                if (failed.length) {
                  throw new Error(JSON.stringify({ failed, results }));
                }

                window.webkit.messageHandlers.precision.postMessage({
                  type: 'result',
                  results,
                  exported
                });
              })
              .catch(error => {
                window.webkit.messageHandlers.precision.postMessage({
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
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "precision", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown JavaScript error.")
        }

        if let exported = body["exported"] as? String {
            do {
                try exported.write(to: outputURL, atomically: true, encoding: .utf8)
            } catch {
                fail("Could not write precision output HTML: \(error.localizedDescription)")
            }
        }

        var summary = body
        summary.removeValue(forKey: "exported")

        if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) {
            do {
                try data.write(to: reportURL)
            } catch {
                fail("Could not write precision report: \(error.localizedDescription)")
            }
            print(output)
            print("Wrote: \(outputURL.path)")
            print("Report: \(reportURL.path)")
            exit(0)
        }

        fail("Could not serialize precision result.")
    }

    private func fail(_ message: String) -> Never {
        fputs("Precision test failed: \(message)\n", stderr)
        exit(1)
    }
}

private let precisionFixtureHTML = """
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <title>Chiselo Precision Fixture</title>
  <style>
    * { box-sizing: border-box; }
    html, body { margin: 0; padding: 0; background: #e5e7eb; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
    body { display: grid; justify-items: center; padding: 0; }
    .slide { position: relative; width: 1280px; height: 720px; overflow: hidden; background: #f8fafc; }
    .target { position: absolute; border-radius: 8px; color: #fff; display: grid; place-items: center; font-weight: 800; }
    #box { left: 100px; top: 120px; width: 140px; height: 90px; background: #6d50b4; }
    #align { left: 940px; top: 90px; width: 160px; height: 80px; background: #c62828; }
    .flow-panel { position: absolute; left: 80px; top: 300px; width: 520px; padding: 28px; background: #fff; border: 1px solid #ded5ee; border-radius: 18px; }
    #flow-title { margin: 0; width: 360px; font-size: 34px; line-height: 1.12; color: #15151b; }
    .group-stage { position: absolute; left: 720px; top: 270px; width: 360px; height: 140px; }
    .group-item { position: absolute; top: 0; width: 90px; height: 70px; border-radius: 12px; background: #ffc107; display: grid; place-items: center; font-weight: 900; }
    #g1 { left: 0; }
    #g2 { left: 130px; top: 35px; width: 114px; height: 82px; }
    #g3 { left: 260px; top: 70px; width: 74px; height: 64px; }
  </style>
</head>
<body>
  <section class="slide">
    <div id="box" class="target">BOX</div>
    <div id="align" class="target">ALIGN</div>
    <article class="flow-panel">
      <h2 id="flow-title">Flow text target</h2>
    </article>
    <div class="group-stage">
      <div id="g1" class="group-item">1</div>
      <div id="g2" class="group-item">2</div>
      <div id="g3" class="group-item">3</div>
    </div>
  </section>
</body>
</html>
"""

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = projectRoot
    .appendingPathComponent("Chiselo")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Editor")
    .appendingPathComponent("index.html")

let outputsRoot = projectRoot.appendingPathComponent("outputs", isDirectory: true)
try? FileManager.default.createDirectory(at: outputsRoot, withIntermediateDirectories: true)

let defaultOutput = outputsRoot.appendingPathComponent("precision-adjustment-edited.html").path
let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? defaultOutput)

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let test = PrecisionAdjustmentTest(editorURL: editorURL, outputURL: outputURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
