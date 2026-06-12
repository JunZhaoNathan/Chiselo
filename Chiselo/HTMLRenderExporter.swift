import AppKit
import CoreGraphics
import Foundation
import WebKit

@MainActor
final class HTMLRenderExporter: NSObject, WKNavigationDelegate {
    struct RenderedPage {
        var index: Int
        var width: CGFloat
        var height: CGFloat
        var pngData: Data
    }

    struct EditablePage: Decodable {
        var index: Int
        var width: Double
        var height: Double
        var backgroundColor: String?
        var backgroundAlpha: Double
        var backgroundGradient: EditableGradient?
        var objects: [EditableObject]
    }

    struct EditableObject: Decodable {
        var id: Int
        var kind: String
        var tag: String
        var name: String?
        var x: Double
        var y: Double
        var width: Double
        var height: Double
        var rotate: Double
        var opacity: Double
        var text: String?
        var imageSource: String?
        var fillColor: String?
        var fillAlpha: Double
        var fillGradient: EditableGradient?
        var borderColor: String?
        var borderAlpha: Double
        var borderWidth: Double
        var radius: Double
        var shadowColor: String?
        var shadowAlpha: Double
        var shadowBlur: Double
        var shadowDistance: Double
        var shadowAngle: Double
        var paddingLeft: Double
        var paddingTop: Double
        var paddingRight: Double
        var paddingBottom: Double
        var fontFamily: String?
        var fontSize: Double
        var fontWeight: String?
        var fontStyle: String?
        var textColor: String?
        var textAlpha: Double
        var textAlign: String?
        var lineHeight: Double
    }

    struct EditableGradient: Decodable {
        var angle: Double
        var stops: [EditableGradientStop]
    }

    struct EditableGradientStop: Decodable {
        var color: String
        var alpha: Double
        var position: Double
    }

    private let html: String
    private let baseURL: URL?
    private let webView: WKWebView
    private var renderCompletion: ((Result<[RenderedPage], Error>) -> Void)?
    private var editableCompletion: ((Result<[EditablePage], Error>) -> Void)?
    private var renderMode: RenderMode = .rendered

    private enum RenderMode {
        case rendered
        case editable
    }

