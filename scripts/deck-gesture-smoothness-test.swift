import AppKit
import Foundation
import WebKit

final class DeckGestureSmoothnessTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?
    private var didStart = false
    private var didInstallChiseloHandler = false
    private var isMeasuringSelectionBridge = false
    private var selectionMessageCount = 0
    private var startSelection: [String: Any]?
    private var preparationAttempts = 0

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "deckGesture")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 860), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.installChiseloHandlerIfNeeded()
            self?.scheduleGestureStart()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self else { return }
            fail("Timed out waiting for deck gesture result. didStart=\(didStart), didInstallChiseloHandler=\(didInstallChiseloHandler)")
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }

        if message.name == "chiselo" {
            handleEditorMessage(body)
            return
        }

        guard message.name == "deckGesture", let type = body["type"] as? String else { return }

        switch type {
        case "error":
            fail(body["message"] as? String ?? "Unknown JavaScript error.")
        default:
            break
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.installChiseloHandlerIfNeeded()
            self?.scheduleGestureStart()
        }
    }

    private func handleEditorMessage(_ body: [String: Any]) {
        if body["type"] as? String == "selectionChanged", isMeasuringSelectionBridge {
            selectionMessageCount += 1
        }

    }

    private func installChiseloHandlerIfNeeded() {
        guard !didInstallChiseloHandler else { return }
        didInstallChiseloHandler = true
        webView?.configuration.userContentController.add(self, name: "chiselo")
    }

    private func scheduleGestureStart() {
        guard !didStart else { return }
        didStart = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.runGesture()
        }
    }

    private func runGesture() {
        let script = """
        (() => {
          const editor = window.ChiseloEditor;
          if (!editor) return null;
          const startSelection = editor.selectElementById('title');
          if (!startSelection) throw new Error('Could not select default title element.');

          const target = document.querySelector('[data-id="title"]');
          if (!target) throw new Error('Title element node not found.');
          const rect = target.getBoundingClientRect();
          const startX = rect.left + Math.min(32, Math.max(8, rect.width / 4));
          const startY = rect.top + Math.min(24, Math.max(8, rect.height / 2));
          window.__chiseloDeckGestureTest = { startSelection, startX, startY, pointerId: 61 };
          return { startSelection, startX, startY };
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self else { return }
            if let error {
                fail("Prepare gesture script failed: \(error.localizedDescription)")
            }

            guard let payload = result as? [String: Any] else {
                self.retryGesturePreparation()
                return
            }

            guard let startSelection = payload["startSelection"] as? [String: Any] else {
                fail("Prepare gesture script returned an invalid payload.")
            }

            self.startSelection = startSelection
            runPointerSequence()
        }
    }

    private func retryGesturePreparation() {
        preparationAttempts += 1
        guard preparationAttempts <= 30 else {
            fail("ChiseloEditor did not become ready after \(preparationAttempts) attempts.")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.runGesture()
        }
    }

    private func runPointerSequence() {
        isMeasuringSelectionBridge = true
        selectionMessageCount = 0

        let script = """
        (() => {
          const state = window.__chiseloDeckGestureTest;
          if (!state) throw new Error('Deck gesture state missing.');
          const target = document.querySelector('[data-id="title"]');
          if (!target) throw new Error('Title element node not found for pointer sequence.');
          const { startX, startY, pointerId } = state;
          target.dispatchEvent(new PointerEvent('pointerdown', {
            bubbles: true,
            cancelable: true,
            button: 0,
            buttons: 1,
            pointerId,
            clientX: startX,
            clientY: startY
          }));

          for (let index = 1; index <= 12; index += 1) {
            document.dispatchEvent(new PointerEvent('pointermove', {
              bubbles: true,
              cancelable: true,
              button: 0,
              buttons: 1,
              pointerId,
              clientX: startX + index * 5,
              clientY: startY + index * 3
            }));
          }

          document.dispatchEvent(new PointerEvent('pointerup', {
            bubbles: true,
            cancelable: true,
            button: 0,
            buttons: 0,
            pointerId,
            clientX: startX + 60,
            clientY: startY + 36
          }));
          return true;
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] _, error in
            guard let self else { return }
            if let error {
                fail("Pointer sequence script failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.finishGesture()
            }
        }
    }

    private func finishGesture() {
        let script = "window.ChiseloEditor?.getSelection();"

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self else { return }
            isMeasuringSelectionBridge = false

            if let error {
                fail("Final selection script failed: \(error.localizedDescription)")
            }

            guard let startSelection,
                  let finalSelection = result as? [String: Any],
                  let startX = bridgeDouble(startSelection["x"]),
                  let startY = bridgeDouble(startSelection["y"]),
                  let finalX = bridgeDouble(finalSelection["x"]),
                  let finalY = bridgeDouble(finalSelection["y"]),
                  finalSelection["id"] as? String == "title" else {
                fail("Final selection payload is invalid: \(String(describing: result))")
            }

            guard finalX > startX + 20, finalY > startY + 10 else {
                fail("Deck drag did not move enough. start=\(startSelection), final=\(finalSelection)")
            }
            guard selectionMessageCount > 0 else {
                fail("Deck drag did not emit selection bridge updates.")
            }
            guard selectionMessageCount <= 8 else {
                fail("Deck drag emitted too many selection bridge updates: \(selectionMessageCount)")
            }

            let output: [String: Any] = [
                "type": "result",
                "selectionMessageCount": selectionMessageCount,
                "start": startSelection,
                "final": finalSelection
            ]

            if let data = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]),
               let string = String(data: data, encoding: .utf8) {
                print(string)
            }
            exit(0)
        }
    }

    private func bridgeDouble(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            let double = number.doubleValue
            return double.isFinite ? double : nil
        case let double as Double:
            return double.isFinite ? double : nil
        default:
            return nil
        }
    }

    private func fail(_ message: String) -> Never {
        fputs("Deck gesture smoothness test failed: \(message)\n", stderr)
        exit(1)
    }
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = projectRoot
    .appendingPathComponent("Chiselo")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Editor")
    .appendingPathComponent("index.html")

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let test = DeckGestureSmoothnessTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
