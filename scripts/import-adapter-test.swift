import AppKit
import Foundation
import WebKit

final class ImportAdapterTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "adapter")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1400, height: 900), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let html = """
        <style>
          .pseudo-source::before {
            content: "AUTO";
            display: inline-block;
            padding: 4px 8px;
            border-radius: 12px;
            background: #0a84ff;
            color: white;
            font-weight: 800;
          }
        </style>
        <section class=slide style="position:relative;width:960px;height:540px">
          <h1>Adapter smoke</h1>
          <p class=pseudo-source> pseudo text host</p>
          <div class=gradient-box style="position:absolute;left:220px;top:130px;width:160px;height:80px;border-radius:18px;background:linear-gradient(135deg, #ff0066 0%, rgba(10, 132, 255, 0.72) 100%)"></div>
          <img class=bad src="missing-chiselo-image.png" style="width:180px;height:90px">
          <svg class=mark width=80 height=40><rect width=80 height=40 fill="#6a50ad"/></svg>
          <table id=spanTable border=1 cellpadding=2>
            <tr><td class=merged colspan=2>merged</td><td>C</td></tr>
            <tr><td>A</td><td>B</td><td>C</td></tr>
          </table>
        </section>
        """

        guard let data = html.data(using: .utf8) else {
            fail("Could not encode fixture.")
        }

        let base64 = data.base64EncodedString()
        let script = """
        void (async () => {
          const editor = window.ChiseloEditor;
          await editor.openHTMLFromBase64('\(base64)', '');
          await new Promise(resolve => setTimeout(resolve, 350));
          const before = editor.getImportDiagnostics();
          const selectedPPTXReviewTarget = editor.selectHTMLById(before.pptxReviewElementId || '');
          const selectedSecondPPTXReviewTarget = editor.selectHTMLById(before.pptxReviewElementIds?.[1] || before.pptxReviewElementId || '');
          editor.setBackdropStyle('grid');
          const gridBackdropApplied = document.documentElement.dataset.backdrop === 'grid';
          editor.setBackdropStyle('dots');
          const dotsBackdropApplied = document.documentElement.dataset.backdrop === 'dots';
          editor.setBackdropStyle('clean');
          const cleanBackdropApplied = document.documentElement.dataset.backdrop === 'clean';

          editor.selectHTML('#spanTable .merged');
          const selectedBefore = editor.getSelection();
          const htmlTree = editor.getHTMLTree();
          const pageFrames = editor.getPageFrames();
          const pageBoundaryCount = document.querySelectorAll('.page-boundary').length;

          editor.selectHTML('.gradient-box');
          const boxBeforeStyle = editor.getSelection();
          editor.updateElement({
            ...boxBeforeStyle,
            style: {
              ...(boxBeforeStyle.style || {}),
              fill: '#fff6d8',
              stroke: '#0a84ff',
              strokeWidth: 3,
              radius: 16,
              shadow: '0 10px 24px rgba(15, 23, 42, 0.16)',
              textAlign: 'center'
            }
          });
          const boxAfterStyle = editor.getSelection();
          const boxStyledExport = editor.exportHTML();

          editor.selectHTML('img.bad');
          const imageBeforeStyle = editor.getSelection();
          editor.updateElement({
            ...imageBeforeStyle,
            style: {
              ...(imageBeforeStyle.style || {}),
              objectFit: 'contain',
              radius: 12,
              shadow: '0 10px 24px rgba(15, 23, 42, 0.16)'
            }
          });
          const imageAfterStyle = editor.getSelection();
          const imageStyledExport = editor.exportHTML();

          editor.selectHTML('#spanTable .merged');
          editor.command('tableAddColumnAfter');
          const afterAdd = editor.exportHTML();
          const afterAddDiagnostics = editor.getImportDiagnostics();
          const afterAddIssueKinds = new Set((afterAddDiagnostics.issues || []).map(issue => issue.kind));

          editor.command('tableDeleteColumn');
          const afterDelete = editor.exportHTML();
          const frozenDeck = await editor.importHTMLFromBase64('\(base64)', '');
          const frozenJSON = JSON.stringify(frozenDeck);
          const frozenExport = editor.exportHTML();
          const firstFrozenElement = frozenDeck.slides?.[0]?.elements?.[0];
          const selectedFrozenElement = firstFrozenElement ? editor.selectElementById(firstFrozenElement.id) : null;

          const minimalHTML = '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>Minimal</title></head><body><main><h1>Minimal diagnostics fixture</h1><p>No images, media, SVG, or tables.</p></main></body></html>';
          await editor.openHTMLFromBase64(btoa(minimalHTML), '');
          const minimalDiagnostics = editor.getImportDiagnostics();

          const assertions = {
            fragmentWrapped: editor.exportHTML().includes('<html'),
            imageDetected: before.imageCount === 1,
            brokenImageDetected: before.brokenImages === 1,
            svgDetected: before.svgCount === 1,
            tableDetected: before.tableCount === 1,
            selectedCellSemantic: selectedBefore.semanticRole === 'table-cell' && selectedBefore.semanticLabel === '单元格',
            treeSemanticPage: htmlTree.some(node => node.semanticRole === 'page' && node.semanticLabel === '页面'),
            pageFrameDetected: pageFrames.length === 1 && pageFrames[0].w >= 900 && pageFrames[0].h >= 500,
            pageBoundaryRendered: pageBoundaryCount === pageFrames.length,
            backdropSwitcherWorks: gridBackdropApplied && dotsBackdropApplied && cleanBackdropApplied,
            stylePanelBoxWriteback: boxAfterStyle.style.radius === 16 && boxAfterStyle.style.strokeWidth === 3,
            stylePanelShadowExported: /box-shadow:/i.test(boxStyledExport) && boxStyledExport.includes('24px'),
            stylePanelTextAlignExported: /text-align:\\s*center/i.test(boxStyledExport),
            stylePanelImageFitWriteback: imageAfterStyle.style.objectFit === 'contain',
            stylePanelImageFitExported: /object-fit:\\s*contain/i.test(imageStyledExport),
            pptxMappingCountsDetected: before.pptxTextObjectCount >= 1 && before.pptxImageObjectCount === 1 && before.pptxReviewObjectCount >= 1,
            pptxMappingTargetsDetected: [before.pptxTextElementId, before.pptxImageElementId, before.pptxReviewElementId].every(value => typeof value === 'string' && value.length > 0),
            pptxMappingTargetListsDetected: Array.isArray(before.pptxReviewElementIds) && before.pptxReviewElementIds.length >= 2 && Array.isArray(before.pptxTextElementIds) && before.pptxTextElementIds.length >= 1,
            pptxMappingReviewTargetSelectable: Boolean(selectedPPTXReviewTarget && selectedPPTXReviewTarget.id === before.pptxReviewElementId),
            pptxMappingSecondReviewTargetSelectable: Boolean(selectedSecondPPTXReviewTarget && before.pptxReviewElementIds.includes(selectedSecondPPTXReviewTarget.id)),
            spanTableDetected: before.spanTableCount === 1,
            mergedColumnExpanded: afterAdd.includes('colspan="3"'),
            mergedColumnRestored: afterDelete.includes('colspan="2"'),
            diagnosticsRemainClean: afterAddDiagnostics.cleanExport === true,
            visualDiffDetected: afterAddDiagnostics.visualChangeCount >= 1 && afterAddIssueKinds.has('visual-change'),
            visualDiffTargetClickable: typeof afterAddDiagnostics.visualChangeElementId === 'string' && afterAddDiagnostics.visualChangeElementId.length > 0,
            visualDiffTargetListDetected: Array.isArray(afterAddDiagnostics.visualChangeElementIds) && afterAddDiagnostics.visualChangeElementIds.length >= 1,
            visualDiffMapItemsDetected: Array.isArray(afterAddDiagnostics.visualChangeItems) && afterAddDiagnostics.visualChangeItems.length >= 1 && typeof afterAddDiagnostics.visualChangeItems[0].kind === 'string' && typeof afterAddDiagnostics.visualChangeItems[0].label === 'string' && Number.isFinite(afterAddDiagnostics.visualChangeItems[0].x) && Number.isFinite(afterAddDiagnostics.visualChangeItems[0].y) && Number.isFinite(afterAddDiagnostics.visualChangeItems[0].w) && Number.isFinite(afterAddDiagnostics.visualChangeItems[0].h),
            visualDiffCanvasSizeDetected: afterAddDiagnostics.visualChangeCanvasWidth > 0 && afterAddDiagnostics.visualChangeCanvasHeight > 0,
            cleanExport: !afterDelete.includes('data-chiselo'),
            pseudoElementFrozen: frozenJSON.includes('AUTO'),
            gradientFillFrozen: frozenJSON.includes('linear-gradient'),
            imageElementFrozen: frozenJSON.includes('"type":"image"'),
            imageSourcePreserved: frozenJSON.includes('missing-chiselo-image.png'),
            imageExportPreserved: frozenExport.includes('<img') && frozenExport.includes('missing-chiselo-image.png'),
            deckLayerSelectionWorks: Boolean(firstFrozenElement && selectedFrozenElement && selectedFrozenElement.id === firstFrozenElement.id),
            minimalDiagnosticsNoResourceTarget: minimalDiagnostics.imageCount === 0 && minimalDiagnostics.mediaCount === 0 && minimalDiagnostics.resourceElementId === null,
            minimalDiagnosticsNoTableTarget: minimalDiagnostics.tableCount === 0 && minimalDiagnostics.tableElementId === null,
            minimalDiagnosticsNoSvgTarget: minimalDiagnostics.svgCount === 0 && minimalDiagnostics.svgElementId === null,
            minimalDiagnosticsOnlyTextPPTXTarget: minimalDiagnostics.pptxTextElementId !== null && minimalDiagnostics.pptxImageElementId === null && minimalDiagnostics.pptxReviewElementId === null && minimalDiagnostics.pptxFallbackElementId === null && Array.isArray(minimalDiagnostics.pptxTextElementIds) && minimalDiagnostics.pptxTextElementIds.length >= 1
          };

          const failed = Object.entries(assertions).filter(([, value]) => !value);
          if (failed.length) {
            throw new Error(JSON.stringify({ failed, assertions, before, selectedBefore, afterAdd, afterDelete }));
          }

          window.webkit.messageHandlers.adapter.postMessage({
            type: 'result',
            assertions,
            before,
            afterAddDiagnostics,
            minimalDiagnostics
          });
        })().catch(error => {
          window.webkit.messageHandlers.adapter.postMessage({ type: 'error', message: String(error && error.message || error) });
        });
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error {
                self.fail("Script failed: \(error.localizedDescription)")
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            fail("Invalid bridge message.")
        }

        if type == "error" {
            fail(body["message"] as? String ?? "Unknown adapter failure.")
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
            print(String(data: data, encoding: .utf8) ?? "{}")
            exit(0)
        } catch {
            fail("Could not encode result: \(error.localizedDescription)")
        }
    }

    private func fail(_ message: String) -> Never {
        fputs("\(message)\n", stderr)
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

let test = ImportAdapterTest(editorURL: editorURL)
test.start()

app.run()
