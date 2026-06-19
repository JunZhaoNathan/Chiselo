import AppKit
import Foundation
import WebKit

final class DirectHTMLEditorShellStabilityTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let outputURL: URL
    private var webView: WKWebView?

    init(editorURL: URL, outputURL: URL) {
        self.editorURL = editorURL
        self.outputURL = outputURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "editorShellStability")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1360, height: 900), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 14) { [weak self] in
            self?.fail("Timed out waiting for editor shell stability result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let base64 = Data(Self.fixtureHTML.utf8).base64EncodedString()
        let script = """
        void (async () => {
          const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));
          const editor = window.ChiseloEditor;
          await editor.openHTMLFromBase64('\(base64)', '');
          await sleep(360);

          const frameDoc = document.querySelector('iframe.html-frame')?.contentDocument;
          if (!frameDoc) throw new Error('HTML frame document is not available.');

          const rectOf = (selector) => {
            const node = frameDoc.querySelector(selector);
            if (!node) throw new Error(`Missing selector ${selector}`);
            const rect = node.getBoundingClientRect();
            return {
              x: Math.round(rect.x),
              y: Math.round(rect.y),
              width: Math.round(rect.width),
              height: Math.round(rect.height),
              right: Math.round(rect.right),
              bottom: Math.round(rect.bottom)
            };
          };

          const selectedStyle = (selector) => frameDoc.querySelector(selector)?.getAttribute('style') || '';
          const aiStayedRight = (mainRect, aiRect) => aiRect.x >= mainRect.right - 3 && aiRect.y < mainRect.bottom - 30;
          const noInlineSize = (styleText) => !/\\bwidth\\s*:/.test(styleText) && !/\\bheight\\s*:/.test(styleText);

          const before = {
            shell: rectOf('.app-shell'),
            main: rectOf('.editor-workspace'),
            code: rectOf('.code-pane'),
            ai: rectOf('.ai-collab')
          };
          const initialSidebarRight = aiStayedRight(before.main, before.ai);

          const codeSelection = editor.selectHTML('.code-pane');
          if (!codeSelection) throw new Error('Could not select code pane.');
          editor.command('setLayoutTransform');
          editor.updateElement({
            id: codeSelection.id,
            x: codeSelection.x + 18,
            y: codeSelection.y + 10,
            w: codeSelection.w + 120,
            h: codeSelection.h + 64,
            style: {
              background: 'rgb(18, 27, 42)',
              borderColor: 'rgb(20, 184, 166)',
              borderWidth: 1
            }
          });
          await sleep(220);

          const afterCodeAdjust = {
            shell: rectOf('.app-shell'),
            main: rectOf('.editor-workspace'),
            code: rectOf('.code-pane'),
            ai: rectOf('.ai-collab'),
            codeStyle: selectedStyle('.code-pane'),
            mainStyle: selectedStyle('.editor-workspace')
          };

          const shellSelection = editor.selectHTML('.app-shell');
          if (!shellSelection) throw new Error('Could not select app shell.');
          editor.command('setLayoutTransform');
          editor.updateElement({
            id: shellSelection.id,
            x: shellSelection.x,
            y: shellSelection.y,
            w: shellSelection.w + 180,
            h: shellSelection.h + 90
          });
          await sleep(220);

          const afterShellAdjust = {
            shell: rectOf('.app-shell'),
            main: rectOf('.editor-workspace'),
            code: rectOf('.code-pane'),
            ai: rectOf('.ai-collab'),
            shellStyle: selectedStyle('.app-shell'),
            mainStyle: selectedStyle('.editor-workspace'),
            codeStyle: selectedStyle('.code-pane')
          };

          const titleSelection = editor.selectHTML('.ai-collab h2');
          if (!titleSelection) throw new Error('Could not select AI panel title.');
          editor.setSelectedHTMLText('AI 协作区保持右侧');
          await sleep(180);

          const diagnostics = editor.getImportDiagnostics();
          const exported = editor.exportHTML();
          const sourceClean = diagnostics.cleanExport === true
            && diagnostics.exportArtifactCount === 0
            && !exported.includes('data-chiselo')
            && !exported.includes('__chiselo')
            && exported.includes('AI 协作区保持右侧');

          const assertions = {
            initialSidebarRight,
            codeAdjustSidebarRight: aiStayedRight(afterCodeAdjust.main, afterCodeAdjust.ai),
            shellAdjustSidebarRight: aiStayedRight(afterShellAdjust.main, afterShellAdjust.ai),
            shellFlowSizePreserved: noInlineSize(afterShellAdjust.shellStyle),
            mainFlowSizePreserved: noInlineSize(afterShellAdjust.mainStyle),
            codePaneSizePreserved: noInlineSize(afterCodeAdjust.codeStyle),
            sourceClean,
            visualChangeReported: Number(diagnostics.visualChangeCount || 0) >= 1,
            visualChangeItemsAvailable: Array.isArray(diagnostics.visualChangeItems) && diagnostics.visualChangeItems.length >= 1
          };

          const failed = Object.entries(assertions).filter(([, value]) => !value);
          if (failed.length) {
            throw new Error(JSON.stringify({
              failed,
              assertions,
              before,
              afterCodeAdjust,
              afterShellAdjust,
              diagnostics,
              exportedPreview: exported.slice(0, 2000)
            }));
          }

          window.webkit.messageHandlers.editorShellStability.postMessage({
            type: 'result',
            assertions,
            before,
            afterCodeAdjust,
            afterShellAdjust,
            diagnostics: {
              cleanExport: diagnostics.cleanExport,
              exportArtifactCount: diagnostics.exportArtifactCount,
              visualChangeCount: diagnostics.visualChangeCount,
              visualChangeItems: diagnostics.visualChangeItems,
              visualChangeCanvasWidth: diagnostics.visualChangeCanvasWidth,
              visualChangeCanvasHeight: diagnostics.visualChangeCanvasHeight,
              responsiveChangeCount: diagnostics.responsiveChangeCount,
              responsiveLayoutRiskCount: diagnostics.responsiveLayoutRiskCount
            }
          });
        })().catch(error => {
          window.webkit.messageHandlers.editorShellStability.postMessage({
            type: 'error',
            message: String(error && error.message || error),
            stack: String(error && error.stack || '')
          });
        });
        """

        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error {
                self?.fail("JavaScript evaluation failed: \(error.localizedDescription)")
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "editorShellStability", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown editor shell stability error.")
        }

        do {
            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: outputURL)
            if let string = String(data: data, encoding: .utf8) {
                print(string)
            }
            print("Wrote: \(outputURL.path)")
            exit(0)
        } catch {
            fail("Could not write editor shell stability report: \(error.localizedDescription)")
        }
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML editor shell stability test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html lang="zh-CN">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Editor Shell Stability Fixture</title>
      <style>
        :root {
          --bg: #0b111c;
          --panel: #111827;
          --panel-2: #0f172a;
          --line: #273449;
          --muted: #94a3b8;
          --text: #e5eefb;
          --accent: #14b8a6;
          --blue: #2f7df6;
          --warn: #f59e0b;
          font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif;
        }
        * { box-sizing: border-box; }
        html, body { margin: 0; min-height: 100%; background: #eaf1fb; }
        body { padding: 40px; color: var(--text); }
        .app-shell {
          width: 1180px;
          min-height: 660px;
          display: flex;
          align-items: stretch;
          overflow: hidden;
          border: 1px solid #d3dfef;
          border-radius: 8px;
          background: var(--bg);
          box-shadow: 0 26px 60px rgba(15, 23, 42, .22);
        }
        .project-sidebar {
          flex: 0 0 260px;
          min-width: 230px;
          background: #0c1423;
          border-right: 1px solid var(--line);
          padding: 16px;
        }
        .workspace-stack {
          flex: 1 1 auto;
          min-width: 0;
          display: flex;
          flex-direction: column;
          border-right: 1px solid var(--line);
        }
        .top-tabs {
          height: 46px;
          display: flex;
          align-items: center;
          gap: 8px;
          padding: 0 14px;
          border-bottom: 1px solid var(--line);
          background: #0b1220;
        }
        .tab {
          padding: 8px 12px;
          border: 1px solid var(--line);
          border-radius: 6px 6px 0 0;
          color: var(--muted);
          font-size: 12px;
        }
        .tab.active { color: white; border-color: #335b96; background: #13233b; }
        .editor-workspace {
          flex: 1 1 auto;
          min-width: 0;
          display: grid;
          grid-template-rows: minmax(340px, 1fr) minmax(150px, .42fr);
          gap: 10px;
          padding: 12px;
          background: var(--panel);
        }
        .code-pane,
        .activity-log {
          min-width: 0;
          overflow: hidden;
          border: 1px solid var(--line);
          background: var(--panel-2);
          border-radius: 6px;
        }
        .pane-head {
          height: 34px;
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 0 12px;
          border-bottom: 1px solid var(--line);
          color: var(--muted);
          font-size: 12px;
        }
        pre {
          margin: 0;
          padding: 18px;
          color: #d8e4f8;
          font: 13px/1.62 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
          white-space: pre-wrap;
        }
        .line-no { color: #64748b; display: inline-block; width: 28px; }
        .token-key { color: #f59e0b; }
        .token-class { color: #5eead4; }
        .ai-collab {
          flex: 0 0 340px;
          min-width: 300px;
          display: flex;
          flex-direction: column;
          gap: 14px;
          padding: 16px;
          background: #101a2b;
        }
        .ai-collab h2,
        .project-sidebar h2 {
          margin: 0 0 12px;
          font-size: 16px;
          letter-spacing: 0;
        }
        .file-item,
        .ai-message,
        .suggestion {
          border: 1px solid var(--line);
          border-radius: 6px;
          padding: 10px 12px;
          background: rgba(255,255,255,.025);
          color: var(--muted);
          font-size: 13px;
          line-height: 1.5;
        }
        .file-item.active { color: white; border-color: var(--blue); background: rgba(47,125,246,.16); }
        .ai-message.good { border-color: rgba(20,184,166,.55); color: #ccfbf1; }
        .ai-message.warn { border-color: rgba(245,158,11,.55); color: #fde68a; }
        .run-button {
          margin-top: auto;
          align-self: flex-end;
          padding: 9px 14px;
          border: 1px solid rgba(20,184,166,.7);
          border-radius: 6px;
          color: #ccfbf1;
          background: rgba(20,184,166,.14);
          font-weight: 700;
        }
        @media (max-width: 760px) {
          body { padding: 18px; }
          .app-shell {
            width: min(100%, 1180px);
            flex-wrap: wrap;
          }
          .project-sidebar,
          .workspace-stack,
          .ai-collab {
            flex-basis: 100%;
            min-width: 0;
          }
          .editor-workspace {
            grid-template-rows: auto auto;
          }
        }
      </style>
    </head>
    <body>
      <main class="app-shell">
        <aside class="project-sidebar">
          <h2>PROJECT</h2>
          <div class="file-item active">index.html</div>
          <div class="file-item">styles.css</div>
          <div class="file-item">components/card.html</div>
          <div class="file-item">assets/logo.svg</div>
        </aside>
        <section class="workspace-stack">
          <nav class="top-tabs">
            <span class="tab active">index.html</span>
            <span class="tab">预览</span>
            <span class="tab">导出前复核</span>
          </nav>
          <section class="editor-workspace">
            <article class="code-pane">
              <div class="pane-head"><span>HTML</span><span>已选中 DIV · 1130 x 571</span></div>
              <pre><span class="line-no">01</span>&lt;<span class="token-key">section</span> class="<span class="token-class">hero-grid</span>"&gt;
    <span class="line-no">02</span>  &lt;div class="<span class="token-class">copy-block</span>"&gt;精准修改已有 HTML&lt;/div&gt;
    <span class="line-no">03</span>  &lt;aside class="<span class="token-class">ai-panel</span>"&gt;修改建议和风险复核&lt;/aside&gt;
    <span class="line-no">04</span>&lt;/<span class="token-key">section</span>&gt;</pre>
            </article>
            <article class="activity-log">
              <div class="pane-head"><span>导出前检查</span><span>3 项通过</span></div>
              <pre><span class="line-no">01</span>源代码干净：通过
    <span class="line-no">02</span>视觉变更地图：2 个对象
    <span class="line-no">03</span>响应式风险：未破坏三栏布局</pre>
            </article>
          </section>
        </section>
        <aside class="ai-collab">
          <h2>AI 协作区</h2>
          <div class="ai-message good">已识别当前对象属于 flex/grid 工作区，优先使用 transform，避免写死布局宽高。</div>
          <div class="suggestion">建议先备份原始 HTML，再导出修改后的文件。</div>
          <div class="ai-message warn">如果用户拖动外层容器，右侧面板必须保持在同一行。</div>
          <button class="run-button">导出前复核</button>
        </aside>
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
let outputURL = projectRoot
    .appendingPathComponent("outputs", isDirectory: true)
    .appendingPathComponent("editor-shell-stability-report.json")

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let test = DirectHTMLEditorShellStabilityTest(editorURL: editorURL, outputURL: outputURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
