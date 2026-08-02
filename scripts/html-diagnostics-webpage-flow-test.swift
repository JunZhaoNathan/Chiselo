import AppKit
import Foundation
import WebKit

final class HTMLDiagnosticsWebpageFlowTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?
    private var latestDiagnostics: [String: Any]?
    private var didStart = false

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "chiselo")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 840), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.fail("Timed out waiting for webpage-flow diagnostics. latest=\(String(describing: self?.latestDiagnostics))")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.loadFixtureHTML()
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "chiselo",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String,
              type == "htmlTreeChanged" || type == "htmlDiagnosticsChanged",
              let diagnostics = body["diagnostics"] as? [String: Any] else {
            return
        }

        latestDiagnostics = diagnostics
        guard diagnosticsMatchExpected(diagnostics) else { return }

        let output: [String: Any] = [
            "type": "result",
            "messageType": type,
            "diagnostics": diagnostics
        ]

        if let data = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            print(string)
        }
        exit(0)
    }

    private func loadFixtureHTML() {
        guard !didStart else { return }
        didStart = true

        let base64 = Data(Self.fixtureHTML.utf8).base64EncodedString()
        let script = """
        void window.ChiseloEditor.openHTMLFromBase64('\(base64)', '')
          .then(() => {
            window.webkit.messageHandlers.chiselo.postMessage({
              type: 'htmlDiagnosticsChanged',
              diagnostics: window.ChiseloEditor.getImportDiagnostics()
            });
          })
          .catch(error => console.error(error));
        """

        webView?.evaluateJavaScript(script) { [weak self] _, error in
            if let error {
                self?.fail("Could not load fixture HTML: \(error.localizedDescription)")
            }
        }
    }

    private func diagnosticsMatchExpected(_ diagnostics: [String: Any]) -> Bool {
        let issues = diagnostics["issues"] as? [[String: Any]] ?? []
        let layoutIssueKinds = Set(["text-overflow", "out-of-bounds", "overlap"])
        let issueKinds = Set(issues.compactMap { $0["kind"] as? String })

        return bridgeInt(diagnostics["brokenImages"]) == 0 &&
            bridgeInt(diagnostics["brokenMedia"]) == 0 &&
            bridgeBool(diagnostics["cleanExport"]) == true &&
            bridgeInt(diagnostics["textOverflowCount"]) == 0 &&
            bridgeInt(diagnostics["outOfBoundsCount"]) == 0 &&
            bridgeInt(diagnostics["overlapCount"]) == 0 &&
            issueKinds.isDisjoint(with: layoutIssueKinds)
    }

    private func bridgeInt(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        default:
            return nil
        }
    }

    private func bridgeBool(_ value: Any?) -> Bool? {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        default:
            return nil
        }
    }

    private func fail(_ message: String) -> Never {
        fputs("HTML diagnostics webpage flow test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body {
          margin: 0;
          color: #172033;
          background: #f8fafc;
          font-family: -apple-system, BlinkMacSystemFont, sans-serif;
        }
        header {
          padding: 64px 56px 40px;
          background: #ffffff;
          border-bottom: 1px solid #dbe3ee;
        }
        main {
          max-width: 920px;
          margin: 0 auto;
          padding: 48px 32px 120px;
        }
        section {
          margin: 0 0 44px;
          padding: 28px;
          background: #ffffff;
          border: 1px solid #dbe3ee;
          border-radius: 18px;
        }
        h1 { margin: 0 0 12px; font-size: 52px; line-height: 1.05; }
        h2 { margin: 0 0 12px; font-size: 28px; }
        p { margin: 0 0 14px; font-size: 18px; line-height: 1.65; }
      </style>
    </head>
    <body>
      <header>
        <h1>Long Webpage Fixture</h1>
        <p>This is a normal scrolling webpage, not a fixed page, slide, poster, or clipped canvas.</p>
      </header>
      <main>
        <section><h2>Section 1</h2><p>Readable page content flows naturally inside the document and should never be treated as out of bounds just because it sits below the first viewport.</p></section>
        <section><h2>Section 2</h2><p>Paragraphs wrap normally and cards stack vertically. This layout is valid HTML page flow.</p></section>
        <section><h2>Section 3</h2><p>The diagnostic layer should stay quiet unless there is a concrete delivery risk.</p></section>
        <section><h2>Section 4</h2><p>More content pushes the document height beyond the iframe viewport, which is expected for a webpage.</p></section>
        <section><h2>Section 5</h2><p>These sections are intentionally below the fold to guard against viewport-based false positives.</p></section>
        <section><h2>Section 6</h2><p>Clean HTML export should remain clean after diagnostics run.</p></section>
        <section><h2>Section 7</h2><p>There are no clipped containers, no fixed slide frames, and no absolute overlap targets.</p></section>
      </main>
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

let test = HTMLDiagnosticsWebpageFlowTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
