import AppKit
import Foundation
import WebKit

final class HTMLDeliveryDiagnosticsTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
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
            self?.fail("Timed out waiting for delivery diagnostics. latest=\(String(describing: self?.latestDiagnostics))")
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
        let issueKinds = Set(issues.compactMap { $0["kind"] as? String })
        let hasElementTarget = issues.contains { issue in
            guard let elementId = issue["elementId"] as? String else { return false }
            return !elementId.isEmpty
        }

        return bridgeInt(diagnostics["brokenImages"]) == 1 &&
            (bridgeInt(diagnostics["svgCount"]) ?? 0) >= 1 &&
            bridgeInt(diagnostics["tableCount"]) == 1 &&
            bridgeInt(diagnostics["spanTableCount"]) == 1 &&
            bridgeBool(diagnostics["cleanExport"]) == true &&
            (bridgeInt(diagnostics["textOverflowCount"]) ?? 0) >= 1 &&
            (bridgeInt(diagnostics["outOfBoundsCount"]) ?? 0) >= 1 &&
            (bridgeInt(diagnostics["overlapCount"]) ?? 0) >= 1 &&
            (bridgeInt(diagnostics["pptxEffectRiskCount"]) ?? 0) >= 1 &&
            (bridgeInt(diagnostics["pptxTextObjectCount"]) ?? 0) >= 1 &&
            (bridgeInt(diagnostics["pptxImageObjectCount"]) ?? 0) >= 1 &&
            (bridgeInt(diagnostics["pptxReviewObjectCount"]) ?? 0) >= 1 &&
            bridgeInt(diagnostics["pptxFallbackObjectCount"]) == 0 &&
            hasBridgeString(diagnostics["pptxTextElementId"]) &&
            hasBridgeString(diagnostics["pptxImageElementId"]) &&
            hasBridgeString(diagnostics["pptxReviewElementId"]) &&
            bridgeString(diagnostics["pptxFallbackElementId"]) == nil &&
            (bridgeStringArray(diagnostics["pptxTextElementIds"])?.count ?? 0) >= 1 &&
            (bridgeStringArray(diagnostics["pptxImageElementIds"])?.count ?? 0) >= 1 &&
            (bridgeStringArray(diagnostics["pptxReviewElementIds"])?.count ?? 0) >= 3 &&
            (bridgeStringArray(diagnostics["pptxFallbackElementIds"])?.count ?? 0) == 0 &&
            issueKinds.isSuperset(of: ["broken-image", "text-overflow", "out-of-bounds", "overlap", "pptx-effect-risk"]) &&
            hasElementTarget
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

    private func bridgeString(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        default:
            return nil
        }
    }

    private func hasBridgeString(_ value: Any?) -> Bool {
        guard let string = bridgeString(value) else { return false }
        return !string.isEmpty
    }

    private func bridgeStringArray(_ value: Any?) -> [String]? {
        if let strings = value as? [String] {
            return strings
        }
        if let values = value as? [Any] {
            return values.compactMap { $0 as? String }
        }
        return nil
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
        fputs("HTML delivery diagnostics test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        main { position: relative; width: 960px; height: 540px; padding: 48px; overflow: hidden; background: #f8fafc; }
        img { width: 180px; height: 90px; display: block; }
        table { border-collapse: collapse; margin-top: 24px; }
        td { border: 1px solid #94a3b8; padding: 10px 14px; }
        .overflow-copy { width: 132px; height: 24px; overflow: hidden; white-space: nowrap; border: 1px solid #cbd5e1; }
        .out-of-bounds { position: absolute; left: 930px; top: 470px; width: 140px; height: 70px; background: #fee2e2; }
        .overlap-a, .overlap-b { position: absolute; left: 300px; top: 300px; width: 190px; height: 72px; padding: 12px; color: white; box-sizing: border-box; }
        .overlap-a { background: #0f766e; }
        .overlap-b { left: 336px; top: 318px; background: #7c3aed; }
        .pptx-effect-risk { position: absolute; left: 650px; top: 96px; width: 150px; height: 72px; background: radial-gradient(circle, #60a5fa, #1e3a8a); filter: saturate(1.4); clip-path: polygon(0 0, 100% 12%, 92% 100%, 8% 88%); color: white; padding: 14px; box-sizing: border-box; }
      </style>
    </head>
    <body>
      <main>
        <h1>Delivery Diagnostics Fixture</h1>
        <p class="overflow-copy">This sentence is intentionally much wider than its small box.</p>
        <img alt="missing" src="missing-chiselo-delivery-diagnostics.png">
        <svg width="80" height="40" viewBox="0 0 80 40"><rect width="80" height="40" fill="#0a84ff"/></svg>
        <table>
          <tr><td colspan="2">merged</td><td>C</td></tr>
          <tr><td>A</td><td>B</td><td>C</td></tr>
        </table>
        <div class="overlap-a">Overlap block A</div>
        <div class="overlap-b">Overlap block B</div>
        <div class="pptx-effect-risk">Complex CSS effect</div>
        <div class="out-of-bounds">Outside page</div>
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

let test = HTMLDeliveryDiagnosticsTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
