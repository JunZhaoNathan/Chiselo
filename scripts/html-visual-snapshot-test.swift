import AppKit
import Foundation
import WebKit

final class HTMLVisualSnapshotTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?
    private var didStart = false
    private var didCapture = false
    private var didLongPageCheck = false

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
            self?.fail("Timed out waiting for visual snapshot")
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
              type == "htmlTreeChanged" else {
            return
        }

        guard !didCapture else { return }
        didCapture = true
        captureSnapshotPair()
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

    private func captureSnapshotPair() {
        captureSnapshot { [weak self] baselineImage, rect, baselineBytes in
            guard let self else { return }
            self.applyVisualChange {
                self.captureSnapshot { currentImage, _, currentBytes in
                    guard let diff = self.visualDiff(baseline: baselineImage, current: currentImage),
                          let heatmap = diff.heatmap,
                          let heatmapBytes = self.pngByteCount(for: heatmap),
                          heatmapBytes > 100 else {
                        self.fail("Snapshot diff was empty")
                    }

                    guard diff.changedPixelRatio > 0.001, diff.averageDelta > 0 else {
                        self.fail("Snapshot diff did not detect the visual change: \(diff)")
                    }

                    self.checkLongPageSegmentation(previous: [
                        "rect": [
                            "x": rect.origin.x,
                            "y": rect.origin.y,
                            "width": rect.width,
                            "height": rect.height
                        ],
                        "baselinePngBytes": baselineBytes,
                        "currentPngBytes": currentBytes,
                        "heatmapPngBytes": heatmapBytes,
                        "changedPixelRatio": diff.changedPixelRatio,
                        "averageDelta": diff.averageDelta
                    ])
                }
            }
        }
    }

    private func checkLongPageSegmentation(previous: [String: Any]) {
        guard !didLongPageCheck else { return }
        didLongPageCheck = true

        loadLongFixture { [weak self] in
            self?.prepareLongFixtureSnapshot(previous: previous)
        }
    }

    private func loadLongFixture(completion: @escaping () -> Void) {
        let base64 = Data(Self.longFixtureHTML.utf8).base64EncodedString()
        let script = """
        void window.ChiseloEditor.openHTMLFromBase64('\(base64)', '')
          .catch(error => console.error(error));
        """

        webView?.evaluateJavaScript(script) { [weak self] _, error in
            guard let self else { return }
            if let error {
                self.fail("Could not load long fixture: \(error.localizedDescription)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                completion()
            }
        }
    }

    private func prepareLongFixtureSnapshot(previous: [String: Any]) {
        webView?.evaluateJavaScript("JSON.stringify(window.ChiseloEditor.prepareVisualReviewSnapshot())") { [weak self] result, error in
            guard let self else { return }
            if let error {
                self.fail("Could not prepare long fixture: \(error.localizedDescription)")
            }

            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let snapshot = object["snapshot"] as? [String: Any],
                  let rect = snapshot["rect"] as? [String: Any],
                  let contentHeight = self.bridgeCGFloat(snapshot["contentHeight"]),
                  let viewportHeight = self.bridgeCGFloat(rect["height"]),
                  contentHeight > viewportHeight * 1.5 else {
                self.fail("Long page snapshot metadata did not show a scrollable page")
            }

            self.webView?.evaluateJavaScript("JSON.stringify(window.ChiseloEditor.scrollVisualReviewSnapshotTo(\(viewportHeight)))") { [weak self] segmentResult, segmentError in
                guard let self else { return }
                if let segmentError {
                    self.fail("Could not scroll long fixture snapshot: \(segmentError.localizedDescription)")
                }
                guard let segmentJSON = segmentResult as? String,
                      let segmentData = segmentJSON.data(using: .utf8),
                      let segment = try? JSONSerialization.jsonObject(with: segmentData) as? [String: Any],
                      let offsetY = self.bridgeCGFloat(segment["offsetY"]),
                      offsetY > 0 else {
                    self.fail("Long page second segment did not report a positive offset")
                }

                if let state = object["state"] {
                    self.restoreSnapshotState(state, in: self.webView!) {
                        self.printResult(previous: previous, longContentHeight: contentHeight, longViewportHeight: viewportHeight)
                    }
                } else {
                    self.printResult(previous: previous, longContentHeight: contentHeight, longViewportHeight: viewportHeight)
                }
            }
        }
    }

    private func printResult(previous: [String: Any], longContentHeight: CGFloat, longViewportHeight: CGFloat) {
        var output = previous
        output["type"] = "result"
        output["longContentHeight"] = longContentHeight
        output["longViewportHeight"] = longViewportHeight

        if let data = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            print(string)
        }
        exit(0)
    }

    private func captureSnapshot(completion: @escaping (NSImage, NSRect, Int) -> Void) {
        guard let webView else {
            fail("WebView missing")
        }

        let script = "JSON.stringify(window.ChiseloEditor?.prepareVisualReviewSnapshot?.() ?? null);"
        webView.evaluateJavaScript(script) { [weak self, weak webView] result, error in
            guard let self, let webView else { return }
            if let error {
                self.fail("Could not get snapshot rect: \(error.localizedDescription)")
            }

            guard let json = result as? String,
                  json != "null",
                  let data = json.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let snapshotObject = object["snapshot"] as? [String: Any],
                  let rectObject = snapshotObject["rect"] as? [String: Any] else {
                self.fail("Snapshot rect was not valid JSON")
            }
            let restoreState = object["state"]

            let rect = NSRect(
                x: max(0, self.bridgeCGFloat(rectObject["x"]) ?? 0),
                y: max(0, self.bridgeCGFloat(rectObject["y"]) ?? 0),
                width: max(1, self.bridgeCGFloat(rectObject["width"]) ?? webView.bounds.width),
                height: max(1, self.bridgeCGFloat(rectObject["height"]) ?? webView.bounds.height)
            ).intersection(webView.bounds)

            guard rect.width > 100, rect.height > 100 else {
                self.fail("Snapshot rect too small: \(rect)")
            }

            let config = WKSnapshotConfiguration()
            config.rect = rect
            webView.takeSnapshot(with: config) { [weak self] image, error in
                guard let self else { return }
                if let error {
                    self.fail("Could not take snapshot: \(error.localizedDescription)")
                }

                guard let image,
                      let pngData = self.pngData(for: image),
                      pngData.count > 1000 else {
                    self.fail("Snapshot PNG was empty")
                }

                self.restoreSnapshotState(restoreState, in: webView) {
                    completion(image, rect, pngData.count)
                }
            }
        }
    }

    private func restoreSnapshotState(_ state: Any?, in webView: WKWebView, completion: @escaping () -> Void) {
        guard let state,
              JSONSerialization.isValidJSONObject(state),
              let data = try? JSONSerialization.data(withJSONObject: state, options: []),
              let json = String(data: data, encoding: .utf8) else {
            completion()
            return
        }

        webView.evaluateJavaScript("window.ChiseloEditor?.restoreVisualReviewSnapshot?.(\(json));") { [weak self] _, error in
            if let error {
                self?.fail("Could not restore snapshot state: \(error.localizedDescription)")
            }
            completion()
        }
    }

    private func applyVisualChange(completion: @escaping () -> Void) {
        let script = """
        (() => {
          const badge = document.querySelector('.html-frame')?.contentDocument?.querySelector('.badge');
          if (!badge) return false;
          badge.textContent = 'Snapshot changed';
          badge.style.background = '#dc2626';
          badge.style.transform = 'translateX(120px)';
          return true;
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            if let error {
                self?.fail("Could not apply visual change: \(error.localizedDescription)")
            }
            guard (result as? Bool) == true else {
                guard let self else { return }
                self.fail("Visual change target not found")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                completion()
            }
        }
    }

    private struct SnapshotDiff: CustomStringConvertible {
        var changedPixelRatio: Double
        var averageDelta: Double
        var heatmap: NSImage?

        var description: String {
            "changedPixelRatio=\(changedPixelRatio), averageDelta=\(averageDelta)"
        }
    }

    private struct RGBAPixels {
        var width: Int
        var height: Int
        var bytes: [UInt8]
    }

    private func visualDiff(baseline: NSImage, current: NSImage) -> SnapshotDiff? {
        guard let baselinePixels = rgbaPixels(for: baseline),
              let currentPixels = rgbaPixels(for: current),
              baselinePixels.bytes.count == currentPixels.bytes.count else {
            return nil
        }

        let pixelCount = max(baselinePixels.width * baselinePixels.height, 1)
        var changedPixels = 0
        var totalDelta = 0.0
        var heatmapBytes = Array(repeating: UInt8(0), count: pixelCount * 4)

        var pixelIndex = 0
        var byteIndex = 0
        while byteIndex + 3 < baselinePixels.bytes.count {
            let redDelta = abs(Int(baselinePixels.bytes[byteIndex]) - Int(currentPixels.bytes[byteIndex]))
            let greenDelta = abs(Int(baselinePixels.bytes[byteIndex + 1]) - Int(currentPixels.bytes[byteIndex + 1]))
            let blueDelta = abs(Int(baselinePixels.bytes[byteIndex + 2]) - Int(currentPixels.bytes[byteIndex + 2]))
            let alphaDelta = abs(Int(baselinePixels.bytes[byteIndex + 3]) - Int(currentPixels.bytes[byteIndex + 3]))
            let normalizedDelta = Double(redDelta + greenDelta + blueDelta + alphaDelta) / (255.0 * 4.0)

            totalDelta += normalizedDelta
            if normalizedDelta >= 0.035 {
                changedPixels += 1
            }

            let intensity = UInt8(min(255, max(0, Int((normalizedDelta * 420).rounded()))))
            heatmapBytes[pixelIndex * 4] = 255
            heatmapBytes[pixelIndex * 4 + 1] = UInt8(max(0, 180 - Int(intensity) / 2))
            heatmapBytes[pixelIndex * 4 + 2] = 40
            heatmapBytes[pixelIndex * 4 + 3] = intensity

            pixelIndex += 1
            byteIndex += 4
        }

        return SnapshotDiff(
            changedPixelRatio: Double(changedPixels) / Double(pixelCount),
            averageDelta: totalDelta / Double(pixelCount),
            heatmap: imageFromRGBABytes(heatmapBytes, width: baselinePixels.width, height: baselinePixels.height)
        )
    }

    private func rgbaPixels(for image: NSImage, width targetWidth: Int = 192, height targetHeight: Int = 128) -> RGBAPixels? {
        let imageWidth = max(image.size.width, 1)
        let imageHeight = max(image.size.height, 1)
        var bytes = Array(repeating: UInt8(0), count: targetWidth * targetHeight * 4)
        guard let context = CGContext(
            data: &bytes,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight).fill()
        image.draw(in: fittedRect(imageSize: NSSize(width: imageWidth, height: imageHeight), targetSize: NSSize(width: targetWidth, height: targetHeight)), from: .zero, operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        return RGBAPixels(width: targetWidth, height: targetHeight, bytes: bytes)
    }

    private func fittedRect(imageSize: NSSize, targetSize: NSSize) -> NSRect {
        let scale = min(targetSize.width / max(imageSize.width, 1), targetSize.height / max(imageSize.height, 1))
        let width = max(1, imageSize.width * scale)
        let height = max(1, imageSize.height * scale)
        return NSRect(
            x: (targetSize.width - width) / 2,
            y: (targetSize.height - height) / 2,
            width: width,
            height: height
        )
    }

    private func imageFromRGBABytes(_ bytes: [UInt8], width: Int, height: Int) -> NSImage? {
        var mutableBytes = bytes
        guard let context = CGContext(
            data: &mutableBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    private func pngByteCount(for image: NSImage) -> Int? {
        pngData(for: image)?.count
    }

    private func pngData(for image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }

    private func bridgeCGFloat(_ value: Any?) -> CGFloat? {
        switch value {
        case let double as Double:
            return double.isFinite ? CGFloat(double) : nil
        case let number as NSNumber:
            let double = number.doubleValue
            return double.isFinite ? CGFloat(double) : nil
        case let string as String:
            guard let double = Double(string), double.isFinite else { return nil }
            return CGFloat(double)
        default:
            return nil
        }
    }

    private func fail(_ message: String) -> Never {
        fputs("HTML visual snapshot test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        main { width: 960px; height: 540px; padding: 48px; background: linear-gradient(135deg, #f8fafc, #dbeafe); color: #0f172a; }
        h1 { margin: 0 0 18px; font-size: 44px; }
        p { width: 520px; font-size: 18px; line-height: 1.45; }
        .badge { display: inline-block; margin-top: 24px; padding: 12px 18px; background: #0a84ff; color: white; border-radius: 14px; font-weight: 800; }
      </style>
    </head>
    <body>
      <main>
        <h1>Visual Snapshot Fixture</h1>
        <p>This page exists to verify that the export preflight can capture the rendered canvas for before/after review.</p>
        <div class="badge">Snapshot target</div>
      </main>
    </body>
    </html>
    """

    private static let longFixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #f8fafc; }
        main { width: 960px; min-height: 2200px; padding: 48px; color: #0f172a; background: linear-gradient(180deg, #dbeafe, #f8fafc 40%, #dcfce7); }
        section { height: 360px; margin-bottom: 42px; padding: 28px; border-radius: 18px; background: rgba(255,255,255,.78); border: 1px solid rgba(15,23,42,.12); }
        h1 { margin: 0 0 18px; font-size: 44px; }
      </style>
    </head>
    <body>
      <main>
        <h1>Long Visual Snapshot Fixture</h1>
        <section>Segment 1</section>
        <section>Segment 2</section>
        <section>Segment 3</section>
        <section>Segment 4</section>
        <section>Segment 5</section>
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

let test = HTMLVisualSnapshotTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
