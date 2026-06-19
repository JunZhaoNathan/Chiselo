import AppKit
import Foundation
import WebKit

final class DirectHTMLSourceSyncTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private var webView: WKWebView?

    init(editorURL: URL) {
        self.editorURL = editorURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "sourceSync")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 840), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.fail("Timed out waiting for source sync result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let base64 = Data(Self.fixtureHTML.utf8).base64EncodedString()
        let script = """
        void (async () => {
          const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));
          const editor = window.ChiseloEditor;
          await editor.openHTMLFromBase64('\(base64)', '');
          await sleep(260);

          const selected = editor.selectHTML('#sourceTarget');
          if (!selected) throw new Error('Could not select source sync fixture.');
          const snippet = String(selected.sourceSnippet || '');
          const lineCount = Number(selected.sourceSnippetLineCount || 0);
          const ancestorItems = Array.isArray(selected.sourceAncestorItems) ? selected.sourceAncestorItems : [];
          const siblingItems = Array.isArray(selected.sourceSiblingItems) ? selected.sourceSiblingItems : [];
          const childItems = Array.isArray(selected.sourceChildItems) ? selected.sourceChildItems : [];
          const sourceHasTag = snippet.includes('<article') && snippet.includes('id="sourceTarget"');
          const sourceHasChildren = snippet.includes('<h2>Synced title</h2>') && snippet.includes('<strong>real source</strong>');
          const sourceClean = !snippet.includes('data-chiselo') && !snippet.includes('__chiselo') && !snippet.includes('chiselo-edit');
          const sourceFormatted = snippet.includes('\\n  <h2>');
          const ancestorTags = ancestorItems.map(item => String(item && item.tagName || '').toLowerCase());
          const ancestorPaths = ancestorItems.map(item => String(item && item.path || ''));
          const sourceAncestorItemsVisible = ancestorItems.length >= 3 && ancestorTags[0] === 'body' && ancestorTags.includes('main') && ancestorTags.includes('article') && ancestorPaths.every(path => path.length > 0);
          const sourceSiblingItemsAvailable = siblingItems.some(item => String(item && item.tagName || '').toLowerCase() === 'article' && item.id === selected.id);
          const childItemTags = childItems.map(item => String(item && item.tagName || '').toLowerCase());
          const childItemPaths = childItems.map(item => String(item && item.path || ''));
          const sourceChildItemsVisible = childItems.length >= 3 && childItemTags.includes('h2') && childItemTags.includes('p') && childItemTags.includes('strong') && childItemPaths.every(path => path.includes('sourceTarget'));
          const selectedArticleItem = ancestorItems.find(item => String(item && item.tagName || '').toLowerCase() === 'article');
          const articleSelection = selectedArticleItem ? editor.selectHTMLById(selectedArticleItem.id) : null;
          const articleSelectionOk = !!articleSelection && articleSelection.tagName === 'article' && String(articleSelection.sourceSnippet || '').includes('sourceTarget');
          const selectedH2Item = childItems.find(item => String(item && item.tagName || '').toLowerCase() === 'h2');
          const selectedStrongItem = childItems.find(item => String(item && item.tagName || '').toLowerCase() === 'strong');
          const childMetadataVisible = selectedH2Item?.canEditText === true
            && String(selectedH2Item?.textPreview || '').includes('Synced title')
            && selectedStrongItem?.canEditText === true
            && String(selectedStrongItem?.textPreview || '').includes('real source')
            && Number(selectedStrongItem?.depth || 0) >= 2;
          const originalH2Id = String(selectedH2Item && selectedH2Item.id || '');
          const originalStrongId = String(selectedStrongItem && selectedStrongItem.id || '');
          const h2Selection = selectedH2Item ? editor.selectHTMLById(selectedH2Item.id) : null;
          const h2Snippet = String(h2Selection?.sourceSnippet || '');
          const h2SelectionOk = !!h2Selection && h2Selection.tagName === 'h2' && h2Snippet.includes('<h2') && h2Snippet.includes('Synced title');
          const h2SiblingItems = Array.isArray(h2Selection?.sourceSiblingItems) ? h2Selection.sourceSiblingItems : [];
          const h2SiblingTags = h2SiblingItems.map(item => String(item && item.tagName || '').toLowerCase());
          const selectedParagraphSibling = h2SiblingItems.find(item => String(item && item.tagName || '').toLowerCase() === 'p');
          const paragraphSelection = selectedParagraphSibling ? editor.selectHTMLById(selectedParagraphSibling.id) : null;
          const paragraphSiblingSelectionOk = !!paragraphSelection && paragraphSelection.tagName === 'p' && String(paragraphSelection.sourceSnippet || '').includes('real source');
          const sourceSiblingItemsVisible = h2SiblingItems.length >= 2 && h2SiblingTags.includes('h2') && h2SiblingTags.includes('p') && paragraphSiblingSelectionOk;
          const strongSelection = selectedStrongItem ? editor.selectHTMLById(selectedStrongItem.id) : null;
          const strongSnippet = String(strongSelection?.sourceSnippet || '');
          const strongSelectionOk = !!strongSelection && strongSelection.tagName === 'strong' && strongSnippet.includes('<strong') && strongSnippet.includes('real source');
          editor.selectHTMLById(selected.id);
          const reselected = editor.selectHTMLById(selected.id);
          const reselectedSame = reselected && reselected.id === selected.id && String(reselected.sourceSnippet || '').includes('Synced title');
          const nextSource = snippet.replace('Synced title', 'Edited from source').replace('real source', 'source editor');
          const warningPreview = editor.validateSelectedHTMLSource(nextSource.replace('class="source-card"', 'class="source-card changed-card"').replace('<article', '<section').replace('</article>', '</section>'));
          const warningDetected = warningPreview.ok === true && Array.isArray(warningPreview.warnings) && warningPreview.warnings.some(item => String(item).includes('顶层标签')) && warningPreview.warnings.some(item => String(item).includes('class'));
          const structureShiftSource = [
            '<article id="sourceTarget" class="source-card">',
            '  <header>',
            '    <h2>Edited from source</h2>',
            '  </header>',
            '  <p>This is <strong>source editor</strong> mapped to a visual object.</p>',
            '</article>'
          ].join('\\n');
          const mappingPreview = editor.validateSelectedHTMLSource(structureShiftSource);
          const mappingSummary = mappingPreview?.mappingSummary;
          const mappingPreviewDetected = mappingPreview?.ok === true
            && mappingSummary
            && mappingSummary.structureRisk === true
            && Number(mappingSummary.preservedCount || 0) >= 3
            && Number(mappingSummary.addedCount || 0) >= 1
            && Array.isArray(mappingSummary.items)
            && mappingSummary.items.some(item => item.slot === 'preserved' && String(item.nextTagName || '').toLowerCase() === 'h2')
            && mappingSummary.items.some(item => item.slot === 'added' && String(item.nextTagName || '').toLowerCase() === 'header');
          const simpleMappingPreview = editor.validateSelectedHTMLSource(nextSource)?.mappingSummary;
          const simpleMappingStable = simpleMappingPreview
            && simpleMappingPreview.structureRisk === false
            && Number(simpleMappingPreview.addedCount || 0) === 0
            && Number(simpleMappingPreview.unmatchedCount || 0) === 0;
          const scriptRejected = editor.validateSelectedHTMLSource(nextSource.replace('</article>', '<script>alert(1)</script></article>'));
          const handlerRejected = editor.applySelectedHTMLSource(nextSource.replace('<h2>', '<h2 onclick="alert(1)">'));
          const dangerousRejected = scriptRejected.ok === false && handlerRejected.ok === false;
          const applyResult = editor.applySelectedHTMLSource(nextSource);
          const applied = applyResult && applyResult.ok === true && applyResult.element && applyResult.element.id === selected.id;
          const appliedSnippet = String(applyResult?.element?.sourceSnippet || '');
          const appliedChildItems = Array.isArray(applyResult?.element?.sourceChildItems) ? applyResult.element.sourceChildItems : [];
          const appliedH2Item = appliedChildItems.find(item => String(item && item.tagName || '').toLowerCase() === 'h2');
          const appliedStrongItem = appliedChildItems.find(item => String(item && item.tagName || '').toLowerCase() === 'strong');
          const childIdsStable = !!appliedH2Item && !!appliedStrongItem && appliedH2Item.id === originalH2Id && appliedStrongItem.id === originalStrongId;
          const exported = editor.exportHTML();
          const diagnostics = editor.getImportDiagnostics();
          const sourceApplied = appliedSnippet.includes('Edited from source') && exported.includes('Edited from source') && exported.includes('source editor');
          const exportClean = diagnostics.cleanExport === true && diagnostics.exportArtifactCount === 0 && !exported.includes('data-chiselo');
          editor.command('undo');
          await sleep(180);
          const undoExport = editor.exportHTML();
          const undoRestored = undoExport.includes('Synced title') && !undoExport.includes('Edited from source');

          editor.selectHTML('#sourceTarget');
          const structureShiftBase = editor.selectHTML('#sourceTarget');
          const structureShiftBaseChildren = Array.isArray(structureShiftBase?.sourceChildItems) ? structureShiftBase.sourceChildItems : [];
          const structureShiftBaseH2 = structureShiftBaseChildren.find(item => String(item && item.tagName || '').toLowerCase() === 'h2');
          const structureShiftBaseStrong = structureShiftBaseChildren.find(item => String(item && item.tagName || '').toLowerCase() === 'strong');
          const structureShiftApply = editor.applySelectedHTMLSource(structureShiftSource);
          const structureShiftChildren = Array.isArray(structureShiftApply?.element?.sourceChildItems) ? structureShiftApply.element.sourceChildItems : [];
          const structureShiftH2 = structureShiftChildren.find(item => String(item && item.tagName || '').toLowerCase() === 'h2');
          const structureShiftStrong = structureShiftChildren.find(item => String(item && item.tagName || '').toLowerCase() === 'strong');
          const structureShiftIdsStable = structureShiftApply?.ok === true && structureShiftH2?.id === structureShiftBaseH2?.id && structureShiftStrong?.id === structureShiftBaseStrong?.id;
          const structureShiftSelectH2 = structureShiftH2 ? editor.selectHTMLById(structureShiftH2.id) : null;
          const structureShiftSelectStrong = structureShiftStrong ? editor.selectHTMLById(structureShiftStrong.id) : null;
          const structureShiftSelectionOk = !!structureShiftSelectH2 && !!structureShiftSelectStrong && structureShiftSelectH2.tagName === 'h2' && structureShiftSelectStrong.tagName === 'strong';
          editor.command('undo');
          await sleep(180);

          if (!sourceHasTag || !sourceHasChildren || !sourceClean || !sourceFormatted || lineCount < 4 || !sourceAncestorItemsVisible || !sourceSiblingItemsAvailable || !articleSelectionOk || !sourceChildItemsVisible || !childMetadataVisible || !h2SelectionOk || !sourceSiblingItemsVisible || !strongSelectionOk || !reselectedSame || !warningDetected || !mappingPreviewDetected || !simpleMappingStable || !dangerousRejected || !applied || !childIdsStable || !sourceApplied || !exportClean || !undoRestored || !structureShiftIdsStable || !structureShiftSelectionOk) {
            throw new Error(JSON.stringify({
              sourceHasTag,
              sourceHasChildren,
              sourceClean,
              sourceFormatted,
              lineCount,
              sourceAncestorItemsVisible,
              ancestorItems,
              sourceSiblingItemsAvailable,
              siblingItems,
              articleSelectionOk,
              sourceChildItemsVisible,
              childMetadataVisible,
              childItems,
              h2SelectionOk,
              h2Snippet,
              sourceSiblingItemsVisible,
              h2SiblingItems,
              paragraphSiblingSelectionOk,
              strongSelectionOk,
              strongSnippet,
              reselectedSame,
              warningPreview,
              warningDetected,
              mappingPreview,
              mappingSummary,
              mappingPreviewDetected,
              simpleMappingPreview,
              simpleMappingStable,
              scriptRejected,
              handlerRejected,
              dangerousRejected,
              applyResult,
              applied,
              childIdsStable,
              originalH2Id,
              appliedH2Item,
              originalStrongId,
              appliedStrongItem,
              sourceApplied,
              exportClean,
              undoRestored,
              structureShiftApply,
              structureShiftBase,
              structureShiftBaseChildren,
              structureShiftBaseH2,
              structureShiftBaseStrong,
              structureShiftChildren,
              structureShiftH2,
              structureShiftStrong,
              structureShiftIdsStable,
              structureShiftSelectionOk,
              diagnostics,
              exported,
              undoExport,
              selected,
              snippet
            }));
          }

          window.webkit.messageHandlers.sourceSync.postMessage({
            type: 'result',
            id: selected.id,
            lineCount,
            sourceAncestorItemsVisible,
            sourceSiblingItemsAvailable,
            sourceChildItemsVisible,
            childMetadataVisible,
            articleSelectionOk,
            h2SelectionOk,
            sourceSiblingItemsVisible,
            strongSelectionOk,
            warningDetected,
            mappingPreviewDetected,
            simpleMappingStable,
            dangerousRejected,
            applied,
            childIdsStable,
            sourceApplied,
            cleanExport: diagnostics.cleanExport,
            undoRestored,
            structureShiftIdsStable,
            structureShiftSelectionOk,
            snippet
          });
        })().catch(error => {
          window.webkit.messageHandlers.sourceSync.postMessage({
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
        guard message.name == "sourceSync", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown source sync error.")
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            print(string)
        }
        exit(0)
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML source sync test failed: \(message)\n", stderr)
        exit(1)
    }

    private static let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Source Sync Fixture</title>
      <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        main { width: 720px; padding: 48px; }
        .source-card { padding: 24px; border: 1px solid rgb(203, 213, 225); background: rgb(248, 250, 252); }
      </style>
    </head>
    <body>
      <main>
        <article id="sourceTarget" class="source-card" aria-label="Source card">
          <h2>Synced title</h2>
          <p>This is <strong>real source</strong> mapped to a visual object.</p>
        </article>
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

let test = DirectHTMLSourceSyncTest(editorURL: editorURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