    init(html: String, baseURL: URL?) {
        self.html = html
        self.baseURL = baseURL
        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720))
        super.init()
        webView.navigationDelegate = self
    }

    func renderPages(completion: @escaping (Result<[RenderedPage], Error>) -> Void) {
        renderMode = .rendered
        renderCompletion = completion
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func renderEditablePages(completion: @escaping (Result<[EditablePage], Error>) -> Void) {
        renderMode = .editable
        editableCompletion = completion
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            _ = try? await webView.evaluateJavaScript(Self.exportStabilityScript)
            try? await Task.sleep(nanoseconds: 120_000_000)
            switch renderMode {
            case .rendered:
                collectAndCapturePages()
            case .editable:
                collectEditablePages()
            }
        }
    }

    private func collectAndCapturePages() {
        webView.evaluateJavaScript(Self.collectScript) { [weak self] result, error in
            guard let self else { return }

            if let error {
                self.finishRendered(.failure(error))
                return
            }

            let count = result as? Int ?? 0
            guard count > 0 else {
                self.finishRendered(.failure(ExportError.noPages))
                return
            }

            self.capturePage(index: 0, count: count, pages: [])
        }
    }

    private func capturePage(index: Int, count: Int, pages: [RenderedPage]) {
        if index >= count {
            finishRendered(.success(pages))
            return
        }

        webView.evaluateJavaScript(Self.preparePageScript(index: index)) { [weak self] result, error in
            guard let self else { return }

            if let error {
                self.finishRendered(.failure(error))
                return
            }

            let info = result as? [String: Any]
            let width = CGFloat(info?["width"] as? Double ?? 1280)
            let height = CGFloat(info?["height"] as? Double ?? 720)
            self.webView.setFrameSize(NSSize(width: width, height: height))

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                let config = WKSnapshotConfiguration()
                config.rect = NSRect(x: 0, y: 0, width: width, height: height)
                self.webView.takeSnapshot(with: config) { image, error in
                    if let error {
                        self.finishRendered(.failure(error))
                        return
                    }

                    guard let tiff = image?.tiffRepresentation,
                          let rep = NSBitmapImageRep(data: tiff),
                          let pngData = rep.representation(using: .png, properties: [:]) else {
                        self.finishRendered(.failure(ExportError.pngEncodingFailed))
                        return
                    }

                    var nextPages = pages
                    nextPages.append(RenderedPage(index: index + 1, width: width, height: height, pngData: pngData))
                    self.capturePage(index: index + 1, count: count, pages: nextPages)
                }
            }
        }
    }

    private func collectEditablePages() {
        webView.evaluateJavaScript(Self.collectEditableScript) { [weak self] result, error in
            guard let self else { return }

            if let error {
                let nsError = error as NSError
                self.finishEditable(.failure(ExportError.editableExtractionFailedWithMessage("\(error.localizedDescription)\n\(nsError.userInfo)")))
                return
            }

            guard let json = result as? String,
                  let data = json.data(using: .utf8) else {
                self.finishEditable(.failure(ExportError.editableExtractionFailed))
                return
            }

            do {
                if let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   payload["ok"] as? Bool == false {
                    let message = payload["message"] as? String ?? "Unknown editable extraction error."
                    let stack = payload["stack"] as? String ?? ""
                    self.finishEditable(.failure(ExportError.editableExtractionFailedWithMessage([message, stack].filter { !$0.isEmpty }.joined(separator: "\n"))))
                    return
                }

                let pagesData: Data
                if let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let pagesValue = payload["pages"] {
                    pagesData = try JSONSerialization.data(withJSONObject: pagesValue)
                } else {
                    pagesData = data
                }

                let pages = try JSONDecoder().decode([EditablePage].self, from: pagesData)
                guard !pages.isEmpty else {
                    self.finishEditable(.failure(ExportError.noPages))
                    return
                }
                self.finishEditable(.success(pages))
            } catch {
                self.finishEditable(.failure(error))
            }
        }
    }

    private func finishRendered(_ result: Result<[RenderedPage], Error>) {
        let callback = renderCompletion
        renderCompletion = nil
        callback?(result)
    }

    private func finishEditable(_ result: Result<[EditablePage], Error>) {
        let callback = editableCompletion
        editableCompletion = nil
        callback?(result)
    }

    static func writePDF(pages: [RenderedPage], to url: URL) throws {
        guard !pages.isEmpty else { throw ExportError.noPages }
        guard let consumer = CGDataConsumer(url: url as CFURL) else { throw ExportError.pdfCreationFailed }
        guard let context = CGContext(consumer: consumer, mediaBox: nil, nil) else { throw ExportError.pdfCreationFailed }
        context.interpolationQuality = .high

        for page in pages {
            let pageRect = CGRect(x: 0, y: 0, width: page.width, height: page.height)
            var mediaBox = pageRect
            context.beginPage(mediaBox: &mediaBox)

            guard let bitmap = NSBitmapImageRep(data: page.pngData),
                  let image = bitmap.cgImage else {
                throw ExportError.imageDecodeFailed
            }
            context.draw(image, in: pageRect)
            context.endPage()
        }

        context.closePDF()
    }

    static func writePPTX(pages: [RenderedPage], to url: URL) throws {
        guard let first = pages.first else { throw ExportError.noPages }
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChiseloPPTX-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let ppt = tempRoot.appendingPathComponent("ppt", isDirectory: true)
        let rels = tempRoot.appendingPathComponent("_rels", isDirectory: true)
        let pptRels = ppt.appendingPathComponent("_rels", isDirectory: true)
        let slides = ppt.appendingPathComponent("slides", isDirectory: true)
        let slideRels = slides.appendingPathComponent("_rels", isDirectory: true)
        let slideMasters = ppt.appendingPathComponent("slideMasters", isDirectory: true)
        let slideMasterRels = slideMasters.appendingPathComponent("_rels", isDirectory: true)
        let slideLayouts = ppt.appendingPathComponent("slideLayouts", isDirectory: true)
        let slideLayoutRels = slideLayouts.appendingPathComponent("_rels", isDirectory: true)
        let theme = ppt.appendingPathComponent("theme", isDirectory: true)
        let media = ppt.appendingPathComponent("media", isDirectory: true)
        let docProps = tempRoot.appendingPathComponent("docProps", isDirectory: true)

        for directory in [ppt, rels, pptRels, slides, slideRels, slideMasters, slideMasterRels, slideLayouts, slideLayoutRels, theme, media, docProps] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        for page in pages {
            try page.pngData.write(to: media.appendingPathComponent("slide\(page.index).png"))
        }

        try xml(contentTypesXML(slideCount: pages.count), to: tempRoot.appendingPathComponent("[Content_Types].xml"))
        try xml(packageRelsXML(), to: rels.appendingPathComponent(".rels"))
        try xml(corePropsXML(), to: docProps.appendingPathComponent("core.xml"))
        try xml(appPropsXML(slideCount: pages.count), to: docProps.appendingPathComponent("app.xml"))
        let slideWidthEMU = Int64(first.width * 914400 / 96)
        let slideHeightEMU = Int64(first.height * 914400 / 96)
        try xml(presentationXML(slideCount: pages.count, widthEMU: slideWidthEMU, heightEMU: slideHeightEMU), to: ppt.appendingPathComponent("presentation.xml"))
        try xml(presentationRelsXML(slideCount: pages.count), to: pptRels.appendingPathComponent("presentation.xml.rels"))
        try xml(themeXML(), to: theme.appendingPathComponent("theme1.xml"))
        try xml(slideMasterXML(), to: slideMasters.appendingPathComponent("slideMaster1.xml"))
        try xml(slideMasterRelsXML(), to: slideMasterRels.appendingPathComponent("slideMaster1.xml.rels"))
        try xml(slideLayoutXML(), to: slideLayouts.appendingPathComponent("slideLayout1.xml"))
        try xml(slideLayoutRelsXML(), to: slideLayoutRels.appendingPathComponent("slideLayout1.xml.rels"))

        for page in pages {
            try xml(slideXML(index: page.index, widthEMU: slideWidthEMU, heightEMU: slideHeightEMU), to: slides.appendingPathComponent("slide\(page.index).xml"))
            try xml(slideRelsXML(index: page.index), to: slideRels.appendingPathComponent("slide\(page.index).xml.rels"))
        }

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        try runZip(in: tempRoot, output: url)
    }

    static func writeEditablePPTX(pages: [EditablePage], to url: URL, baseURL: URL? = nil) throws {
        guard let first = pages.first else { throw ExportError.noPages }
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChiseloEditablePPTX-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let ppt = tempRoot.appendingPathComponent("ppt", isDirectory: true)
        let rels = tempRoot.appendingPathComponent("_rels", isDirectory: true)
        let pptRels = ppt.appendingPathComponent("_rels", isDirectory: true)
        let slides = ppt.appendingPathComponent("slides", isDirectory: true)
        let slideRels = slides.appendingPathComponent("_rels", isDirectory: true)
        let slideMasters = ppt.appendingPathComponent("slideMasters", isDirectory: true)
        let slideMasterRels = slideMasters.appendingPathComponent("_rels", isDirectory: true)
        let slideLayouts = ppt.appendingPathComponent("slideLayouts", isDirectory: true)
        let slideLayoutRels = slideLayouts.appendingPathComponent("_rels", isDirectory: true)
        let theme = ppt.appendingPathComponent("theme", isDirectory: true)
        let media = ppt.appendingPathComponent("media", isDirectory: true)
        let docProps = tempRoot.appendingPathComponent("docProps", isDirectory: true)

        for directory in [ppt, rels, pptRels, slides, slideRels, slideMasters, slideMasterRels, slideLayouts, slideLayoutRels, theme, media, docProps] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        var imageRelationshipsBySlide: [Int: [EditableImageRelationship]] = [:]
        for page in pages {
            var relationships: [EditableImageRelationship] = []
            var nextRelationshipIndex = 2

            for object in page.objects where object.kind == "image" {
                guard let source = object.imageSource,
                      let payload = imagePayload(for: source, baseURL: baseURL) else {
                    continue
                }

                let fileName = "slide\(page.index)-image\(object.id).\(payload.fileExtension)"
                try payload.data.write(to: media.appendingPathComponent(fileName))
                relationships.append(
                    EditableImageRelationship(
                        objectID: object.id,
                        relationshipID: "rId\(nextRelationshipIndex)",
                        target: "../media/\(fileName)"
                    )
                )
                nextRelationshipIndex += 1
            }

            imageRelationshipsBySlide[page.index] = relationships
        }

        try xml(contentTypesXML(slideCount: pages.count), to: tempRoot.appendingPathComponent("[Content_Types].xml"))
        try xml(packageRelsXML(), to: rels.appendingPathComponent(".rels"))
        try xml(corePropsXML(), to: docProps.appendingPathComponent("core.xml"))
        try xml(appPropsXML(slideCount: pages.count), to: docProps.appendingPathComponent("app.xml"))
        let slideWidthEMU = Int64(first.width * emuPerPixel)
        let slideHeightEMU = Int64(first.height * emuPerPixel)
        try xml(presentationXML(slideCount: pages.count, widthEMU: slideWidthEMU, heightEMU: slideHeightEMU), to: ppt.appendingPathComponent("presentation.xml"))
        try xml(presentationRelsXML(slideCount: pages.count), to: pptRels.appendingPathComponent("presentation.xml.rels"))
        try xml(themeXML(), to: theme.appendingPathComponent("theme1.xml"))
        try xml(slideMasterXML(), to: slideMasters.appendingPathComponent("slideMaster1.xml"))
        try xml(slideMasterRelsXML(), to: slideMasterRels.appendingPathComponent("slideMaster1.xml.rels"))
        try xml(slideLayoutXML(), to: slideLayouts.appendingPathComponent("slideLayout1.xml"))
        try xml(slideLayoutRelsXML(), to: slideLayoutRels.appendingPathComponent("slideLayout1.xml.rels"))

        for page in pages {
            let relationships = imageRelationshipsBySlide[page.index] ?? []
            try xml(
                editableSlideXML(page: page, widthEMU: slideWidthEMU, heightEMU: slideHeightEMU, imageRelationships: relationships),
                to: slides.appendingPathComponent("slide\(page.index).xml")
            )
            try xml(editableSlideRelsXML(imageRelationships: relationships), to: slideRels.appendingPathComponent("slide\(page.index).xml.rels"))
        }

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        try runZip(in: tempRoot, output: url)
    }

    private struct ImagePayload {
        var data: Data
        var fileExtension: String
    }

    private struct EditableImageRelationship {
        var objectID: Int
        var relationshipID: String
        var target: String
    }

    private static let emuPerPixel = 914_400.0 / 96.0
    private static let pageSelector = ".slide, .sheet, .page, [data-slide], [data-page], [role=doc-page], [aria-roledescription=slide], [class~=slide], [class^=slide-], [class*=slide-], [class~=page], [class^=page-], [class*=page-], [id^=slide], [id*=-slide], [id^=page], [id*=-page]"

    private static func runZip(in root: URL, output: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = root
        process.arguments = ["-qr", output.path, "."]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ExportError.pptxZipFailed }
    }

    private static func xml(_ value: String, to url: URL) throws {
        try value.data(using: .utf8)?.write(to: url)
    }

    private static let collectScript = """
    (() => {
      const pages = exportPageNodes();
      if (pages.length) return pages.length;
      return document.body ? 1 : 0;

      function exportPageNodes() {
        const candidates = [...document.querySelectorAll('\(pageSelector)')].filter(isExportPageCandidate);
        const candidateSet = new Set(candidates);
        return candidates.filter((node) => {
          let parent = node.parentElement;
          while (parent && parent !== document.body && parent !== document.documentElement) {
            if (candidateSet.has(parent)) return false;
            parent = parent.parentElement;
          }
          return true;
        });
      }

      function isExportPageCandidate(node) {
        if (!node || node === document.body || node === document.documentElement) return false;
        const style = getComputedStyle(node);
        if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity || 1) <= 0.01) return false;
        const rect = node.getBoundingClientRect();
        return rect.width >= 240 && rect.height >= 160;
      }
    })();
    """

    private static let exportStabilityScript = """
    (() => {
      let style = document.getElementById('__chiselo_export_stability');
      if (!style) {
        style = document.createElement('style');
        style.id = '__chiselo_export_stability';
        document.head.appendChild(style);
      }
      style.textContent = `
        html { scroll-behavior: auto !important; }
        *, *::before, *::after {
          animation-play-state: paused !important;
          transition-property: none !important;
          transition-duration: 0s !important;
          transition-delay: 0s !important;
          caret-color: transparent !important;
        }
      `;
      for (const video of document.querySelectorAll('video')) {
        try { video.pause(); } catch {}
      }
      window.scrollTo(0, 0);
      return true;
    })();
    """

    private static func preparePageScript(index: Int) -> String {
        """
        (() => {
          const pages = exportPageNodes();
          let target = pages[\(index)];
          let style = document.getElementById('__chiselo_export_style');
          if (!style) {
            style = document.createElement('style');
            style.id = '__chiselo_export_style';
            document.head.appendChild(style);
          }

          if (pages.length && target) {
            style.textContent = `
              html, body { margin: 0 !important; padding: 0 !important; width: auto !important; height: auto !important; overflow: hidden !important; background: white !important; display: block !important; }
              .__chiselo_export_page { display: none !important; margin: 0 !important; box-shadow: none !important; }
              .__chiselo_export_page.__chiselo_export_active { display: block !important; }
            `;
            pages.forEach((page) => {
              page.classList.add('__chiselo_export_page');
              page.classList.remove('__chiselo_export_active');
            });
            target.classList.add('__chiselo_export_active');
          } else {
            target = document.body;
            style.textContent = `
              html, body { margin: 0 !important; padding: 0 !important; overflow: hidden !important; background: white !important; display: block !important; }
            `;
          }

          window.scrollTo(0, 0);
          const rect = target.getBoundingClientRect();
          return {
            width: Math.max(640, Math.ceil(rect.width || document.documentElement.scrollWidth || 1280)),
            height: Math.max(360, Math.ceil(rect.height || document.documentElement.scrollHeight || 720))
          };

          function exportPageNodes() {
            const candidates = [...document.querySelectorAll('\(pageSelector)')].filter(isExportPageCandidate);
            const candidateSet = new Set(candidates);
            return candidates.filter((node) => {
              let parent = node.parentElement;
              while (parent && parent !== document.body && parent !== document.documentElement) {
                if (candidateSet.has(parent)) return false;
                parent = parent.parentElement;
              }
              return true;
            });
          }

          function isExportPageCandidate(node) {
            if (!node || node === document.body || node === document.documentElement) return false;
            const style = getComputedStyle(node);
            if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity || 1) <= 0.01) return false;
            const rect = node.getBoundingClientRect();
            return rect.width >= 240 && rect.height >= 160;
          }
        })();
        """
    }

    private static let collectEditableScript = #"""
    (() => {
      try {
      const ignoredTags = new Set(["SCRIPT", "STYLE", "META", "LINK", "TITLE", "HEAD", "NOSCRIPT", "TEMPLATE"]);
      const textTags = new Set(["A", "B", "BUTTON", "CAPTION", "CODE", "DD", "DT", "EM", "FIGCAPTION", "H1", "H2", "H3", "H4", "H5", "H6", "LABEL", "LEGEND", "LI", "P", "PRE", "SMALL", "SPAN", "STRONG", "TD", "TEXTAREA", "TH"]);
      const pageCandidates = exportPageNodes();
      const pageNodes = pageCandidates.length ? pageCandidates : [document.body || document.documentElement].filter(Boolean);
      let nextID = 2;

      function number(value, fallback = 0) {
        const parsed = parseFloat(value);
        return Number.isFinite(parsed) ? parsed : fallback;
      }

      function px(value, fallback = 0) {
        return number(value, fallback);
      }

      function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
      }

      function exportPageNodes() {
        const candidates = [...document.querySelectorAll("\#(pageSelector)")].filter(isExportPageCandidate);
        const candidateSet = new Set(candidates);
        return candidates.filter((node) => {
          let parent = node.parentElement;
          while (parent && parent !== document.body && parent !== document.documentElement) {
            if (candidateSet.has(parent)) return false;
            parent = parent.parentElement;
          }
          return true;
        });
      }

      function isExportPageCandidate(node) {
        if (!node || node === document.body || node === document.documentElement) return false;
        const style = getComputedStyle(node);
        if (style.display === "none" || style.visibility === "hidden" || number(style.opacity, 1) <= 0.01) return false;
        const rect = node.getBoundingClientRect();
        return rect.width >= 240 && rect.height >= 160;
      }

      function parseColor(value) {
        if (!value || value === "transparent") return { hex: null, alpha: 0 };
        const text = String(value).trim();
        const hex = text.match(/^#([0-9a-f]{3}|[0-9a-f]{6})$/i);
        if (hex) {
          const raw = hex[1].length === 3 ? hex[1].split("").map((part) => part + part).join("") : hex[1];
          return { hex: raw.toUpperCase(), alpha: 1 };
        }
        const match = text.match(/rgba?\(([^)]+)\)/i);
        if (!match) return { hex: null, alpha: 0 };
        const parts = match[1].split(/[, ]+/).filter(Boolean).map((part) => part.trim().replace("%", ""));
        if (parts.length < 3) return { hex: null, alpha: 0 };
        const r = clamp(Math.round(number(parts[0])), 0, 255);
        const g = clamp(Math.round(number(parts[1])), 0, 255);
        const b = clamp(Math.round(number(parts[2])), 0, 255);
        const alpha = parts.length >= 4 ? clamp(number(parts[3], 1), 0, 1) : 1;
        const rgbHex = [r, g, b].map((part) => part.toString(16).padStart(2, "0")).join("").toUpperCase();
        return { hex: rgbHex, alpha };
      }

      function splitTopLevel(value, delimiter = ",") {
        const parts = [];
        let current = "";
        let depth = 0;
        let quote = "";
        for (const char of String(value || "")) {
          if (quote) {
            current += char;
            if (char === quote) quote = "";
            continue;
          }
          if (char === "\"" || char === "'") {
            quote = char;
            current += char;
            continue;
          }
          if (char === "(") depth += 1;
          if (char === ")") depth = Math.max(0, depth - 1);
          if (char === delimiter && depth === 0) {
            parts.push(current.trim());
            current = "";
          } else {
            current += char;
          }
        }
        if (current.trim()) parts.push(current.trim());
        return parts;
      }

      function parseGradient(value) {
        const source = String(value || "");
        const match = source.match(/linear-gradient\((.*)\)/i);
        if (!match) return null;
        const parts = splitTopLevel(match[1]);
        if (parts.length < 2) return null;

        let angle = 90;
        let stopParts = parts;
        const first = parts[0].toLowerCase();
        if (first.includes("deg")) {
          angle = number(first, 90);
          stopParts = parts.slice(1);
        } else if (first.startsWith("to ")) {
          const direction = first.replace(/^to\s+/, "").trim();
          if (direction === "right") angle = 90;
          else if (direction === "left") angle = 270;
          else if (direction === "bottom") angle = 180;
          else if (direction === "top") angle = 0;
          else if (direction.includes("right") && direction.includes("bottom")) angle = 135;
          else if (direction.includes("left") && direction.includes("bottom")) angle = 225;
          else if (direction.includes("right") && direction.includes("top")) angle = 45;
          else if (direction.includes("left") && direction.includes("top")) angle = 315;
          stopParts = parts.slice(1);
        }

        const rawStops = stopParts.map((part, index) => {
          const colorMatch = part.match(/(rgba?\([^)]+\)|#[0-9a-f]{3,8}|[a-z]+)\s*(.*)$/i);
          if (!colorMatch) return null;
          const color = parseColor(colorMatch[1]);
          if (!color.hex) return null;
          const positionText = colorMatch[2] || "";
          const percent = positionText.match(/(-?\d+(?:\.\d+)?)%/);
          const fallback = stopParts.length <= 1 ? 0 : index / (stopParts.length - 1);
          return {
            color: color.hex,
            alpha: color.alpha,
            position: percent ? clamp(number(percent[1]) / 100, 0, 1) : fallback
          };
        }).filter(Boolean);

        if (rawStops.length < 2) return null;
        return { angle, stops: rawStops };
      }

      function parseShadow(value) {
        if (!value || value === "none") return null;
        const first = splitTopLevel(value)[0];
        if (!first || first.includes("inset")) return null;
        const colorMatch = first.match(/rgba?\([^)]+\)|#[0-9a-f]{3,8}/i);
        const color = parseColor(colorMatch ? colorMatch[0] : "rgba(0,0,0,.25)");
        const lengths = first
          .replace(colorMatch ? colorMatch[0] : "", "")
          .trim()
          .split(/\s+/)
          .map((part) => number(part))
          .filter(Number.isFinite);
        if (lengths.length < 2 || !color.hex || color.alpha <= 0.01) return null;
        const offsetX = lengths[0];
        const offsetY = lengths[1];
        const blur = Math.max(0, lengths[2] || 0);
        const distance = Math.sqrt(offsetX * offsetX + offsetY * offsetY);
        const angle = ((Math.atan2(offsetY, offsetX) * 180 / Math.PI) + 360) % 360;
        return {
          color: color.hex,
          alpha: color.alpha,
          blur,
          distance,
          angle
        };
      }

      function textOf(element) {
        if (element.closest?.("svg")) return "";
        const value = (element.innerText || element.textContent || "").replace(/\u00a0/g, " ");
        return value.split("\n").map((line) => line.replace(/\s+/g, " ").trim()).filter(Boolean).join("\n").trim();
      }

      function isVisible(element, pageRect) {
        if (!element || ignoredTags.has(element.tagName)) return false;
        const style = getComputedStyle(element);
        if (style.display === "none" || style.visibility === "hidden" || number(style.opacity, 1) <= 0.01) return false;
        const rect = element.getBoundingClientRect();
        if (rect.width < 1 || rect.height < 1) return false;
        return rect.right >= pageRect.left && rect.left <= pageRect.right && rect.bottom >= pageRect.top && rect.top <= pageRect.bottom;
      }

      function hasVisibleTextChild(element, pageRect) {
        return [...element.children].some((child) => isVisible(child, pageRect) && textOf(child).length > 0);
      }

      function rotationDegrees(transform) {
        if (!transform || transform === "none") return 0;
        const matrix = transform.match(/matrix\(([^)]+)\)/);
        if (matrix) {
          const parts = matrix[1].split(",").map((part) => number(part));
          if (parts.length >= 2) return Math.atan2(parts[1], parts[0]) * 180 / Math.PI;
        }
        const matrix3d = transform.match(/matrix3d\(([^)]+)\)/);
        if (matrix3d) {
          const parts = matrix3d[1].split(",").map((part) => number(part));
          if (parts.length >= 2) return Math.atan2(parts[1], parts[0]) * 180 / Math.PI;
        }
        return 0;
      }

      function safeName(element, kind) {
        const className = element.getAttribute?.("class") || "";
        return element.id || element.getAttribute("aria-label") || element.getAttribute("alt") || className || kind;
      }

      function svgDataURL(element) {
        const source = new XMLSerializer().serializeToString(element);
        const bytes = new TextEncoder().encode(source);
        let binary = "";
        for (const byte of bytes) binary += String.fromCharCode(byte);
        return `data:image/svg+xml;base64,${btoa(binary)}`;
      }

      function normalizedRect(element, pageRect) {
        const rect = element.getBoundingClientRect();
        return {
          x: Math.round((rect.left - pageRect.left) * 1000) / 1000,
          y: Math.round((rect.top - pageRect.top) * 1000) / 1000,
          width: Math.round(rect.width * 1000) / 1000,
          height: Math.round(rect.height * 1000) / 1000
        };
      }

      function baseObject(element, pageRect, kind) {
        const style = getComputedStyle(element);
        const rect = normalizedRect(element, pageRect);
        const fill = parseColor(style.backgroundColor);
        const gradient = parseGradient(style.backgroundImage);
        const border = parseColor(style.borderTopColor || style.borderColor);
        const fontColor = parseColor(style.color);
        const shadow = parseShadow(style.boxShadow);
        const family = (style.fontFamily || "Arial").split(",")[0].replace(/^["']|["']$/g, "") || "Arial";
        return {
          id: nextID++,
          kind,
          tag: element.tagName.toLowerCase(),
          name: safeName(element, kind),
          x: rect.x,
          y: rect.y,
          width: rect.width,
          height: rect.height,
          rotate: rotationDegrees(style.transform),
          opacity: clamp(number(style.opacity, 1), 0, 1),
          text: null,
          imageSource: null,
          fillColor: fill.hex,
          fillAlpha: fill.alpha,
          fillGradient: gradient,
          borderColor: border.hex,
          borderAlpha: border.alpha,
          borderWidth: Math.max(px(style.borderTopWidth), px(style.borderRightWidth), px(style.borderBottomWidth), px(style.borderLeftWidth)),
          radius: Math.max(px(style.borderTopLeftRadius), px(style.borderTopRightRadius), px(style.borderBottomLeftRadius), px(style.borderBottomRightRadius)),
          shadowColor: shadow?.color || null,
          shadowAlpha: shadow?.alpha || 0,
          shadowBlur: shadow?.blur || 0,
          shadowDistance: shadow?.distance || 0,
          shadowAngle: shadow?.angle || 0,
          paddingLeft: px(style.paddingLeft),
          paddingTop: px(style.paddingTop),
          paddingRight: px(style.paddingRight),
          paddingBottom: px(style.paddingBottom),
          fontFamily: family,
          fontSize: px(style.fontSize, 16),
          fontWeight: style.fontWeight || "400",
          fontStyle: style.fontStyle || "normal",
          textColor: fontColor.hex || "111111",
          textAlpha: fontColor.alpha || 1,
          textAlign: style.textAlign || "left",
          lineHeight: style.lineHeight === "normal" ? px(style.fontSize, 16) * 1.2 : px(style.lineHeight, px(style.fontSize, 16) * 1.2)
        };
      }

      function hasVisualBox(element) {
        const style = getComputedStyle(element);
        const fill = parseColor(style.backgroundColor);
        const gradient = parseGradient(style.backgroundImage);
        const shadow = parseShadow(style.boxShadow);
        const borderWidth = Math.max(px(style.borderTopWidth), px(style.borderRightWidth), px(style.borderBottomWidth), px(style.borderLeftWidth));
        return fill.alpha > 0.01 || Boolean(gradient) || Boolean(shadow) || borderWidth > 0.2;
      }

      function shouldEmitText(element, pageRect, text) {
        if (!text || text.length === 0) return false;
        if (text.length > 1200) return false;
        if (textTags.has(element.tagName)) return true;
        return !hasVisibleTextChild(element, pageRect);
      }

      function cssContentText(value, element) {
        if (!value || value === "normal" || value === "none") return "";
        const pieces = splitTopLevel(String(value), " ");
        const text = pieces.map((piece) => {
          const attr = piece.match(/^attr\(([^)]+)\)$/i);
          if (attr) return element.getAttribute(attr[1].trim()) || "";
          if ((piece.startsWith("\"") && piece.endsWith("\"")) || (piece.startsWith("'") && piece.endsWith("'"))) {
            return piece.slice(1, -1).replace(/\\A/gi, "\n").replace(/\\([0-9a-f]{1,6})\s?/gi, (_, hex) => String.fromCodePoint(parseInt(hex, 16)));
          }
          return "";
        }).join("");
        return text.replace(/\u00a0/g, " ").trim();
      }

      function pseudoRect(element, pageRect, style, text, pseudo) {
        const parent = element.getBoundingClientRect();
        const fontSize = px(style.fontSize, 16);
        const paddingX = px(style.paddingLeft) + px(style.paddingRight);
        const paddingY = px(style.paddingTop) + px(style.paddingBottom);
        const width = style.width === "auto" || !style.width
          ? Math.max(6, Math.min(parent.width, text ? text.length * fontSize * 0.62 + paddingX : parent.width))
          : Math.max(1, px(style.width, parent.width));
        const lineHeight = style.lineHeight === "normal" ? fontSize * 1.2 : px(style.lineHeight, fontSize * 1.2);
        const height = style.height === "auto" || !style.height
          ? Math.max(6, text ? lineHeight + paddingY : Math.min(parent.height, lineHeight + paddingY))
          : Math.max(1, px(style.height, parent.height));
        let left = parent.left;
        let top = parent.top;

        if (style.position === "absolute" || style.position === "fixed") {
          if (style.left !== "auto") left = parent.left + px(style.left);
          else if (style.right !== "auto") left = parent.right - px(style.right) - width;
          else if (pseudo === "::after") left = parent.right - width;

          if (style.top !== "auto") top = parent.top + px(style.top);
          else if (style.bottom !== "auto") top = parent.bottom - px(style.bottom) - height;
        } else if (pseudo === "::after") {
          left = Math.max(parent.left, parent.right - width);
        }

        return {
          x: Math.round((left - pageRect.left) * 1000) / 1000,
          y: Math.round((top - pageRect.top) * 1000) / 1000,
          width: Math.round(width * 1000) / 1000,
          height: Math.round(height * 1000) / 1000
        };
      }

      function pseudoObject(element, pageRect, pseudo) {
        const style = getComputedStyle(element, pseudo);
        if (!style || style.display === "none" || style.visibility === "hidden" || number(style.opacity, 1) <= 0.01) return null;
        const text = cssContentText(style.content, element);
        const fill = parseColor(style.backgroundColor);
        const gradient = parseGradient(style.backgroundImage);
        const border = parseColor(style.borderTopColor || style.borderColor);
        const fontColor = parseColor(style.color);
        const shadow = parseShadow(style.boxShadow);
        const borderWidth = Math.max(px(style.borderTopWidth), px(style.borderRightWidth), px(style.borderBottomWidth), px(style.borderLeftWidth));
        const hasBox = fill.alpha > 0.01 || Boolean(gradient) || borderWidth > 0.2 || Boolean(shadow);
        if (!text && !hasBox) return null;

        const rect = pseudoRect(element, pageRect, style, text, pseudo);
        if (rect.width < 1 || rect.height < 1) return null;
        const family = (style.fontFamily || "Arial").split(",")[0].replace(/^["']|["']$/g, "") || "Arial";
        return {
          id: nextID++,
          kind: text ? "text" : "shape",
          tag: pseudo,
          name: `${safeName(element, "pseudo")} ${pseudo}`,
          x: rect.x,
          y: rect.y,
          width: rect.width,
          height: rect.height,
          rotate: rotationDegrees(style.transform),
          opacity: clamp(number(style.opacity, 1), 0, 1),
          text: text || null,
          imageSource: null,
          fillColor: fill.hex,
          fillAlpha: fill.alpha,
          fillGradient: gradient,
          borderColor: border.hex,
          borderAlpha: border.alpha,
          borderWidth,
          radius: Math.max(px(style.borderTopLeftRadius), px(style.borderTopRightRadius), px(style.borderBottomLeftRadius), px(style.borderBottomRightRadius)),
          shadowColor: shadow?.color || null,
          shadowAlpha: shadow?.alpha || 0,
          shadowBlur: shadow?.blur || 0,
          shadowDistance: shadow?.distance || 0,
          shadowAngle: shadow?.angle || 0,
          paddingLeft: px(style.paddingLeft),
          paddingTop: px(style.paddingTop),
          paddingRight: px(style.paddingRight),
          paddingBottom: px(style.paddingBottom),
          fontFamily: family,
          fontSize: px(style.fontSize, 16),
          fontWeight: style.fontWeight || "400",
          fontStyle: style.fontStyle || "normal",
          textColor: fontColor.hex || "111111",
          textAlpha: fontColor.alpha || 1,
          textAlign: style.textAlign || "left",
          lineHeight: style.lineHeight === "normal" ? px(style.fontSize, 16) * 1.2 : px(style.lineHeight, px(style.fontSize, 16) * 1.2)
        };
      }

      const pages = pageNodes.map((page, pageIndex) => {
        const pageRect = page.getBoundingClientRect();
        const pageStyle = getComputedStyle(page);
        const pageFill = parseColor(pageStyle.backgroundColor);
        const pageGradient = parseGradient(pageStyle.backgroundImage);
        const width = Math.max(1, Math.ceil(pageRect.width || page.scrollWidth || document.documentElement.scrollWidth || 1280));
        const height = Math.max(1, Math.ceil(pageRect.height || page.scrollHeight || document.documentElement.scrollHeight || 720));
        const objects = [];

        for (const element of page.querySelectorAll("*")) {
          if (!isVisible(element, pageRect)) continue;
          const tag = element.tagName;
          const tagUpper = tag.toUpperCase();
          if (element.closest?.("svg") && tagUpper !== "SVG") continue;
          const text = textOf(element);
          const emitText = shouldEmitText(element, pageRect, text);

          if (tagUpper === "SVG") {
            const object = baseObject(element, pageRect, "image");
            object.imageSource = svgDataURL(element);
            object.text = element.getAttribute("aria-label") || "";
            objects.push(object);
            continue;
          }

          if (tagUpper === "IMG") {
            const object = baseObject(element, pageRect, "image");
            object.imageSource = element.currentSrc || element.src || element.getAttribute("src") || "";
            object.text = element.alt || "";
            objects.push(object);
            continue;
          }

          if (hasVisualBox(element) && !emitText) {
            objects.push(baseObject(element, pageRect, "shape"));
          }

          if (emitText) {
            const object = baseObject(element, pageRect, "text");
            object.text = text;
            objects.push(object);
          }

          for (const pseudo of ["::before", "::after"]) {
            const object = pseudoObject(element, pageRect, pseudo);
            if (object) objects.push(object);
          }
        }

        return {
          index: pageIndex + 1,
          width,
          height,
          backgroundColor: pageFill.hex || "FFFFFF",
          backgroundAlpha: pageFill.alpha || 1,
          backgroundGradient: pageGradient,
          objects
        };
      });

      return JSON.stringify({ ok: true, pages });
      } catch (error) {
        return JSON.stringify({
          ok: false,
          message: String(error && error.message || error),
          stack: String(error && error.stack || "")
        });
      }
    })();
    """#

    private static func contentTypesXML(slideCount: Int) -> String {
        let slideOverrides = (1...slideCount)
            .map { "<Override PartName=\"/ppt/slides/slide\($0).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" }
            .joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Default Extension="png" ContentType="image/png"/>
          <Default Extension="jpg" ContentType="image/jpeg"/>
          <Default Extension="jpeg" ContentType="image/jpeg"/>
          <Default Extension="gif" ContentType="image/gif"/>
          <Default Extension="svg" ContentType="image/svg+xml"/>
          <Default Extension="webp" ContentType="image/webp"/>
          <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
          <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
          <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
          <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
          <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
          <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
          \(slideOverrides)
        </Types>
        """
    }

    private static func packageRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """
    }

    private static func corePropsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <dc:title>Chiselo Export</dc:title>
          <dc:creator>Chiselo</dc:creator>
        </cp:coreProperties>
        """
    }

    private static func appPropsXML(slideCount: Int) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
          <Application>Chiselo</Application>
          <Slides>\(slideCount)</Slides>
        </Properties>
        """
    }

    private static func presentationXML(slideCount: Int, widthEMU: Int64, heightEMU: Int64) -> String {
        let slideIds = (1...slideCount)
            .map { "<p:sldId id=\"\(255 + $0)\" r:id=\"rId\($0)\"/>" }
            .joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId\(slideCount + 1)"/></p:sldMasterIdLst>
          <p:sldIdLst>\(slideIds)</p:sldIdLst>
          <p:sldSz cx="\(widthEMU)" cy="\(heightEMU)"/>
          <p:notesSz cx="6858000" cy="9144000"/>
        </p:presentation>
        """
    }

    private static func presentationRelsXML(slideCount: Int) -> String {
        ("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        """ + (1...slideCount)
            .map { "  <Relationship Id=\"rId\($0)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide\($0).xml\"/>" }
            .joined(separator: "\n") + "\n  <Relationship Id=\"rId\(slideCount + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"slideMasters/slideMaster1.xml\"/>\n</Relationships>")
    }

    private static func slideRelsXML(index: Int) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/slide\(index).png"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
        </Relationships>
        """
    }

    private static func editableSlideRelsXML(imageRelationships: [EditableImageRelationship]) -> String {
        let imageRels = imageRelationships
            .map { "  <Relationship Id=\"\($0.relationshipID)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"\($0.target)\"/>" }
            .joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
        \(imageRels.isEmpty ? "" : "\n\(imageRels)")
        </Relationships>
        """
    }

    private static func editableSlideXML(page: EditablePage, widthEMU: Int64, heightEMU: Int64, imageRelationships: [EditableImageRelationship]) -> String {
        let relationshipByObjectID = Dictionary(uniqueKeysWithValues: imageRelationships.map { ($0.objectID, $0.relationshipID) })
        let objectXML = page.objects.enumerated().compactMap { offset, object in
            editableObjectXML(
                object,
                shapeID: offset + 2,
                page: page,
                widthEMU: widthEMU,
                heightEMU: heightEMU,
                imageRelationshipID: relationshipByObjectID[object.id]
            )
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld>
            <p:bg>
              <p:bgPr>\(backgroundFillXML(page))</p:bgPr>
            </p:bg>
            <p:spTree>
              <p:nvGrpSpPr>
                <p:cNvPr id="1" name=""/>
                <p:cNvGrpSpPr/>
                <p:nvPr/>
              </p:nvGrpSpPr>
              <p:grpSpPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="0" cy="0"/>
                  <a:chOff x="0" y="0"/>
                  <a:chExt cx="0" cy="0"/>
                </a:xfrm>
              </p:grpSpPr>
        \(objectXML)
            </p:spTree>
          </p:cSld>
          <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
        </p:sld>
        """
    }

    private static func editableObjectXML(
        _ object: EditableObject,
        shapeID: Int,
        page: EditablePage,
        widthEMU: Int64,
        heightEMU: Int64,
        imageRelationshipID: String?
    ) -> String? {
        guard object.width > 0.5, object.height > 0.5 else { return nil }

        switch object.kind {
        case "image":
            guard let imageRelationshipID else { return nil }
            return imageXML(object, shapeID: shapeID, page: page, widthEMU: widthEMU, heightEMU: heightEMU, relationshipID: imageRelationshipID)
        case "text":
            guard let text = object.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return textShapeXML(object, shapeID: shapeID, page: page, widthEMU: widthEMU, heightEMU: heightEMU, text: text)
        default:
            return shapeXML(object, shapeID: shapeID, page: page, widthEMU: widthEMU, heightEMU: heightEMU)
        }
    }

    private static func shapeXML(_ object: EditableObject, shapeID: Int, page: EditablePage, widthEMU: Int64, heightEMU: Int64) -> String {
        let name = xmlEscape(object.name ?? "Shape \(shapeID)")
        return """
              <p:sp>
                <p:nvSpPr>
                  <p:cNvPr id="\(shapeID)" name="\(name)"/>
                  <p:cNvSpPr/>
                  <p:nvPr/>
                </p:nvSpPr>
                \(shapePropertiesXML(object, page: page, widthEMU: widthEMU, heightEMU: heightEMU))
              </p:sp>
        """
    }

    private static func textShapeXML(_ object: EditableObject, shapeID: Int, page: EditablePage, widthEMU: Int64, heightEMU: Int64, text: String) -> String {
        let name = xmlEscape(object.name ?? "Text \(shapeID)")
        return """
              <p:sp>
                <p:nvSpPr>
                  <p:cNvPr id="\(shapeID)" name="\(name)"/>
                  <p:cNvSpPr txBox="1"/>
                  <p:nvPr/>
                </p:nvSpPr>
                \(shapePropertiesXML(object, page: page, widthEMU: widthEMU, heightEMU: heightEMU))
                \(textBodyXML(object, page: page, widthEMU: widthEMU, heightEMU: heightEMU, text: text))
              </p:sp>
        """
    }

    private static func imageXML(_ object: EditableObject, shapeID: Int, page: EditablePage, widthEMU: Int64, heightEMU: Int64, relationshipID: String) -> String {
        let name = xmlEscape(object.name ?? "Image \(shapeID)")
        return """
              <p:pic>
                <p:nvPicPr>
                  <p:cNvPr id="\(shapeID)" name="\(name)"/>
                  <p:cNvPicPr/>
                  <p:nvPr/>
                </p:nvPicPr>
                <p:blipFill>
                  <a:blip r:embed="\(relationshipID)"/>
                  <a:stretch><a:fillRect/></a:stretch>
                </p:blipFill>
                <p:spPr>
                  \(transformXML(object, page: page, widthEMU: widthEMU, heightEMU: heightEMU))
                  <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                  \(lineXML(color: object.borderColor, alpha: object.borderAlpha * object.opacity, width: object.borderWidth))
                  \(effectXML(object))
                </p:spPr>
              </p:pic>
        """
    }

    private static func shapePropertiesXML(_ object: EditableObject, page: EditablePage, widthEMU: Int64, heightEMU: Int64) -> String {
        """
                <p:spPr>
                  \(transformXML(object, page: page, widthEMU: widthEMU, heightEMU: heightEMU))
                  \(presetGeometryXML(for: object))
                  \(fillXML(color: object.fillColor, alpha: object.fillAlpha * object.opacity, gradient: object.fillGradient, opacity: object.opacity))
                  \(lineXML(color: object.borderColor, alpha: object.borderAlpha * object.opacity, width: object.borderWidth))
                  \(effectXML(object))
                </p:spPr>
        """
    }

    private static func transformXML(_ object: EditableObject, page: EditablePage, widthEMU: Int64, heightEMU: Int64) -> String {
        let x = scaledEMU(object.x, source: page.width, target: widthEMU)
        let y = scaledEMU(object.y, source: page.height, target: heightEMU)
        let width = max(1, scaledEMU(object.width, source: page.width, target: widthEMU))
        let height = max(1, scaledEMU(object.height, source: page.height, target: heightEMU))
        let rotation = Int((object.rotate * 60_000).rounded())
        let rotationAttribute = abs(rotation) > 0 ? " rot=\"\(rotation)\"" : ""

        return """
                  <a:xfrm\(rotationAttribute)>
                    <a:off x="\(x)" y="\(y)"/>
                    <a:ext cx="\(width)" cy="\(height)"/>
                  </a:xfrm>
        """
    }

    private static func textBodyXML(_ object: EditableObject, page: EditablePage, widthEMU: Int64, heightEMU: Int64, text: String) -> String {
        let alignment = pptAlignment(object.textAlign)
        let fontSize = max(100, Int((object.fontSize * 75).rounded()))
        let lineHeight = max(100, Int((object.lineHeight * 75).rounded()))
        let weight = Int(object.fontWeight?.trimmingCharacters(in: .letters.inverted) ?? "") ?? (object.fontWeight?.lowercased() == "bold" ? 700 : 400)
        let boldAttribute = weight >= 600 ? " b=\"1\"" : ""
        let italicAttribute = object.fontStyle?.lowercased().contains("italic") == true ? " i=\"1\"" : ""
        let family = xmlEscape(object.fontFamily?.isEmpty == false ? object.fontFamily! : "Arial")
        let textFill = solidFillXML(color: object.textColor ?? "111111", alpha: object.textAlpha * object.opacity)
        let paragraphs = text.components(separatedBy: .newlines)
            .map { line -> String in
                let safeLine = xmlEscape(line)
                return """
                    <a:p>
                      <a:pPr algn="\(alignment)"><a:lnSpc><a:spcPts val="\(lineHeight)"/></a:lnSpc></a:pPr>
                      <a:r>
                        <a:rPr lang="zh-CN" sz="\(fontSize)"\(boldAttribute)\(italicAttribute)>
                          \(textFill)
                          <a:latin typeface="\(family)"/>
                          <a:ea typeface="\(family)"/>
                        </a:rPr>
                        <a:t>\(safeLine)</a:t>
                      </a:r>
                    </a:p>
                """
            }
            .joined(separator: "\n")

        return """
                <p:txBody>
                  <a:bodyPr wrap="square" anchor="t" \(textInsetAttributes(object, page: page, widthEMU: widthEMU, heightEMU: heightEMU))/>\n                  <a:lstStyle/>
        \(paragraphs)
                </p:txBody>
        """
    }

    private static func textInsetAttributes(_ object: EditableObject, page: EditablePage, widthEMU: Int64, heightEMU: Int64) -> String {
        let left = max(0, scaledEMU(object.paddingLeft, source: page.width, target: widthEMU))
        let top = max(0, scaledEMU(object.paddingTop, source: page.height, target: heightEMU))
        let right = max(0, scaledEMU(object.paddingRight, source: page.width, target: widthEMU))
        let bottom = max(0, scaledEMU(object.paddingBottom, source: page.height, target: heightEMU))
        return "lIns=\"\(left)\" tIns=\"\(top)\" rIns=\"\(right)\" bIns=\"\(bottom)\""
    }

    private static func shapePreset(for object: EditableObject) -> String {
        let shortestSide = max(1, min(object.width, object.height))
        let aspectDelta = abs(object.width - object.height) / shortestSide
        if object.radius >= shortestSide * 0.45, aspectDelta < 0.2 {
            return "ellipse"
        }
        if object.radius > 2 {
            return "roundRect"
        }
        return "rect"
    }

    private static func presetGeometryXML(for object: EditableObject) -> String {
        let preset = shapePreset(for: object)
        guard preset == "roundRect" else {
            return "<a:prstGeom prst=\"\(preset)\"><a:avLst/></a:prstGeom>"
        }

        let shortestSide = max(1, min(object.width, object.height))
        let adjustment = min(50_000, max(1_000, Int(((object.radius / shortestSide) * 100_000).rounded())))
        return """
                  <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val \(adjustment)"/></a:avLst></a:prstGeom>
        """
    }

    private static func backgroundFillXML(_ page: EditablePage) -> String {
        if let gradient = gradientFillXML(page.backgroundGradient, opacity: 1) {
            return gradient
        }
        return solidFillXML(color: page.backgroundColor ?? "FFFFFF", alpha: page.backgroundAlpha)
    }

    private static func fillXML(color: String?, alpha: Double, gradient: EditableGradient?, opacity: Double) -> String {
        if let gradient = gradientFillXML(gradient, opacity: opacity) {
            return gradient
        }

        guard alpha > 0.01, let color = normalizedHexColor(color) else {
            return "<a:noFill/>"
        }
        return solidFillXML(color: color, alpha: alpha)
    }

    private static func gradientFillXML(_ gradient: EditableGradient?, opacity: Double) -> String? {
        guard let gradient, gradient.stops.count >= 2 else { return nil }
        let stops = gradient.stops
            .sorted { $0.position < $1.position }
            .compactMap { stop -> String? in
                guard let color = normalizedHexColor(stop.color) else { return nil }
                let alphaValue = Int((clamp(stop.alpha * opacity) * 100_000).rounded())
                let alphaXML = alphaValue < 100_000 ? "<a:alpha val=\"\(alphaValue)\"/>" : ""
                let position = Int((clamp(stop.position) * 100_000).rounded())
                return "<a:gs pos=\"\(position)\"><a:srgbClr val=\"\(color)\">\(alphaXML)</a:srgbClr></a:gs>"
            }
            .joined()

        guard !stops.isEmpty else { return nil }
        let angle = Int(((450 - gradient.angle).truncatingRemainder(dividingBy: 360) * 60_000).rounded())
        return """
                  <a:gradFill rotWithShape="1"><a:gsLst>\(stops)</a:gsLst><a:lin ang="\(angle)" scaled="1"/></a:gradFill>
        """
    }

    private static func effectXML(_ object: EditableObject) -> String {
        guard object.shadowBlur > 0.1 || object.shadowDistance > 0.1,
              object.shadowAlpha > 0.01,
              let color = normalizedHexColor(object.shadowColor) else {
            return ""
        }

        let blur = max(1, Int((object.shadowBlur * emuPerPixel).rounded()))
        let distance = max(0, Int((object.shadowDistance * emuPerPixel).rounded()))
        let direction = Int((object.shadowAngle * 60_000).rounded())
        let alphaValue = Int((clamp(object.shadowAlpha * object.opacity) * 100_000).rounded())
        let alphaXML = alphaValue < 100_000 ? "<a:alpha val=\"\(alphaValue)\"/>" : ""

        return """
                  <a:effectLst><a:outerShdw blurRad="\(blur)" dist="\(distance)" dir="\(direction)" algn="ctr" rotWithShape="0"><a:srgbClr val="\(color)">\(alphaXML)</a:srgbClr></a:outerShdw></a:effectLst>
        """
    }

    private static func lineXML(color: String?, alpha: Double, width: Double) -> String {
        guard width > 0.1, alpha > 0.01, let color = normalizedHexColor(color) else {
            return "<a:ln><a:noFill/></a:ln>"
        }

        let lineWidth = max(1, Int((width * emuPerPixel).rounded()))
        return """
                  <a:ln w="\(lineWidth)">\(solidFillXML(color: color, alpha: alpha))</a:ln>
        """
    }

    private static func solidFillXML(color: String, alpha: Double) -> String {
        let hex = normalizedHexColor(color) ?? "FFFFFF"
        let alphaValue = Int((clamp(alpha) * 100_000).rounded())
        let alphaXML = alphaValue < 100_000 ? "<a:alpha val=\"\(alphaValue)\"/>" : ""
        return "<a:solidFill><a:srgbClr val=\"\(hex)\">\(alphaXML)</a:srgbClr></a:solidFill>"
    }

    private static func pptAlignment(_ value: String?) -> String {
        switch value?.lowercased() {
        case "center", "-webkit-center":
            return "ctr"
        case "right", "end", "-webkit-right":
            return "r"
        case "justify":
            return "just"
        default:
            return "l"
        }
    }

    private static func scaledEMU(_ value: Double, source: Double, target: Int64) -> Int64 {
        guard source > 0 else { return Int64((value * emuPerPixel).rounded()) }
        return Int64(((value / source) * Double(target)).rounded())
    }

    private static func normalizedHexColor(_ value: String?) -> String? {
        guard var value else { return nil }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }
        guard value.count == 6, value.allSatisfy({ $0.isHexDigit }) else { return nil }
        return value.uppercased()
    }

    private static func clamp(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func imagePayload(for source: String, baseURL: URL?) -> ImagePayload? {
        if source.lowercased().hasPrefix("data:") {
            return dataURLImagePayload(source)
        }

        guard let url = URL(string: source, relativeTo: baseURL)?.absoluteURL else {
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        let fileExtension = normalizedImageExtension(url.pathExtension)
            ?? inferredImageExtension(from: data)
            ?? "png"
        return pptCompatibleImagePayload(data: data, fileExtension: fileExtension)
    }

    private static func dataURLImagePayload(_ source: String) -> ImagePayload? {
        guard let commaIndex = source.firstIndex(of: ",") else { return nil }
        let metadataStart = source.index(source.startIndex, offsetBy: 5)
        let metadata = String(source[metadataStart..<commaIndex]).lowercased()
        let payload = String(source[source.index(after: commaIndex)...])

        let data: Data?
        if metadata.contains(";base64") {
            data = Data(base64Encoded: payload)
        } else {
            data = payload.removingPercentEncoding?.data(using: .utf8)
        }

        guard let data else { return nil }
        let mimeType = metadata.components(separatedBy: ";").first ?? ""
        let fileExtension = imageExtension(forMIMEType: mimeType)
            ?? inferredImageExtension(from: data)
            ?? "png"
        return pptCompatibleImagePayload(data: data, fileExtension: fileExtension)
    }

    private static func pptCompatibleImagePayload(data: Data, fileExtension: String) -> ImagePayload {
        let normalizedExtension = fileExtension.lowercased()
        if ["svg", "webp"].contains(normalizedExtension),
           let pngData = rasterizedPNG(from: data) {
            return ImagePayload(data: pngData, fileExtension: "png")
        }

        return ImagePayload(data: data, fileExtension: normalizedExtension)
    }

    private static func rasterizedPNG(from data: Data) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        let naturalWidth = max(1, image.size.width)
        let naturalHeight = max(1, image.size.height)
        let scale = min(2, max(1, 2400 / max(naturalWidth, naturalHeight)))
        let pixelsWide = max(1, Int((naturalWidth * scale).rounded()))
        let pixelsHigh = max(1, Int((naturalHeight * scale).rounded()))

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: CGFloat(pixelsWide), height: CGFloat(pixelsHigh)).fill()
        image.draw(
            in: NSRect(x: 0, y: 0, width: CGFloat(pixelsWide), height: CGFloat(pixelsHigh)),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        return bitmap.representation(using: .png, properties: [:])
    }

    private static func imageExtension(forMIMEType mimeType: String) -> String? {
        switch mimeType.lowercased() {
        case "image/png":
            return "png"
        case "image/jpeg", "image/jpg":
            return "jpg"
        case "image/gif":
            return "gif"
        case "image/svg+xml":
            return "svg"
        case "image/webp":
            return "webp"
        default:
            return nil
        }
    }

    private static func normalizedImageExtension(_ fileExtension: String) -> String? {
        switch fileExtension.lowercased() {
        case "png":
            return "png"
        case "jpg", "jpeg":
            return "jpg"
        case "gif":
            return "gif"
        case "svg", "svgz":
            return "svg"
        case "webp":
            return "webp"
        default:
            return nil
        }
    }

    private static func inferredImageExtension(from data: Data) -> String? {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }
        if data.starts(with: [0x47, 0x49, 0x46]) {
            return "gif"
        }
        if let prefix = String(data: data.prefix(256), encoding: .utf8),
           prefix.lowercased().contains("<svg") {
            return "svg"
        }
        return nil
    }

    private static func slideMasterRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
        </Relationships>
        """
    }

    private static func slideLayoutRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
        </Relationships>
        """
    }

    private static func slideMasterXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld>
          <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
          <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
          <p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles>
        </p:sldMaster>
        """
    }

    private static func slideLayoutXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">
          <p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld>
          <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
        </p:sldLayout>
        """
    }

    private static func themeXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Chiselo">
          <a:themeElements>
            <a:clrScheme name="Chiselo">
              <a:dk1><a:srgbClr val="15151B"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
              <a:dk2><a:srgbClr val="4B3B78"/></a:dk2><a:lt2><a:srgbClr val="F7F4FB"/></a:lt2>
              <a:accent1><a:srgbClr val="6D50B4"/></a:accent1><a:accent2><a:srgbClr val="C62828"/></a:accent2>
              <a:accent3><a:srgbClr val="FFC107"/></a:accent3><a:accent4><a:srgbClr val="6A6578"/></a:accent4>
              <a:accent5><a:srgbClr val="DED5EE"/></a:accent5><a:accent6><a:srgbClr val="FFFFFF"/></a:accent6>
              <a:hlink><a:srgbClr val="6D50B4"/></a:hlink><a:folHlink><a:srgbClr val="4B3B78"/></a:folHlink>
            </a:clrScheme>
            <a:fontScheme name="Chiselo"><a:majorFont><a:latin typeface="Arial"/></a:majorFont><a:minorFont><a:latin typeface="Arial"/></a:minorFont></a:fontScheme>
            <a:fmtScheme name="Chiselo"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme>
          </a:themeElements>
          <a:objectDefaults/>
          <a:extraClrSchemeLst/>
        </a:theme>
        """
    }

    private static func slideXML(index: Int, widthEMU: Int64, heightEMU: Int64) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld>
            <p:spTree>
              <p:nvGrpSpPr>
                <p:cNvPr id="1" name=""/>
                <p:cNvGrpSpPr/>
                <p:nvPr/>
              </p:nvGrpSpPr>
              <p:grpSpPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="0" cy="0"/>
                  <a:chOff x="0" y="0"/>
                  <a:chExt cx="0" cy="0"/>
                </a:xfrm>
              </p:grpSpPr>
              <p:pic>
                <p:nvPicPr>
                  <p:cNvPr id="2" name="Chiselo page \(index)"/>
                  <p:cNvPicPr/>
                  <p:nvPr/>
                </p:nvPicPr>
                <p:blipFill>
                  <a:blip r:embed="rId1"/>
                  <a:stretch><a:fillRect/></a:stretch>
                </p:blipFill>
                <p:spPr>
                  <a:xfrm>
                    <a:off x="0" y="0"/>
                    <a:ext cx="\(widthEMU)" cy="\(heightEMU)"/>
                  </a:xfrm>
                  <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                </p:spPr>
              </p:pic>
            </p:spTree>
          </p:cSld>
          <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
        </p:sld>
        """
    }

    enum ExportError: LocalizedError {
        case noPages
        case pngEncodingFailed
        case imageDecodeFailed
        case pdfCreationFailed
        case pptxZipFailed
        case editableExtractionFailed
        case editableExtractionFailedWithMessage(String)

        var errorDescription: String? {
            switch self {
            case .noPages:
                return "No pages or slides were found."
            case .pngEncodingFailed:
                return "Could not encode page snapshot as PNG."
            case .imageDecodeFailed:
                return "Could not decode rendered page image."
            case .pdfCreationFailed:
                return "Could not create PDF."
            case .pptxZipFailed:
                return "Could not package PPTX."
            case .editableExtractionFailed:
                return "Could not extract editable objects from the HTML document."
            case .editableExtractionFailedWithMessage(let message):
                return "Could not extract editable objects from the HTML document: \(message)"
            }
        }
    }
}
