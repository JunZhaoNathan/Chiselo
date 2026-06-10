import AppKit
import Foundation
import WebKit

final class FiveSlideAcceptanceTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
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
                const tree = editor.getHTMLTree();
                const flatten = (nodes) => nodes.flatMap((node) => [node, ...flatten(node.children || [])]);
                const treeNodes = flatten(tree);
                const replacementSVG = '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360"><rect width="640" height="360" rx="32" fill="#0f766e"/><circle cx="128" cy="112" r="54" fill="#facc15"/><rect x="248" y="86" width="250" height="36" rx="18" fill="#ecfeff"/><rect x="248" y="150" width="320" height="28" rx="14" fill="#99f6e4"/><rect x="248" y="202" width="280" height="28" rx="14" fill="#5eead4"/><text x="64" y="306" font-family="Arial" font-size="38" font-weight="700" fill="#ffffff">Replaced by Chiselo</text></svg>';
                const replacementBase64 = btoa(replacementSVG);

                const h1 = editor.selectHTML('section.cover h1');
                if (!h1) throw new Error('Missing cover h1');
                editor.command('setLayoutTransform');
                editor.updateElement({
                  ...h1,
                  x: h1.x + 30,
                  y: h1.y + 12,
                  style: {
                    ...h1.style,
                    color: 'rgb(18, 59, 99)',
                    fontSize: 64,
                    lineHeight: 1.05
                  }
                });
                editor.setSelectedHTMLText('Chiselo 编辑验收：5 页 HTML Slides');

                const image = editor.selectHTML('img.demo-image');
                if (!image) throw new Error('Missing demo image');
                let replacedImage = editor.replaceSelectedImageFromBase64('image/svg+xml', replacementBase64);
                if (!replacedImage) throw new Error('Could not replace image');
                replacedImage = await editor.settleSelectedImage();
                if (!replacedImage) throw new Error('Replaced image did not settle');
                editor.command('setLayoutFree');
                editor.updateElement({
                  ...replacedImage,
                  x: replacedImage.x + 36,
                  y: replacedImage.y + 22,
                  w: replacedImage.w + 44,
                  h: replacedImage.h + 20,
                  style: {
                    ...replacedImage.style,
                    stroke: 'rgb(31, 138, 112)',
                    strokeWidth: 5,
                    radius: 14
                  }
                });
                editor.command('alignRight');
                editor.command('nudgeLeftBig');
                editor.command('snapToGrid');
                const alignedImage = editor.getSelection();
                editor.updateElement({
                  ...alignedImage,
                  x: image.x + 22,
                  y: image.y + 18,
                  w: image.w + 30,
                  h: image.h + 12
                });

                const imageStatus = editor.selectHTML('table.metrics-table tbody tr:nth-child(1) td:last-child');
                if (!imageStatus) throw new Error('Missing image status cell');
                editor.setSelectedHTMLText('图片已通过');

                const tableStatus = editor.selectHTML('table.metrics-table tbody tr:nth-child(2) td:last-child');
                if (!tableStatus) throw new Error('Missing table status cell');
                editor.setSelectedHTMLText('表格已通过');

                editor.command('tableAddRowAfter');
                editor.setSelectedHTMLText('新增行已通过');
                editor.command('tableAddColumnAfter');
                editor.setSelectedHTMLText('新增列已通过');
                editor.command('cellAlignCenter');
                editor.command('cellStyleSoft');
                editor.command('tableAddRowAfter');
                editor.setSelectedHTMLText('临时删除行');
                editor.command('tableDeleteRow');
                editor.command('tableAddColumnAfter');
                editor.setSelectedHTMLText('临时删除列');
                editor.command('tableDeleteColumn');

                const table = editor.selectHTML('table.metrics-table');
                if (!table) throw new Error('Missing metrics table');
                editor.command('setLayoutTransform');
                editor.updateElement({
                  ...table,
                  x: table.x + 24,
                  y: table.y - 18,
                  w: table.w + 42,
                  h: table.h,
                  style: {
                    ...table.style,
                    fill: 'rgb(255, 255, 255)',
                    stroke: 'rgb(183, 121, 31)',
                    strokeWidth: 3,
                    radius: 10
                  }
                });
                editor.command('alignCenter');
                editor.command('snapToGrid');
                editor.command('duplicate');
                const duplicateTable = editor.getSelection();
                if (!duplicateTable || duplicateTable.tagName !== 'table') {
                  throw new Error('Table duplicate command failed');
                }
                editor.command('delete');
                const finalTable = editor.selectHTML('table.metrics-table');
                editor.updateElement({
                  ...finalTable,
                  x: finalTable.x + 16,
                  y: finalTable.y + 96,
                  w: finalTable.w - 36,
                  h: finalTable.h - 26
                });

                const workflowCard = editor.selectHTML('.workflow-grid .workflow-card:nth-child(1)');
                if (!workflowCard) throw new Error('Missing workflow card');
                editor.command('selectSameClass');
                const workflowGroup = editor.getSelection();
                if (!workflowGroup || workflowGroup.type !== 'html-group') {
                  throw new Error('Same-class multi-selection did not create a group');
                }
                editor.command('nudgeDownBig');
                editor.command('snapToGrid');
                editor.updateElement({
                  ...workflowGroup,
                  x: workflowGroup.x + 12,
                  w: workflowGroup.w + 16
                });
                editor.command('duplicate');
                const duplicateWorkflowGroup = editor.getSelection();
                if (!duplicateWorkflowGroup || duplicateWorkflowGroup.type !== 'html-group') {
                  throw new Error('Workflow group duplicate command failed');
                }
                editor.command('delete');

                const exported = editor.exportHTML();
                const after = editor.getHTMLSummary();
                const assertions = {
                  hasFiveSlides: (exported.match(/class="slide/g) || []).length >= 5,
                  hasImage: exported.includes('img class="demo-image"') && exported.includes('data:image/svg+xml;base64'),
                  hasTable: exported.includes('table class="metrics-table"'),
                  editedTitle: exported.includes('Chiselo 编辑验收：5 页 HTML Slides'),
                  imageReplaced: exported.includes('Replaced by Chiselo') || exported.includes(replacementBase64),
                  imageStatus: exported.includes('图片已通过'),
                  tableStatus: exported.includes('表格已通过'),
                  tableAddedRow: exported.includes('新增行已通过'),
                  tableAddedColumn: exported.includes('新增列已通过'),
                  tableDeletedRow: !exported.includes('临时删除行'),
                  tableDeletedColumn: !exported.includes('临时删除列'),
                  imageStyle: exported.includes('rgb(31, 138, 112)') && exported.includes('border-radius: 14px'),
                  tableStyle: exported.includes('rgb(183, 121, 31)'),
                  cellStyle: exported.includes('rgb(239, 246, 255)') && exported.includes('text-align: center'),
                  duplicateTableCommand: duplicateTable.tagName === 'table',
                  multiSelectGroup: workflowGroup.type === 'html-group' && workflowGroup.text.includes('4'),
                  duplicateWorkflowCommand: duplicateWorkflowGroup.type === 'html-group',
                  cleanExport: !exported.includes('data-chiselo'),
                  treeHasImage: treeNodes.some((node) => node.tagName === 'img'),
                  treeHasTable: treeNodes.some((node) => node.tagName === 'table')
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
                  treeCount: treeNodes.length,
                  duplicateTable,
                  duplicateWorkflowGroup,
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

    static func writeFallbackFixtureIfNeeded(to url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try fallbackFixtureHTML.write(to: url, atomically: true, encoding: .utf8)
    }

    private static let fallbackFixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        html, body { margin: 0; background: #e5e7eb; font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif; }
        body { display: grid; justify-items: center; gap: 28px; padding: 28px; }
        .slide {
          position: relative;
          width: 1280px;
          height: 720px;
          overflow: hidden;
          background: #f8fafc;
          color: #172033;
          box-sizing: border-box;
          padding: 64px;
        }
        .cover { background: linear-gradient(135deg, #f8fafc 0%, #e0f2fe 56%, #ffffff 100%); }
        .cover h1 { margin: 0; width: 760px; font-size: 58px; line-height: 1.06; color: #123b63; }
        .cover p { width: 640px; font-size: 25px; line-height: 1.38; color: #475569; }
        .demo-image {
          position: absolute;
          right: 84px;
          top: 118px;
          width: 420px;
          height: 236px;
          object-fit: cover;
          border-radius: 20px;
          border: 3px solid #94a3b8;
          background: #ffffff;
        }
        .metrics-table {
          position: absolute;
          left: 84px;
          top: 388px;
          width: 760px;
          border-collapse: collapse;
          background: #ffffff;
          border-radius: 16px;
          overflow: hidden;
        }
        .metrics-table th, .metrics-table td {
          border: 1px solid #cbd5e1;
          padding: 14px 18px;
          font-size: 20px;
          line-height: 1.2;
          text-align: left;
        }
        .metrics-table th { background: #dbeafe; font-weight: 800; }
        .workflow-grid {
          position: absolute;
          left: 84px;
          right: 84px;
          bottom: 64px;
          display: grid;
          grid-template-columns: repeat(4, 1fr);
          gap: 20px;
        }
        .workflow-card {
          min-height: 118px;
          border-radius: 18px;
          background: #ffffff;
          border: 1px solid #cbd5e1;
          padding: 20px;
          box-shadow: 0 14px 34px rgba(15, 23, 42, 0.08);
          font-size: 21px;
          font-weight: 760;
        }
        h2 { margin: 0 0 22px; font-size: 46px; }
        .body-copy { width: 760px; font-size: 25px; line-height: 1.45; color: #475569; }
      </style>
    </head>
    <body>
      <section class="slide cover">
        <h1>Chiselo HTML Slides Acceptance</h1>
        <p>用于验证 HTML 主资产的文字、图片、表格、布局、多选和导出链路。</p>
        <img class="demo-image" alt="Demo image" src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NDAiIGhlaWdodD0iMzYwIiB2aWV3Qm94PSIwIDAgNjQwIDM2MCI+PHJlY3Qgd2lkdGg9IjY0MCIgaGVpZ2h0PSIzNjAiIHJ4PSIzMiIgZmlsbD0iI2RiZWFmZSIvPjxjaXJjbGUgY3g9IjE0MCIgY3k9IjEyMCIgcj0iNjQiIGZpbGw9IiMwYTg0ZmYiLz48dGV4dCB4PSI2NCIgeT0iMzAwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMzYiIGZvbnQtd2VpZ2h0PSI3MDAiIGZpbGw9IiMxNzIwMzMiPk9yaWdpbmFsIEltYWdlPC90ZXh0Pjwvc3ZnPg==">
        <table class="metrics-table">
          <thead><tr><th>对象</th><th>状态</th></tr></thead>
          <tbody>
            <tr><td>图片替换</td><td>等待验证</td></tr>
            <tr><td>表格编辑</td><td>等待验证</td></tr>
          </tbody>
        </table>
      </section>
      <section class="slide">
        <h2>Workflow</h2>
        <p class="body-copy">这些卡片用于验证同类对象选择、组移动、复制、删除和干净 HTML 导出。</p>
        <div class="workflow-grid">
          <div class="workflow-card">打开 HTML</div>
          <div class="workflow-card">点选元素</div>
          <div class="workflow-card">调整布局</div>
          <div class="workflow-card">导出交付</div>
        </div>
      </section>
      <section class="slide"><h2>Typography</h2><p class="body-copy">文字编辑、字号、颜色、行高和导出清理需要稳定工作。</p></section>
      <section class="slide"><h2>Tables</h2><p class="body-copy">表格行列增删、单元格样式和内容替换需要稳定工作。</p></section>
      <section class="slide"><h2>Delivery</h2><p class="body-copy">最终 HTML 不应包含 Chiselo 临时属性，并能继续导出 PDF/PPTX。</p></section>
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

let outputsRoot = projectRoot.appendingPathComponent("outputs", isDirectory: true)
try? FileManager.default.createDirectory(at: outputsRoot, withIntermediateDirectories: true)

let defaultInput = outputsRoot.appendingPathComponent("chiselo-five-slide-demo.html").path
let defaultOutput = outputsRoot.appendingPathComponent("chiselo-five-slide-demo-edited.html").path
let inputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? defaultInput)
let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().dropFirst().first ?? defaultOutput)

if CommandLine.arguments.dropFirst().first == nil {
    do {
        try FiveSlideAcceptanceTest.writeFallbackFixtureIfNeeded(to: inputURL)
    } catch {
        fputs("Acceptance test failed: could not write fallback fixture: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let test = FiveSlideAcceptanceTest(editorURL: editorURL, inputURL: inputURL, outputURL: outputURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
