import AppKit
import Foundation
import WebKit

final class DirectHTMLCanvasInteractionTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let editorURL: URL
    private let htmlURL: URL
    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var lastProgressAt = Date()
    private var watchdog: Timer?

    init(editorURL: URL, htmlURL: URL) {
        self.editorURL = editorURL
        self.htmlURL = htmlURL
    }

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "directInteraction")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 900), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        let hostWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 900),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hostWindow.isReleasedWhenClosed = false
        hostWindow.alphaValue = 0.01
        hostWindow.ignoresMouseEvents = true
        hostWindow.contentView = webView
        hostWindow.orderFrontRegardless()
        self.hostWindow = hostWindow
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())

        lastProgressAt = Date()
        watchdog = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let idleSeconds = Date().timeIntervalSince(self.lastProgressAt)
            if idleSeconds > 60 {
                self.fail("Timed out after \(Int(idleSeconds)) seconds without interaction progress.")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 180) { [weak self] in
            self?.fail("Timed out waiting for the complete direct interaction result.")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        do {
            let html = try String(contentsOf: htmlURL, encoding: .utf8)
            guard let data = html.data(using: .utf8) else {
                fail("Could not encode HTML as UTF-8.")
            }

            let base64 = data.base64EncodedString()
            let baseHref = htmlURL.deletingLastPathComponent().absoluteString
            let baseLiteral = try jsStringLiteral(baseHref)
            let script = """
            void window.ChiseloEditor.openHTMLFromBase64('\(base64)', \(baseLiteral))
              .then(async () => {
                const testStartedAt = performance.now();
                const progress = (step) => window.webkit.messageHandlers.directInteraction.postMessage({
                  type: 'progress',
                  step,
                  elapsedMs: Math.round(performance.now() - testStartedAt)
                });
                const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
                progress('loaded');
                const initialViewport = window.ChiseloEditor.getViewportState();
                if (Math.abs(initialViewport.scale - 1) > 0.001 || Math.abs(initialViewport.fitScale - 1) > 0.001 || Math.abs(initialViewport.userZoom - 1) > 0.001) {
                  throw new Error(`HTML did not open at 100% CSS-pixel scale: ${JSON.stringify(initialViewport)}`);
                }
                window.dispatchEvent(new Event('resize'));
                await sleep(40);
                const afterWindowResize = window.ChiseloEditor.getViewportState();
                if (Math.abs(afterWindowResize.scale - 1) > 0.001 || Math.abs(afterWindowResize.userZoom - 1) > 0.001) {
                  throw new Error(`Window resize changed HTML zoom without user action: ${JSON.stringify(afterWindowResize)}`);
                }
                window.ChiseloEditor.setHTMLPreviewWidth(768);
                await sleep(80);
                const afterPreviewWidth = window.ChiseloEditor.getViewportState();
                if (Math.abs(afterPreviewWidth.scale - 1) > 0.001 || Math.abs(afterPreviewWidth.userZoom - 1) > 0.001) {
                  throw new Error(`Responsive preview changed HTML zoom without user action: ${JSON.stringify(afterPreviewWidth)}`);
                }
                const responsiveFrame = document.querySelector('iframe.html-frame');
                const responsiveDoc = responsiveFrame?.contentDocument;
                const responsiveWin = responsiveFrame?.contentWindow;
                const responsiveInput = responsiveDoc?.querySelector('input:not([type="checkbox"])') || responsiveDoc?.querySelector('input');
                const responsiveTarget = responsiveInput || responsiveDoc?.querySelector('h1') || [...(responsiveDoc?.body?.querySelectorAll('*') || [])]
                  .find((node) => {
                    const rect = node.getBoundingClientRect();
                    const style = responsiveWin?.getComputedStyle(node);
                    return rect.width > 3 && rect.height > 3 && style?.display !== 'none' && style?.visibility !== 'hidden';
                  });
                if (!responsiveFrame || !responsiveDoc || !responsiveWin || !responsiveTarget) {
                  throw new Error('Responsive preview did not expose a selectable target.');
                }
                responsiveWin.scrollTo(0, 12);
                await sleep(40);
                const inputPoint = responsiveTarget.getBoundingClientRect();
                responsiveTarget.dispatchEvent(new responsiveWin.PointerEvent('pointerdown', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: inputPoint.left + inputPoint.width / 2,
                  clientY: inputPoint.top + inputPoint.height / 2,
                  pointerId: 701
                }));
                responsiveDoc.dispatchEvent(new responsiveWin.PointerEvent('pointerup', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: inputPoint.left + inputPoint.width / 2,
                  clientY: inputPoint.top + inputPoint.height / 2,
                  pointerId: 701
                }));
                await sleep(80);
                const responsiveInputSelection = window.ChiseloEditor.getSelection();
                if (responsiveInputSelection?.tagName !== responsiveTarget.tagName.toLowerCase()) {
                  throw new Error(`Responsive target click selected the wrong target: ${JSON.stringify(responsiveInputSelection)}`);
                }
                const inputRect = responsiveTarget.getBoundingClientRect();
                const frameRect = responsiveFrame.getBoundingClientRect();
                const selectionRect = document.getElementById('selectionBox')?.getBoundingClientRect();
                const iframeWidth = responsiveWin.innerWidth;
                const iframeHeight = responsiveWin.innerHeight;
                if (!selectionRect || !iframeWidth || !iframeHeight) {
                  throw new Error('Responsive input selection box is unavailable.');
                }
                // iframe-local geometry and the editor overlay must resolve to the
                // same screen pixels. This catches fixed origin offsets introduced
                // by responsive preview borders, transforms, or iframe sizing.
                const expectedSelectionRect = {
                  left: frameRect.left + inputRect.left * frameRect.width / iframeWidth,
                  top: frameRect.top + inputRect.top * frameRect.height / iframeHeight,
                  width: inputRect.width * frameRect.width / iframeWidth,
                  height: inputRect.height * frameRect.height / iframeHeight
                };
                const responsiveSelectionDelta = {
                  left: selectionRect.left - expectedSelectionRect.left,
                  top: selectionRect.top - expectedSelectionRect.top,
                  width: selectionRect.width - expectedSelectionRect.width,
                  height: selectionRect.height - expectedSelectionRect.height
                };
                if (Object.values(responsiveSelectionDelta).some((delta) => Math.abs(delta) > 2)) {
                  throw new Error(`Responsive input selection is visually offset: ${JSON.stringify({
                    responsiveSelectionDelta,
                    inputRect,
                    frameRect,
                    selectionRect,
                    expectedSelectionRect,
                    iframeWidth,
                    iframeHeight
                  })}`);
                }
                window.ChiseloEditor.setHTMLPreviewWidth(null);
                await sleep(80);
                window.ChiseloEditor.setHTMLZoomPreset('fit-width');
                const explicitFitZoom = window.ChiseloEditor.getViewportState();
                if (!(explicitFitZoom.scale > 0 && explicitFitZoom.userZoom > 0)) {
                  throw new Error(`Explicit fit-width zoom did not produce a usable scale: ${JSON.stringify(explicitFitZoom)}`);
                }
                window.ChiseloEditor.setHTMLZoomPreset('actual');
                const restoredActualZoom = window.ChiseloEditor.getViewportState();
                if (Math.abs(restoredActualZoom.scale - 1) > 0.001 || Math.abs(restoredActualZoom.userZoom - 1) > 0.001) {
                  throw new Error(`Explicit 100% zoom did not restore CSS-pixel scale: ${JSON.stringify(restoredActualZoom)}`);
                }
                progress('html-zoom-explicit-and-stable');
                const iframe = document.querySelector('iframe.html-frame');
                const doc = iframe && iframe.contentDocument;
                const win = iframe && iframe.contentWindow;
                if (!doc || !win) throw new Error('Direct HTML iframe is missing.');

                const elementLayer = document.getElementById('elementLayer');
                const layerPointerEvents = getComputedStyle(elementLayer).pointerEvents;
                if (layerPointerEvents !== 'none') {
                  throw new Error(`HTML element layer is blocking direct canvas clicks: pointer-events=${layerPointerEvents}`);
                }
                progress('html-layer-pass-through');

                const isEditableProbeTarget = (node) => {
                  const tag = node && node.tagName && node.tagName.toLowerCase();
                  if (!tag || ['script', 'style', 'meta', 'link', 'base', 'title', 'noscript', 'template'].includes(tag)) return false;
                  const rect = node.getBoundingClientRect();
                  const style = win.getComputedStyle(node);
                  return rect.width > 3 && rect.height > 3 && style.display !== 'none' && style.visibility !== 'hidden';
                };
                const target = doc.querySelector('h1') || [...doc.body.querySelectorAll('*')].find(isEditableProbeTarget);
                if (!target) throw new Error('No clickable body target found.');
                const rect = target.getBoundingClientRect();
                const x = rect.left + Math.min(24, Math.max(4, rect.width / 4));
                const y = rect.top + Math.min(24, Math.max(4, rect.height / 2));

                target.dispatchEvent(new win.PointerEvent('pointerdown', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: x,
                  clientY: y,
                  pointerId: 7
                }));
                doc.dispatchEvent(new win.PointerEvent('pointerup', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: x,
                  clientY: y,
                  pointerId: 7
                }));
                await sleep(80);

                const selected = window.ChiseloEditor.getSelection();
                if (!selected || selected.tagName !== target.tagName.toLowerCase()) {
                  throw new Error(`Body click did not select target. selected=${selected && selected.tagName}, target=${target.tagName.toLowerCase()}`);
                }
                progress('body-click-selected');

                const parentPointFromDirectPoint = (docX, docY) => {
                  const frameRect = iframe.getBoundingClientRect();
                  const viewportState = window.ChiseloEditor.getViewportState();
                  return {
                    clientX: frameRect.left + (docX - win.scrollX) * viewportState.scale,
                    clientY: frameRect.top + (docY - win.scrollY) * viewportState.scale
                  };
                };

                const dragStartRect = target.getBoundingClientRect();
                const dragStartDocX = dragStartRect.left + win.scrollX + Math.min(30, Math.max(6, dragStartRect.width / 5));
                const dragStartDocY = dragStartRect.top + win.scrollY + Math.min(20, Math.max(6, dragStartRect.height / 2));
                const dragStartClientX = dragStartDocX - win.scrollX;
                const dragStartClientY = dragStartDocY - win.scrollY;
                target.dispatchEvent(new win.PointerEvent('pointerdown', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: dragStartClientX,
                  clientY: dragStartClientY,
                  pointerId: 41
                }));
                doc.dispatchEvent(new win.PointerEvent('pointermove', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: dragStartClientX + 36,
                  clientY: dragStartClientY + 12,
                  pointerId: 41
                }));
                await sleep(30);
                const afterInitialDrag = window.ChiseloEditor.getSelection();
                if (!afterInitialDrag || afterInitialDrag.x === selected.x) {
                  throw new Error(`Direct drag did not move before release. before=${JSON.stringify(selected)}, after=${JSON.stringify(afterInitialDrag)}`);
                }

                const outerReleasePoint = parentPointFromDirectPoint(dragStartDocX + 260, dragStartDocY + 24);
                document.dispatchEvent(new PointerEvent('pointermove', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: outerReleasePoint.clientX,
                  clientY: outerReleasePoint.clientY,
                  pointerId: 41
                }));
                document.dispatchEvent(new PointerEvent('pointerup', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: outerReleasePoint.clientX,
                  clientY: outerReleasePoint.clientY,
                  pointerId: 41
                }));
                await sleep(80);

                const afterOuterRelease = window.ChiseloEditor.getSelection();
                doc.dispatchEvent(new win.PointerEvent('pointermove', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: dragStartClientX + 420,
                  clientY: dragStartClientY + 80,
                  pointerId: 41
                }));
                await sleep(80);
                const afterStrayMove = window.ChiseloEditor.getSelection();
                const guideCountAfterRelease = document.getElementById('guideLayer').children.length;
                if (!afterOuterRelease || !afterStrayMove) {
                  throw new Error('Selection disappeared during cross-frame drag release test.');
                }
                if (Math.abs(afterStrayMove.x - afterOuterRelease.x) > 0.5 || Math.abs(afterStrayMove.y - afterOuterRelease.y) > 0.5) {
                  throw new Error(`Direct drag stayed sticky after outer release. release=${JSON.stringify(afterOuterRelease)}, stray=${JSON.stringify(afterStrayMove)}`);
                }
                if (guideCountAfterRelease !== 0) {
                  throw new Error(`Guide layer stayed visible after outer release: ${guideCountAfterRelease}`);
                }
                progress('cross-frame-drag-release');

                const beforeZoom = window.ChiseloEditor.getViewportState();
                doc.dispatchEvent(new win.WheelEvent('wheel', {
                  bubbles: true,
                  cancelable: true,
                  metaKey: true,
                  deltaY: -420,
                  clientX: x,
                  clientY: y
                }));
                await sleep(80);

                const afterZoom = window.ChiseloEditor.getViewportState();
                const handle = document.querySelector('#selectionBox .resize-handle[data-handle="se"]');
                const handleRect = handle && handle.getBoundingClientRect();
                const handleWidth = handleRect ? handleRect.width : 0;

                if (!(afterZoom.userZoom > beforeZoom.userZoom && afterZoom.scale > beforeZoom.scale)) {
                  throw new Error(`Command-wheel zoom did not increase scale. before=${JSON.stringify(beforeZoom)}, after=${JSON.stringify(afterZoom)}`);
                }
                if (handleWidth < 10) {
                  throw new Error(`Resize handle is too small after zoom compensation: ${handleWidth}`);
                }
                progress('zoom-checked');

                const zoomLockedBeforeClick = window.ChiseloEditor.getViewportState();
                const clickTarget = doc.querySelector('p') || target;
                const clickRect = clickTarget.getBoundingClientRect();
                const clickX = clickRect.left + Math.min(24, Math.max(4, clickRect.width / 4));
                const clickY = clickRect.top + Math.min(12, Math.max(4, clickRect.height / 2));
                clickTarget.dispatchEvent(new win.PointerEvent('pointerdown', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: clickX,
                  clientY: clickY,
                  pointerId: 8
                }));
                doc.dispatchEvent(new win.PointerEvent('pointerup', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: clickX,
                  clientY: clickY,
                  pointerId: 8
                }));
                await sleep(80);
                const zoomLockedAfterClick = window.ChiseloEditor.getViewportState();
                if (Math.abs(zoomLockedAfterClick.scale - zoomLockedBeforeClick.scale) > 0.001) {
                  throw new Error(`Selecting after zoom changed scale. before=${JSON.stringify(zoomLockedBeforeClick)}, after=${JSON.stringify(zoomLockedAfterClick)}`);
                }
                progress('zoom-preserved-after-selection');

                const protectedStyle = (node, pseudo = null) => {
                  const style = win.getComputedStyle(node, pseudo);
                  return JSON.stringify([...style].map(property => [property, style.getPropertyValue(property)]));
                };
                const protectedSnapshot = (node) => {
                  const value = node.getBoundingClientRect();
                  return {
                    x: value.x,
                    y: value.y,
                    w: value.width,
                    h: value.height,
                    style: protectedStyle(node),
                    beforeStyle: protectedStyle(node, '::before'),
                    afterStyle: protectedStyle(node, '::after'),
                    source: node.outerHTML
                  };
                };
                const assertProtectedSnapshot = (label, before, after) => {
                  for (const key of ['x', 'y', 'w', 'h']) {
                    if (Math.abs(before[key] - after[key]) > 0.5) {
                      throw new Error(label + ' moved unrelated object ' + key + ': ' + before[key] + ' -> ' + after[key]);
                    }
                  }
                  for (const key of ['style', 'beforeStyle', 'afterStyle', 'source']) {
                    if (before[key] !== after[key]) {
                      throw new Error(label + ' changed unrelated object ' + key + '.');
                    }
                  }
                };
                const zoomPeer = [...doc.body.querySelectorAll('*')].find(node => (
                  node !== clickTarget
                  && !node.contains(clickTarget)
                  && !clickTarget.contains(node)
                  && isEditableProbeTarget(node)
                ));
                if (!zoomPeer) throw new Error('Could not find an unrelated object for zoomed editing.');
                const zoomPeerBefore = protectedSnapshot(zoomPeer);

                const zoomDragBefore = window.ChiseloEditor.getSelection();
                const zoomDragRect = clickTarget.getBoundingClientRect();
                const zoomDragStartDocX = zoomDragRect.left + win.scrollX + Math.min(24, Math.max(6, zoomDragRect.width / 5));
                const zoomDragStartDocY = zoomDragRect.top + win.scrollY + Math.min(16, Math.max(6, zoomDragRect.height / 2));
                clickTarget.dispatchEvent(new win.PointerEvent('pointerdown', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: zoomDragStartDocX - win.scrollX,
                  clientY: zoomDragStartDocY - win.scrollY,
                  pointerId: 81
                }));
                const zoomDragPoint = parentPointFromDirectPoint(zoomDragStartDocX + 53, zoomDragStartDocY + 29);
                document.dispatchEvent(new PointerEvent('pointermove', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: zoomDragPoint.clientX,
                  clientY: zoomDragPoint.clientY,
                  pointerId: 81
                }));
                document.dispatchEvent(new PointerEvent('pointerup', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: zoomDragPoint.clientX,
                  clientY: zoomDragPoint.clientY,
                  pointerId: 81
                }));
                await sleep(100);

                const zoomDragAfter = window.ChiseloEditor.getSelection();
                const zoomAfterDragState = window.ChiseloEditor.getViewportState();
                const zoomDragDelta = {
                  x: zoomDragAfter.x - zoomDragBefore.x,
                  y: zoomDragAfter.y - zoomDragBefore.y
                };
                if (Math.abs(zoomDragDelta.x - 53) > 7 || Math.abs(zoomDragDelta.y - 29) > 7) {
                  throw new Error('Zoomed drag used unstable coordinates: ' + JSON.stringify(zoomDragDelta));
                }
                if (Math.abs(zoomAfterDragState.scale - zoomLockedAfterClick.scale) > 0.001 || Math.abs(zoomAfterDragState.userZoom - zoomLockedAfterClick.userZoom) > 0.001) {
                  throw new Error('Zoomed drag changed viewport scale.');
                }
                assertProtectedSnapshot('zoomed drag', zoomPeerBefore, protectedSnapshot(zoomPeer));
                progress('zoomed-drag-stable');

                const zoomResizeBefore = window.ChiseloEditor.getSelection();
                const zoomResizeHandle = document.querySelector('#selectionBox .resize-handle[data-handle="se"]');
                const zoomResizeHandleRect = zoomResizeHandle?.getBoundingClientRect?.();
                if (!zoomResizeHandle || !zoomResizeHandleRect) throw new Error('Zoomed resize handle is unavailable.');
                const zoomResizeStartX = zoomResizeHandleRect.left + zoomResizeHandleRect.width / 2;
                const zoomResizeStartY = zoomResizeHandleRect.top + zoomResizeHandleRect.height / 2;
                zoomResizeHandle.dispatchEvent(new PointerEvent('pointerdown', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: zoomResizeStartX,
                  clientY: zoomResizeStartY,
                  pointerId: 82
                }));
                document.dispatchEvent(new PointerEvent('pointermove', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: zoomResizeStartX + 37 * zoomLockedAfterClick.scale,
                  clientY: zoomResizeStartY + 23 * zoomLockedAfterClick.scale,
                  pointerId: 82
                }));
                document.dispatchEvent(new PointerEvent('pointerup', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: zoomResizeStartX + 37 * zoomLockedAfterClick.scale,
                  clientY: zoomResizeStartY + 23 * zoomLockedAfterClick.scale,
                  pointerId: 82
                }));
                await sleep(100);

                const zoomResizeAfter = window.ChiseloEditor.getSelection();
                const zoomAfterGeometry = window.ChiseloEditor.getViewportState();
                const zoomResizeDelta = {
                  w: zoomResizeAfter.w - zoomResizeBefore.w,
                  h: zoomResizeAfter.h - zoomResizeBefore.h
                };
                if (Math.abs(zoomResizeDelta.w - 37) > 7 || Math.abs(zoomResizeDelta.h - 23) > 7) {
                  throw new Error('Zoomed resize used unstable coordinates: ' + JSON.stringify(zoomResizeDelta));
                }
                if (Math.abs(zoomAfterGeometry.scale - zoomLockedAfterClick.scale) > 0.001 || Math.abs(zoomAfterGeometry.userZoom - zoomLockedAfterClick.userZoom) > 0.001) {
                  throw new Error('Zoomed resize changed viewport scale.');
                }
                assertProtectedSnapshot('zoomed resize', zoomPeerBefore, protectedSnapshot(zoomPeer));
                progress('zoomed-geometry-before-diagnostics');
                const zoomedGeometryDiagnostics = window.ChiseloEditor.getImportDiagnostics();
                if (!zoomedGeometryDiagnostics || !Array.isArray(zoomedGeometryDiagnostics.issues)) {
                  throw new Error('Diagnostics became unavailable after zoomed geometry editing.');
                }
                progress('zoomed-geometry-after-diagnostics');
                doc.dispatchEvent(new win.PointerEvent('pointermove', {
                  bubbles: true,
                  cancelable: true,
                  button: 0,
                  clientX: zoomDragStartDocX + 400,
                  clientY: zoomDragStartDocY + 180,
                  pointerId: 82
                }));
                const zoomAfterStrayMove = window.ChiseloEditor.getSelection();
                if (Math.abs(zoomAfterStrayMove.w - zoomResizeAfter.w) > 0.5 || Math.abs(zoomAfterStrayMove.h - zoomResizeAfter.h) > 0.5) {
                  throw new Error('Zoomed resize stayed active after pointer release.');
                }
                progress('zoomed-resize-stable');

                async function assertDoubleClickTextEdit(label, node, replacementText = null) {
                  if (!node) throw new Error(`${label} target not found.`);
                  const nodeRect = node.getBoundingClientRect();
                  const nodeX = nodeRect.left + Math.min(24, Math.max(4, nodeRect.width / 4));
                  const nodeY = nodeRect.top + Math.min(12, Math.max(4, nodeRect.height / 2));
                  return assertDoubleClickTextEditAtPoint(label, node, nodeX, nodeY, replacementText);
                }

                async function assertDoubleClickTextEditAtPoint(label, expectedNode, nodeX, nodeY, replacementText = null) {
                  const dispatchTarget = doc.elementFromPoint(nodeX, nodeY) || expectedNode;
                  progress(`${label}-before-dblclick`);
                  dispatchTarget.dispatchEvent(new win.MouseEvent('dblclick', {
                    bubbles: true,
                    cancelable: true,
                    clientX: nodeX,
                    clientY: nodeY,
                    detail: 2
                  }));
                  await sleep(160);
                  progress(`${label}-after-dblclick`);

                  const active = doc.activeElement;
                  const selectedText = String(win.getSelection()).trim();
                  if (active !== expectedNode || expectedNode.getAttribute('contenteditable') !== 'true') {
                    throw new Error(`${label} did not enter text editing. active=${active && active.tagName}, target=${dispatchTarget && dispatchTarget.tagName}, editable=${expectedNode.getAttribute('contenteditable')}`);
                  }
                  if (expectedNode.getAttribute('data-chiselo-edit-font-lock') !== 'true') {
                    throw new Error(`${label} did not lock computed typography while editing.`);
                  }
                  if (!expectedNode.style.getPropertyValue('--chiselo-edit-font-family') || !expectedNode.style.getPropertyValue('--chiselo-edit-font-size')) {
                    throw new Error(`${label} did not expose typography lock variables.`);
                  }
                  if (!selectedText) {
                    throw new Error(`${label} entered text editing without selecting text.`);
                  }
                  progress(`${label}-edit-ready`);

                  if (replacementText) {
                    progress(`${label}-before-replacement`);
                    expectedNode.textContent = replacementText;
                    const inputEvent = typeof win.InputEvent === 'function'
                      ? new win.InputEvent('input', { bubbles: true, inputType: 'insertText', data: replacementText })
                      : new win.Event('input', { bubbles: true });
                    expectedNode.dispatchEvent(inputEvent);
                    await sleep(40);
                    if (!expectedNode.textContent.includes(replacementText)) {
                      throw new Error(`${label} did not accept inserted text.`);
                    }
                    progress(`${label}-after-replacement`);
                  }

                  progress(`${label}-before-finish`);
                  expectedNode.dispatchEvent(new win.KeyboardEvent('keydown', {
                    bubbles: true,
                    cancelable: true,
                    key: 'Escape'
                  }));
                  await sleep(50);
                  if (expectedNode.hasAttribute('data-chiselo-edit-font-lock') || expectedNode.style.getPropertyValue('--chiselo-edit-font-family')) {
                    throw new Error(`${label} leaked temporary typography lock into the document.`);
                  }
                  if (expectedNode.getAttribute('contenteditable') === 'true') {
                    throw new Error(`${label} stayed contenteditable after finishing edit.`);
                  }
                  progress(`${label}-after-finish`);
                  return selectedText;
                }

                const heading = doc.querySelector('h1')
                  || doc.querySelector('.tr-title')
                  || [...doc.body.querySelectorAll('h2,h3,.title,[class*="title"],div,span')].find(isEditableProbeTarget);
                const subtitle = doc.querySelector('.band-subtitle')
                  || doc.querySelector('.flow')
                  || doc.querySelector('p')
                  || [...doc.body.querySelectorAll('.flow,.box,div,span')].find((node) => node !== heading && isEditableProbeTarget(node));
                const headingSelectedText = await assertDoubleClickTextEdit('Heading', heading);
                const subtitleSelectedText = await assertDoubleClickTextEdit('Paragraph', subtitle);
                progress('basic-double-clicks');

                doc.dispatchEvent(new win.WheelEvent('wheel', {
                  bubbles: true,
                  cancelable: true,
                  metaKey: true,
                  deltaY: 260,
                  clientX: zoomDragStartDocX - win.scrollX,
                  clientY: zoomDragStartDocY - win.scrollY
                }));
                const zoomAfterZoomOut = window.ChiseloEditor.getViewportState();
                const selectionAfterZoomOut = window.ChiseloEditor.getSelection();
                if (!(zoomAfterZoomOut.userZoom < zoomAfterGeometry.userZoom && zoomAfterZoomOut.scale < zoomAfterGeometry.scale)) {
                  throw new Error('Command-wheel zoom out did not decrease scale.');
                }
                if (!selectionAfterZoomOut || selectionAfterZoomOut.id !== zoomResizeAfter.id) {
                  throw new Error('Zooming out lost the edited target selection.');
                }
                for (const key of ['x', 'y', 'w', 'h']) {
                  if (Math.abs(selectionAfterZoomOut[key] - zoomResizeAfter[key]) > 0.5) {
                    throw new Error('Zooming out changed edited target geometry: ' + key + '.');
                  }
                }
                assertProtectedSnapshot('zoom out', zoomPeerBefore, protectedSnapshot(zoomPeer));
                progress('zoom-out-stable');

                const headingRect = heading.getBoundingClientRect();
                const svgOverlay = doc.createElementNS('http://www.w3.org/2000/svg', 'svg');
                svgOverlay.setAttribute('class', 'cap watermark');
                svgOverlay.setAttribute('aria-hidden', 'true');
                svgOverlay.setAttribute('width', String(Math.min(headingRect.width, 360)));
                svgOverlay.setAttribute('height', String(Math.max(headingRect.height, 56)));
                svgOverlay.style.cssText = [
                  'position:absolute',
                  `left:${headingRect.left + win.scrollX}px`,
                  `top:${headingRect.top + win.scrollY}px`,
                  `width:${Math.min(headingRect.width, 360)}px`,
                  `height:${Math.max(headingRect.height, 56)}px`,
                  'z-index:2147483646',
                  'pointer-events:auto'
                ].join(';');
                const svgRect = doc.createElementNS('http://www.w3.org/2000/svg', 'rect');
                svgRect.setAttribute('x', '0');
                svgRect.setAttribute('y', '0');
                svgRect.setAttribute('width', '100%');
                svgRect.setAttribute('height', '100%');
                svgRect.setAttribute('fill', 'transparent');
                svgOverlay.appendChild(svgRect);
                doc.body.appendChild(svgOverlay);
                const overlayClickX = headingRect.left + 34;
                const overlayClickY = headingRect.top + Math.max(10, headingRect.height / 2);
                window.ChiseloEditor.selectHTMLAtPoint(overlayClickX, overlayClickY);
                const svgOverlaySelection = window.ChiseloEditor.getSelection();
                if (!svgOverlaySelection || svgOverlaySelection.tagName !== heading.tagName.toLowerCase()) {
                  throw new Error(`SVG overlay click did not select underlying heading: ${JSON.stringify(svgOverlaySelection)}`);
                }
                svgOverlay.remove();
                progress('svg-overlay-selection');

                window.webkit.messageHandlers.directInteraction.postMessage({
                  type: 'result',
                  selected,
                  beforeZoom,
                  afterZoom,
                  zoomLockedAfterClick,
                  zoomAfterGeometry,
                  zoomAfterZoomOut,
                  zoomDragDelta,
                  zoomResizeDelta,
                  handleWidth,
                  headingSelectedText,
                  subtitleSelectedText,
                  svgOverlaySelectionText: svgOverlaySelection.text
                });
              })
              .catch(error => {
                window.webkit.messageHandlers.directInteraction.postMessage({
                  type: 'error',
                  message: String(error && error.message || error),
                  stack: String(error && error.stack || '')
                });
              });
            """

            webView.evaluateJavaScript(script) { _, error in
                if let error {
                    self.fail("JavaScript evaluation failed: \(error.localizedDescription)")
                }
            }
        } catch {
            fail("Could not read HTML: \(error.localizedDescription)")
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "directInteraction", let body = message.body as? [String: Any] else { return }

        if body["type"] as? String == "error" {
            fail(body["message"] as? String ?? "Unknown JavaScript error.")
            return
        }

        if body["type"] as? String == "progress" {
            if let step = body["step"] as? String {
                lastProgressAt = Date()
                let elapsedMs = body["elapsedMs"] as? Int ?? 0
                print("Progress: \(step) (\(elapsedMs) ms)")
            }
            return
        }

        if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) {
            print(output)
            exit(0)
        }

        fail("Could not serialize direct interaction test result.")
    }

    private func jsStringLiteral(_ string: String) throws -> String {
        let data = try JSONEncoder().encode(string)
        return String(data: data, encoding: .utf8) ?? "\"\""
    }

    private func fail(_ message: String) -> Never {
        fputs("Direct HTML canvas interaction test failed: \(message)\n", stderr)
        exit(1)
    }
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let editorURL = projectRoot
    .appendingPathComponent("Chiselo")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Editor")
    .appendingPathComponent("index.html")

let htmlPath = CommandLine.arguments.dropFirst().first
    ?? projectRoot.appendingPathComponent("examples").appendingPathComponent("sample-html-page.html").path
let htmlURL = URL(fileURLWithPath: htmlPath)

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let test = DirectHTMLCanvasInteractionTest(editorURL: editorURL, htmlURL: htmlURL)
DispatchQueue.main.async {
    test.start()
}

app.run()
