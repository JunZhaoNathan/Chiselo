import AppKit
import Foundation
import WebKit

final class PostdocLayoutAdjustmentTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let htmlURL: URL
    private let outputRoot: URL
    private let editedHTMLURL: URL
    private let frozenDeckURL: URL
    private let reportURL: URL
    private var webView: WKWebView?

    init(editorURL: URL, htmlURL: URL, outputRoot: URL) {
        self.editorURL = editorURL
        self.htmlURL = htmlURL
        self.outputRoot = outputRoot
        self.editedHTMLURL = outputRoot.appendingPathComponent("postdoc-layout-edited.html")
        self.frozenDeckURL = outputRoot.appendingPathComponent("postdoc-layout-frozen.aislide")
        self.reportURL = outputRoot.appendingPathComponent("postdoc-layout-review-report.json")
    }

    func start() {
        try? FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)

        let controller = WKUserContentController()
        controller.add(self, name: "postdoc")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1440, height: 1040), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())
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
                const editor = window.ChiseloEditor;
                const iframe = document.querySelector('iframe.html-frame');
                const doc = iframe && iframe.contentDocument;
                if (!doc) throw new Error('Direct HTML iframe is missing.');

                const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
                const select = (selector) => {
                  const item = editor.selectHTML(selector);
                  if (!item) throw new Error(`Missing selector: ${selector}`);
                  return item;
                };
                const rectOnly = (item) => ({
                  x: Math.round(item.x),
                  y: Math.round(item.y),
                  w: Math.round(item.w),
                  h: Math.round(item.h)
                });
                const change = (name, before, after) => ({
                  name,
                  before: rectOnly(before),
                  after: rectOnly(after),
                  delta: {
                    x: Math.round(after.x - before.x),
                    y: Math.round(after.y - before.y),
                    w: Math.round(after.w - before.w),
                    h: Math.round(after.h - before.h)
                  }
                });
                const toBase64Unicode = (value) => {
                  const bytes = new TextEncoder().encode(value);
                  let binary = '';
                  for (const byte of bytes) binary += String.fromCharCode(byte);
                  return btoa(binary);
                };

                const sheetCount = doc.querySelectorAll('.sheet, [data-page]').length;
                if (sheetCount < 2) throw new Error(`Expected 2 A4 sheets, got ${sheetCount}`);

                const beforeSummary = editor.getHTMLSummary();
                const beforeDiagnostics = editor.getImportDiagnostics();
                const adjustments = [];

                editor.command('setLayoutTransform');

                let title = select('.sheet[data-page="1"] h1');
                const titleBefore = { ...title };
                editor.updateElement({
                  ...title,
                  x: title.x + 8,
                  y: title.y,
                  w: title.w + 18,
                  h: title.h + 2
                });
                adjustments.push(change('第一页标题：右移 8px、略放宽，保留副标题空间', titleBefore, editor.getSelection()));

                let role = select('.sheet[data-page="1"] .role-emphasis');
                const roleBefore = { ...role };
                editor.updateElement({
                  ...role,
                  x: role.x,
                  y: role.y + 2,
                  w: role.w + 12,
                  h: role.h + 2,
                  style: { ...(role.style || {}), fontSize: Math.max(16.5, (role.style?.fontSize || 16) + 0.5) }
                });
                adjustments.push(change('第一页红色提示：下移并提高字号', roleBefore, editor.getSelection()));

                let stat = select('.sheet[data-page="1"] .stats .stat:nth-child(1)');
                editor.command('selectSameClass');
                const statGroup = editor.getSelection();
                if (!statGroup || statGroup.type !== 'html-group') throw new Error('Stats group selection failed.');
                const statBefore = { ...statGroup };
                editor.updateElement({
                  ...statGroup,
                  x: statGroup.x,
                  y: statGroup.y + 3,
                  w: statGroup.w,
                  h: statGroup.h
                });
                adjustments.push(change('第一页三张待遇卡片：成组选中并整体下移 3px', statBefore, editor.getSelection()));

                let contact = select('.sheet[data-page="2"] .contact');
                const contactBefore = { ...contact };
                editor.updateElement({
                  ...contact,
                  x: contact.x - 4,
                  y: contact.y - 10,
                  w: contact.w + 8,
                  h: contact.h
                });
                adjustments.push(change('第二页联系方式模块：上移并微调宽度', contactBefore, editor.getSelection()));

                await sleep(120);
                const exported = editor.exportHTML();
                const postEditDiagnostics = editor.getImportDiagnostics();

                const frozenDeck = await editor.importHTMLFromBase64(toBase64Unicode(exported), \(baseLiteral));
                const frozenPages = frozenDeck?.slides || [];
                const objectCounts = frozenPages.map((page) => page.elements.length);

                if (frozenPages.length !== 2) {
                  throw new Error(`Freeze layout expected 2 pages, got ${frozenPages.length}`);
                }
                if (!objectCounts.every((count) => count > 8)) {
                  throw new Error(`Freeze layout produced too few objects: ${objectCounts.join(', ')}`);
                }

                window.webkit.messageHandlers.postdoc.postMessage({
                  type: 'result',
                  exported,
                  frozenDeck: JSON.stringify(frozenDeck, null, 2),
                  report: {
                    input: '\(htmlURL.lastPathComponent)',
                    mode: 'Direct HTML + Editable Version',
                    sheetCount,
                    beforeSummary,
                    beforeDiagnostics,
                    postEditDiagnostics,
                    adjustments,
                    frozen: {
                      pageCount: frozenPages.length,
                      canvas: frozenDeck.canvas,
                      objectCounts,
                      titles: frozenPages.map((page) => page.title)
                    },
                    cleanExport: !exported.includes('data-chiselo'),
                    exportedLength: exported.length
                  }
                });
              })
              .catch(error => {
                window.webkit.messageHandlers.postdoc.postMessage({
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
        guard message.name == "postdoc", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown JavaScript error.")
        }

        do {
            if let exported = body["exported"] as? String {
                try exported.write(to: editedHTMLURL, atomically: true, encoding: .utf8)
            }

            if let frozenDeck = body["frozenDeck"] as? String {
                try frozenDeck.write(to: frozenDeckURL, atomically: true, encoding: .utf8)
            }

            guard let report = body["report"] as? [String: Any] else {
                fail("Missing report payload.")
            }

            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: reportURL)

            if let output = String(data: data, encoding: .utf8) {
                print(output)
            }
            print("Edited HTML: \(editedHTMLURL.path)")
            print("Frozen deck: \(frozenDeckURL.path)")
            print("Report: \(reportURL.path)")
            exit(0)
        } catch {
            fail("Could not write postdoc review artifacts: \(error.localizedDescription)")
        }
    }

    private func jsStringLiteral(_ string: String) throws -> String {
        let data = try JSONEncoder().encode(string)
        return String(data: data, encoding: .utf8) ?? "\"\""
    }

    private func fail(_ message: String) -> Never {
        fputs("Postdoc layout adjustment test failed: \(message)\n", stderr)
        exit(1)
    }
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = projectRoot
    .appendingPathComponent("Chiselo")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Editor")
    .appendingPathComponent("index.html")

guard let htmlPath = CommandLine.arguments.dropFirst().first else {
    fputs("Usage: swift scripts/postdoc-layout-adjustment-test.swift /path/to/postdoc.html [output-directory]\n", stderr)
    exit(2)
}

let defaultOutputRoot = projectRoot.appendingPathComponent("outputs").appendingPathComponent("postdoc-layout-review").path
let htmlURL = URL(fileURLWithPath: htmlPath)
let outputRoot = URL(fileURLWithPath: CommandLine.arguments.dropFirst().dropFirst().first ?? defaultOutputRoot)

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let test = PostdocLayoutAdjustmentTest(editorURL: editorURL, htmlURL: htmlURL, outputRoot: outputRoot)
test.start()
app.run()
