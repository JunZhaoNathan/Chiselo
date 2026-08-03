import AppKit
import Foundation

final class ExportRuntimeSafetyTest: NSObject {
    @MainActor private var renderer: HTMLRenderExporter?

    func run() {
        Task { @MainActor in
            renderer = HTMLRenderExporter(html: Self.fixtureHTML, baseURL: nil)
            renderer?.renderPages { [weak self] result in
                Task { @MainActor in
                    self?.renderer = nil
                    do {
                        let page = try result.get().first
                        guard let page,
                              let image = NSBitmapImageRep(data: page.pngData),
                              let color = image.colorAt(x: 4, y: 4) else {
                            self?.fail("Safe export did not produce an inspectable page image.")
                            return
                        }

                        guard color.greenComponent > color.redComponent else {
                            self?.fail("Page script executed during safe export. pixel=\(color)")
                            return
                        }

                        print("Safe export runtime test OK")
                        exit(0)
                    } catch {
                        self?.fail("Safe export failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func fail(_ message: String) -> Never {
        fputs("Export runtime safety test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html><head><style>html, body { margin: 0; } .page { width: 320px; height: 240px; background: rgb(0, 220, 0); }</style></head>
    <body><main class="page" id="target"></main><script>document.getElementById('target').style.background = 'rgb(220, 0, 0)';</script></body></html>
    """
}

@main
struct ExportRuntimeSafetyTestRunner {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let test = ExportRuntimeSafetyTest()
        DispatchQueue.main.async { test.run() }
        app.run()
    }
}
