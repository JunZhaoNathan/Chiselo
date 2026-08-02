import AppKit
import Foundation
import WebKit

final class DirectHTMLLocalStylesheetSaveTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let fixtureDirectory: URL
    private let htmlURL: URL
    private let cssURL: URL
    private let safeFileHistory = SafeFileHistory()
    private var webView: WKWebView?

    init(editorURL: URL, fixtureDirectory: URL, htmlURL: URL, cssURL: URL) {
        self.editorURL = editorURL
        self.fixtureDirectory = fixtureDirectory
        self.htmlURL = htmlURL
        self.cssURL = cssURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "localStylesheetSave")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 920), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
            self?.fail("Timed out waiting for local stylesheet save result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        do {
            let rawHTML = try String(contentsOf: htmlURL, encoding: .utf8)
            let html = injectLocalStylesheetMirrors(into: rawHTML, relativeTo: htmlURL)
            guard let data = html.data(using: .utf8) else {
                fail("Could not encode HTML as UTF-8.")
            }

            let base64 = data.base64EncodedString()
            let baseHref = fixtureDirectory.absoluteString
            let baseLiteral = try jsStringLiteral(baseHref)
            let script = """
            void window.ChiseloEditor.openHTMLFromBase64('\(base64)', \(baseLiteral))
              .then(async () => {
                const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
                await sleep(220);
                const editor = window.ChiseloEditor;
                const selected = editor.selectHTML('.hero-title');
                if (!selected) throw new Error('Could not select .hero-title');
                if (selected.style?.writebackKind !== 'stylesheet-rule') {
                  const fetchDebug = [];
                  for (const sheet of document.querySelector('iframe.html-frame').contentDocument.styleSheets) {
                    if (!sheet.href) continue;
                    try {
                      const response = await fetch(sheet.href);
                      const text = await response.text();
                      fetchDebug.push({ href: sheet.href, ok: response.ok, sample: text.slice(0, 80) });
                    } catch (error) {
                      fetchDebug.push({ href: sheet.href, error: String(error) });
                    }
                  }
                  const styleSheets = [...document.querySelector('iframe.html-frame').contentDocument.styleSheets].map((sheet) => ({
                    href: sheet.href || '',
                    ownerTag: sheet.ownerNode && sheet.ownerNode.tagName,
                    ruleCount: (() => {
                      try { return (sheet.cssRules || []).length; } catch { return -1; }
                    })(),
                    selectors: (() => {
                      try { return [...(sheet.cssRules || [])].map((rule) => rule.selectorText || rule.cssText || '').slice(0, 6); } catch { return []; }
                    })()
                  }));
                  throw new Error(`Expected stylesheet-rule writeback, got ${JSON.stringify(selected.style)} stylesheets=${JSON.stringify(styleSheets)} fetch=${JSON.stringify(fetchDebug)}`);
                }
                if (!String(selected.style?.writebackDetail || '').includes('styles/site.css')) {
                  throw new Error(`Expected writeback detail to mention styles/site.css, got ${selected.style?.writebackDetail}`);
                }
                if (selected.style?.writebackSourceKind !== 'linked-local'
                  || !String(selected.style?.writebackSourceLabel || '').includes('styles/site.css')
                  || !String(selected.style?.writebackSourceURL || '').startsWith('file://')
                  || !String(selected.style?.writebackRuleSnippet || '').includes('.hero-title')
                  || Number(selected.style?.writebackRuleLine || 0) < 1) {
                  throw new Error(`Missing structured writeback metadata: ${JSON.stringify(selected.style)}`);
                }

                editor.updateElement({
                  ...selected,
                  style: {
                    color: 'rgb(190, 40, 60)'
                  }
                });
                await sleep(80);

                const payload = editor.exportHTMLSavePayload();
                window.webkit.messageHandlers.localStylesheetSave.postMessage(payload);
              })
              .catch(error => {
                window.webkit.messageHandlers.localStylesheetSave.postMessage({
                  type: 'error',
                  message: error.message || String(error)
                });
              });
            """

            webView.evaluateJavaScript(script, completionHandler: nil)
        } catch {
            fail("Could not prepare fixture HTML: \(error.localizedDescription)")
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "localStylesheetSave",
              let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown JavaScript error.")
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            let payload = try JSONDecoder().decode(HTMLDocumentSavePayload.self, from: data)
            let persistence = try persistHTMLDocumentSavePayload(payload, to: htmlURL, safeFileHistory: safeFileHistory)

            let css = try String(contentsOf: cssURL, encoding: .utf8)
            let html = try String(contentsOf: htmlURL, encoding: .utf8)
            let cssBackup = cssURL.deletingPathExtension().appendingPathExtension("chiselo-backup").appendingPathExtension("css")

            guard css.contains("rgb(190, 40, 60)"),
                  html.contains("styles/site.css"),
                  !html.contains("rgb(190, 40, 60)"),
                  persistence.stylesheetWritebacks.count == 1,
                  persistence.stylesheetWritebacks.first?.snapshotURL != nil,
                  FileManager.default.fileExists(atPath: cssBackup.path) else {
                fail("Persisted HTML/CSS did not match expectations. css=\(css) html=\(html) writebacks=\(persistence.stylesheetWritebacks)")
            }

            let result: [String: Any] = [
                "type": "result",
                "htmlSaved": true,
                "cssSaved": true,
                "stylesheetWritebacks": persistence.stylesheetWritebacks.count,
                "cssSnapshot": persistence.stylesheetWritebacks.first?.snapshotURL?.lastPathComponent ?? "",
                "cssBackup": cssBackup.lastPathComponent
            ]
            if let output = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]),
               let string = String(data: output, encoding: .utf8) {
                print(string)
                exit(0)
            }

            fail("Could not serialize local stylesheet save result.")
        } catch {
            fail("Local stylesheet save test failed: \(error.localizedDescription)")
        }
    }

    private func jsStringLiteral(_ string: String) throws -> String {
        let data = try JSONEncoder().encode(string)
        return String(data: data, encoding: .utf8) ?? "\"\""
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML local stylesheet save test failed: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct DirectHTMLLocalStylesheetSaveRunner {
    static func main() throws {
        let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let editorURL = projectRoot
            .appendingPathComponent("Chiselo")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Editor")
            .appendingPathComponent("index.html")

        let fixtureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chiselo-local-stylesheet-save-\(UUID().uuidString)", isDirectory: true)
        let stylesDirectory = fixtureDirectory.appendingPathComponent("styles", isDirectory: true)
        try FileManager.default.createDirectory(at: stylesDirectory, withIntermediateDirectories: true, attributes: nil)

        let htmlURL = fixtureDirectory.appendingPathComponent("index.html")
        let cssURL = stylesDirectory.appendingPathComponent("site.css")

        let html = """
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <title>Local Stylesheet Save Fixture</title>
          <link rel="stylesheet" href="styles/site.css">
        </head>
        <body>
          <main class="hero">
            <h1 class="hero-title">Local stylesheet title</h1>
            <p class="hero-copy">Write back to linked CSS.</p>
          </main>
        </body>
        </html>
        """

        let css = """
        .hero-title {
          color: rgb(10, 20, 30);
          font-size: 42px;
        }

        .hero-copy {
          color: rgb(80, 90, 100);
        }
        """

        try html.write(to: htmlURL, atomically: true, encoding: .utf8)
        try css.write(to: cssURL, atomically: true, encoding: .utf8)

        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let test = DirectHTMLLocalStylesheetSaveTest(
            editorURL: editorURL,
            fixtureDirectory: fixtureDirectory,
            htmlURL: htmlURL,
            cssURL: cssURL
        )
        DispatchQueue.main.async {
            test.start()
        }

        app.run()
    }
}
