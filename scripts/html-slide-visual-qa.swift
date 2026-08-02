import AppKit
import Foundation
import WebKit

final class HTMLSlideVisualQA: NSObject, WKNavigationDelegate {
    private let inputURL: URL
    private let outputDirectory: URL
    private let webView: WKWebView
    private var report: [String: Any] = [:]

    init(inputURL: URL, outputDirectory: URL) {
        self.inputURL = inputURL
        self.outputDirectory = outputDirectory
        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720))
        super.init()
        webView.navigationDelegate = self
    }

    func start() {
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        } catch {
            fail("Could not create QA output directory: \(error.localizedDescription)")
        }

        webView.loadFileURL(inputURL, allowingReadAccessTo: inputURL.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.collectReport()
        }
    }

    private func collectReport() {
        webView.evaluateJavaScript(Self.collectScript) { result, error in
            if let error {
                self.fail("QA collection failed: \(error.localizedDescription)")
            }

            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.fail("QA collection returned invalid data.")
            }

            self.report = object
            let slideCount = object["slideCount"] as? Int ?? 0
            if slideCount == 0 {
                self.fail("No .slide elements found.")
            }

            self.captureSlide(index: 0, count: slideCount)
        }
    }

    private func captureSlide(index: Int, count: Int) {
        if index >= count {
            finish()
            return
        }

        let script = Self.prepareSnapshotScript(index: index)
        webView.evaluateJavaScript(script) { result, error in
            if let error {
                self.fail("Could not prepare slide \(index + 1): \(error.localizedDescription)")
            }

            let info = result as? [String: Any]
            let width = CGFloat(info?["width"] as? Double ?? 1280)
            let height = CGFloat(info?["height"] as? Double ?? 720)
            self.webView.setFrameSize(NSSize(width: width, height: height))

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let config = WKSnapshotConfiguration()
                config.rect = NSRect(x: 0, y: 0, width: width, height: height)
                self.webView.takeSnapshot(with: config) { image, error in
                    if let error {
                        self.fail("Snapshot failed for slide \(index + 1): \(error.localizedDescription)")
                    }

                    guard let tiff = image?.tiffRepresentation,
                          let rep = NSBitmapImageRep(data: tiff),
                          let png = rep.representation(using: .png, properties: [:]) else {
                        self.fail("Could not encode slide \(index + 1) PNG.")
                    }

                    let outputURL = self.outputDirectory.appendingPathComponent(String(format: "page-%02d.png", index + 1))
                    do {
                        try png.write(to: outputURL)
                    } catch {
                        self.fail("Could not write \(outputURL.lastPathComponent): \(error.localizedDescription)")
                    }

                    self.captureSlide(index: index + 1, count: count)
                }
            }
        }
    }

    private func finish() {
        let reportURL = outputDirectory.appendingPathComponent("report.json")
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: reportURL)
        } catch {
            fail("Could not write QA report: \(error.localizedDescription)")
        }

        let issues = report["issues"] as? [[String: Any]] ?? []
        let criticalCount = issues.filter { ($0["severity"] as? String) == "critical" }.count
        let warningCount = issues.filter { ($0["severity"] as? String) == "warning" }.count

        print("QA report: \(reportURL.path)")
        print("Screenshots: \(outputDirectory.path)")
        print("Issues: \(issues.count) total, \(criticalCount) critical, \(warningCount) warning")

        if !issues.isEmpty,
           let data = try? JSONSerialization.data(withJSONObject: issues, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) {
            print(output)
        }

        exit(criticalCount == 0 ? 0 : 1)
    }

    private func fail(_ message: String) -> Never {
        fputs("\(message)\n", stderr)
        exit(1)
    }

    private static let collectScript = """
    (() => {
      const slides = [...document.querySelectorAll('.slide')];
      const issues = [];
      const majorSelector = [
        'h1', 'h2', 'h3', 'p.subtitle', '.kicker', '.accent-line',
        'img', 'table', '.pill', '.grid-3', '.grid-4', '.two-col',
        '.timeline', '.dashboard', '.architecture', '.quote',
        '.metric-card', '.capability-card', '.scenario-card', '.risk-card',
        '.phase', '.component-row', '.bar-list', '.material-card'
      ].join(',');

      const rectOf = (node, base) => {
        const rect = node.getBoundingClientRect();
        return {
          x: Math.round(rect.left - base.left),
          y: Math.round(rect.top - base.top),
          w: Math.round(rect.width),
          h: Math.round(rect.height),
          right: Math.round(rect.right - base.left),
          bottom: Math.round(rect.bottom - base.top)
        };
      };

      const visible = (node) => {
        const style = getComputedStyle(node);
        const rect = node.getBoundingClientRect();
        return style.display !== 'none' && style.visibility !== 'hidden' && Number(style.opacity || 1) > 0.01 && rect.width > 3 && rect.height > 3;
      };

      const labelFor = (node) => {
        const className = [...node.classList || []].slice(0, 2).map((name) => '.' + name).join('');
        const text = (node.textContent || '').replace(/\\s+/g, ' ').trim().slice(0, 42);
        return `${node.tagName.toLowerCase()}${node.id ? '#' + node.id : ''}${className}${text ? ' ' + text : ''}`;
      };

      const area = (rect) => Math.max(0, rect.w) * Math.max(0, rect.h);
      const overlapRect = (a, b) => {
        const left = Math.max(a.x, b.x);
        const top = Math.max(a.y, b.y);
        const right = Math.min(a.right, b.right);
        const bottom = Math.min(a.bottom, b.bottom);
        return { x: left, y: top, w: Math.max(0, right - left), h: Math.max(0, bottom - top), right, bottom };
      };

      const isTextNode = (node) => node.matches('h1,h2,h3,p,li,td,th,span,b');
      const isAllowedOverlap = (a, b) => {
        if (a.contains(b) || b.contains(a)) return true;
        if (a.closest('table') && b.closest('table')) return true;
        if (a.closest('.dashboard') && b.closest('.dashboard')) return true;
        if (a.closest('.timeline') && b.closest('.timeline')) return true;
        if (a.closest('.grid-3') && b.closest('.grid-3')) return true;
        if (a.closest('.grid-4') && b.closest('.grid-4')) return true;
        return false;
      };

      slides.forEach((slide, slideIndex) => {
        const slideRect = slide.getBoundingClientRect();
        const slideWidth = Math.round(slideRect.width);
        const slideHeight = Math.round(slideRect.height);
        const candidates = [...slide.querySelectorAll(majorSelector)]
          .filter((node) => visible(node))
          .filter((node) => ![...node.children].some((child) => child.matches?.(majorSelector) && child.getBoundingClientRect().width > node.getBoundingClientRect().width * 0.86 && child.getBoundingClientRect().height > node.getBoundingClientRect().height * 0.86));

        for (const node of candidates) {
          const rect = rectOf(node, slideRect);
          if (rect.x < -4 || rect.y < -4 || rect.right > slideWidth + 4 || rect.bottom > slideHeight + 4) {
            issues.push({
              severity: 'critical',
              type: 'outOfBounds',
              slide: slideIndex + 1,
              node: labelFor(node),
              rect,
              slideWidth,
              slideHeight
            });
          }

          if (isTextNode(node)) {
            const overflowX = node.scrollWidth - node.clientWidth;
            const overflowY = node.scrollHeight - node.clientHeight;
            const style = getComputedStyle(node);
            const clips = ['hidden', 'clip', 'auto', 'scroll'].includes(style.overflow) || ['hidden', 'clip', 'auto', 'scroll'].includes(style.overflowX) || ['hidden', 'clip', 'auto', 'scroll'].includes(style.overflowY);
            if (clips && (overflowX > 4 || overflowY > 4)) {
              issues.push({
                severity: 'critical',
                type: 'textOverflow',
                slide: slideIndex + 1,
                node: labelFor(node),
                overflowX: Math.round(overflowX),
                overflowY: Math.round(overflowY),
                rect
              });
            }
          }
        }

        for (let i = 0; i < candidates.length; i += 1) {
          for (let j = i + 1; j < candidates.length; j += 1) {
            const a = candidates[i];
            const b = candidates[j];
            if (isAllowedOverlap(a, b)) continue;

            const ar = rectOf(a, slideRect);
            const br = rectOf(b, slideRect);
            const overlap = overlapRect(ar, br);
            const overlapArea = area(overlap);
            if (overlapArea < 240) continue;

            const ratio = overlapArea / Math.min(area(ar), area(br));
            const textConflict = isTextNode(a) || isTextNode(b);
            const mediaConflict = a.matches('img,table') || b.matches('img,table');
            if (ratio > 0.10 && (textConflict || mediaConflict)) {
              issues.push({
                severity: ratio > 0.18 ? 'critical' : 'warning',
                type: 'overlap',
                slide: slideIndex + 1,
                a: labelFor(a),
                b: labelFor(b),
                ratio: Number(ratio.toFixed(3)),
                rect: overlap
              });
            }
          }
        }
      });

      return JSON.stringify({
        input: location.href,
        slideCount: slides.length,
        issues,
        slides: slides.map((slide, index) => {
          const rect = slide.getBoundingClientRect();
          return { index: index + 1, width: Math.round(rect.width), height: Math.round(rect.height) };
        })
      });
    })();
    """

    private static func prepareSnapshotScript(index: Int) -> String {
        """
        (() => {
          const slides = [...document.querySelectorAll('.slide')];
          const slide = slides[\(index)];
          if (!slide) return { width: 1280, height: 720 };
          let style = document.getElementById('__chiselo_visual_qa_style');
          if (!style) {
            style = document.createElement('style');
            style.id = '__chiselo_visual_qa_style';
            document.head.appendChild(style);
          }
          style.textContent = `
            html, body { margin: 0 !important; padding: 0 !important; width: auto !important; height: auto !important; overflow: hidden !important; background: white !important; display: block !important; }
            .slide { display: none !important; margin: 0 !important; box-shadow: none !important; }
            .slide.__chiselo_visual_qa_active { display: block !important; }
          `;
          slides.forEach((item) => item.classList.remove('__chiselo_visual_qa_active'));
          slide.classList.add('__chiselo_visual_qa_active');
          window.scrollTo(0, 0);
          const rect = slide.getBoundingClientRect();
          return { width: Math.ceil(rect.width), height: Math.ceil(rect.height) };
        })();
        """
    }
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputsRoot = projectRoot.appendingPathComponent("outputs", isDirectory: true)
try? FileManager.default.createDirectory(at: outputsRoot, withIntermediateDirectories: true)

let defaultInput = outputsRoot.appendingPathComponent("digital-transformation-10-slides-edited.html").path
let defaultOutput = outputsRoot.appendingPathComponent("digital-transformation-visual-qa").path
let input = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? defaultInput)
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().dropFirst().first ?? defaultOutput)

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let qa = HTMLSlideVisualQA(inputURL: input, outputDirectory: output)
DispatchQueue.main.async {
    qa.start()
}

app.run()
