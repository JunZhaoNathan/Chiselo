(() => {
  "use strict";

  const viewport = document.getElementById("viewport");
  const stageOuter = document.getElementById("stageOuter");
  const stage = document.getElementById("stage");
  const surface = document.getElementById("slideSurface");
  const layer = document.getElementById("elementLayer");
  const guideLayer = document.getElementById("guideLayer");
  const pageBoundaryLayer = document.getElementById("pageBoundaryLayer");
  const hoverBox = document.getElementById("hoverBox");
  const selectionBox = document.getElementById("selectionBox");

  const SNAP_DISTANCE = 6;
  const MIN_SIZE = 24;
  const MIN_USER_ZOOM = 0.2;
  const MAX_USER_ZOOM = 6;
  const MAX_HTML_TREE_NODES = 260;
  const MAX_HTML_DIAGNOSTIC_NODES = 520;
  const MAX_HTML_DIAGNOSTIC_ISSUES = 12;
  const DIRECT_FIXED_FRAME_SELECTOR = ".slide,.sheet,.page,[data-slide],[data-page],[role='doc-page'],[aria-roledescription='slide'],[class~='slide'],[class^='slide-'],[class*=' slide-'],[class~='page'],[class^='page-'],[class*=' page-'],[id^='slide'],[id*='-slide'],[id^='page'],[id*='-page']";
  const CAPTURE_PAGE_SELECTOR = DIRECT_FIXED_FRAME_SELECTOR;
  const DIRECT_RUNTIME_ROOT_SELECTOR = "#app,#root,#__next,#__nuxt,[data-reactroot],[data-v-app],[ng-version]";
  const handles = ["nw", "n", "ne", "e", "se", "s", "sw", "w"];
  const DIRECT_TEXT_BLOCK_SELECTOR = "p,h1,h2,h3,h4,h5,h6,li,figcaption,caption,td,th,button,a,label,pre";
  const DIRECT_SAFE_INLINE_SELECTOR = "span";
  const DIRECT_FORMATTING_INLINE_SELECTOR = "strong,em,b,i,u,small,code,mark,time,sub,sup";
  const DIRECT_TEXT_INLINE_SELECTOR = `${DIRECT_SAFE_INLINE_SELECTOR},${DIRECT_FORMATTING_INLINE_SELECTOR}`;
  const DIRECT_TEXT_SELECTOR = `${DIRECT_TEXT_BLOCK_SELECTOR},${DIRECT_TEXT_INLINE_SELECTOR},div,section,article,header,footer,aside`;

  let deck = sampleDeck();
  let editorMode = "deck";
  let currentSlideIndex = 0;
  let selectedId = null;
  let selectedDeckGroupId = null;
  let directFrame = null;
  let directSelectedNode = null;
  let directSelectedNodes = [];
  let directHadDoctype = true;
  let directBaseHref = "";
  let directLayoutMode = "transform";
  let pendingDirectTextEditNode = null;
  let activeDirectTextEditNode = null;
  let htmlTreeTimer = null;
  let htmlTreeIdleId = null;
  let htmlDiagnosticsTimer = null;
  let directLayoutTimer = null;
  let directMutationRefreshPending = false;
  let directTreeRefreshPending = false;
  let directHoverFrame = 0;
  let pendingDirectHoverNode = null;
  let lastHTMLTreeSignature = "";
  let lastHTMLDiagnosticsSignature = "";
  let directVisualBaseline = null;
  let directVisualBaselineTimer = null;
  let htmlTreeTextCache = null;
  let selectionBridgeTimer = null;
  let selectionBoxFrame = 0;
  let pendingSelectionPayload = null;
  let scale = 1;
  let fitScale = 1;
  let userZoom = 1;
  let activeGesture = null;
  let historyPast = [];
  let historyFuture = [];
  let historyCoalesceKey = null;
  let historyCoalesceUntil = 0;
  let suppressHistory = false;
  let documentDirtyPosted = false;

  function sampleDeck() {
    return {
      version: 1,
      canvas: {
        width: 1280,
        height: 720,
        background: "#f8fafc"
      },
      slides: [
        {
          id: "slide-1",
          title: "HTML 精修页面",
          elements: [
            {
              id: "title",
              type: "text",
              x: 86,
              y: 64,
              w: 720,
              h: 86,
              rotation: 0,
              z: 20,
              text: "Chiselo",
              style: {
                fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif",
                fontSize: 58,
                fontWeight: 760,
                lineHeight: 1.05,
                color: "#111827",
                textAlign: "left"
              }
            },
            {
              id: "subtitle",
              type: "text",
              x: 90,
              y: 160,
              w: 600,
              h: 88,
              rotation: 0,
              z: 19,
              text: "HTML 精修、交付预检、多格式输出。",
              style: {
                fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif",
                fontSize: 28,
                fontWeight: 420,
                lineHeight: 1.22,
                color: "#475569",
                textAlign: "left"
              }
            },
            {
              id: "panel",
              type: "rect",
              x: 770,
              y: 88,
              w: 380,
              h: 470,
              rotation: 0,
              z: 8,
              style: {
                fill: "#ffffff",
                stroke: "#d6dbe5",
                strokeWidth: 1,
                radius: 18
              }
            },
            {
              id: "accent",
              type: "rect",
              x: 818,
              y: 144,
              w: 284,
              h: 86,
              rotation: 0,
              z: 12,
              style: {
                fill: "#1769ff",
                stroke: "#1769ff",
                strokeWidth: 0,
                radius: 14
              }
            },
            {
              id: "metric",
              type: "text",
              x: 846,
              y: 161,
              w: 230,
              h: 54,
              rotation: 0,
              z: 16,
              text: "1280 x 720",
              style: {
                fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif",
                fontSize: 34,
                fontWeight: 720,
                lineHeight: 1.05,
                color: "#ffffff",
                textAlign: "center"
              }
            },
            {
              id: "note",
              type: "text",
              x: 816,
              y: 282,
              w: 290,
              h: 154,
              rotation: 0,
              z: 16,
              text: "Drag, resize, snap, adjust exact geometry, then save as schema or export clean HTML.",
              style: {
                fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif",
                fontSize: 24,
                fontWeight: 460,
                lineHeight: 1.28,
                color: "#334155",
                textAlign: "left"
              }
            }
          ]
        }
      ]
    };
  }

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function currentSlide() {
    const index = Math.min(Math.max(currentSlideIndex, 0), deck.slides.length - 1);
    currentSlideIndex = index;
    return deck.slides[index];
  }

  function selectedElement() {
    if (editorMode === "html") return directSelectedElement();
    const groupSelection = deckGroupSelectionElement();
    if (groupSelection) return groupSelection;
    if (activeGesture?.mode === "deck" && activeGesture.selectionPayloadBase && activeGesture.lastRect) {
      return {
        ...activeGesture.selectionPayloadBase,
        x: activeGesture.lastRect.x,
        y: activeGesture.lastRect.y,
        w: activeGesture.lastRect.w,
        h: activeGesture.lastRect.h,
        rotation: activeGesture.lastRect.rotation || 0
      };
    }
    return currentSlide().elements.find((element) => element.id === selectedId) || null;
  }

  function deckGroupElements(groupId = selectedDeckGroupId) {
    if (!groupId || editorMode !== "deck") return [];
    return currentSlide().elements.filter((element) => element.groupId === groupId);
  }

  function deckGroupBounds(groupId = selectedDeckGroupId) {
    const elements = deckGroupElements(groupId);
    if (!elements.length) return null;

    const left = Math.min(...elements.map((element) => Number(element.x) || 0));
    const top = Math.min(...elements.map((element) => Number(element.y) || 0));
    const right = Math.max(...elements.map((element) => (Number(element.x) || 0) + (Number(element.w) || 0)));
    const bottom = Math.max(...elements.map((element) => (Number(element.y) || 0) + (Number(element.h) || 0)));
    return {
      x: Math.round(left),
      y: Math.round(top),
      w: Math.round(Math.max(1, right - left)),
      h: Math.round(Math.max(1, bottom - top)),
      rotation: 0
    };
  }

  function deckGroupMeta(groupId = selectedDeckGroupId) {
    const elements = deckGroupElements(groupId);
    const first = elements[0] || null;
    return {
      groupRole: first?.groupRole || "module",
      groupLabel: first?.groupLabel || "模块"
    };
  }

  function deckGroupSelectionBase(groupId = selectedDeckGroupId) {
    const bounds = deckGroupBounds(groupId);
    if (!bounds) return null;

    const meta = deckGroupMeta(groupId);
    const count = deckGroupElements(groupId).length;
    return {
      id: `chiselo-deck-group-${groupId}`,
      type: "deck-group",
      tagName: "group",
      htmlPath: `已选中模块：${meta.groupLabel}`,
      semanticRole: "module-group",
      semanticLabel: "模块组",
      groupId,
      groupRole: meta.groupRole,
      groupLabel: meta.groupLabel,
      sourceKind: "module-group-selection",
      editability: "group-editable",
      fidelity: "native",
      captureNote: `模块组包含 ${count} 个可编辑对象，可整组移动、对齐和吸附。`,
      x: bounds.x,
      y: bounds.y,
      w: bounds.w,
      h: bounds.h,
      rotation: 0,
      z: 0,
      text: `已选中模块：${meta.groupLabel}（${count} 个对象）`,
      style: null
    };
  }

  function deckGroupSelectionElement() {
    if (!selectedDeckGroupId || editorMode !== "deck") return null;

    if (activeGesture?.mode === "deck" && activeGesture.type === "group-drag" && activeGesture.selectionPayloadBase && activeGesture.lastRect) {
      return {
        ...activeGesture.selectionPayloadBase,
        x: activeGesture.lastRect.x,
        y: activeGesture.lastRect.y,
        w: activeGesture.lastRect.w,
        h: activeGesture.lastRect.h,
        rotation: 0
      };
    }

    return deckGroupSelectionBase(selectedDeckGroupId);
  }

  function isDeckGroupSelection() {
    return editorMode === "deck" && Boolean(selectedDeckGroupId && deckGroupBounds(selectedDeckGroupId));
  }

  function clearDeckGroupSelection() {
    selectedDeckGroupId = null;
  }

  function sanitizeBridgeValue(value, seen = new WeakSet()) {
    if (value === null) return null;

    const type = typeof value;
    if (type === "string" || type === "boolean") return value;
    if (type === "number") return Number.isFinite(value) ? value : null;
    if (type === "undefined" || type === "function" || type === "symbol") return undefined;

    if (Array.isArray(value)) {
      return value
        .map((item) => sanitizeBridgeValue(item, seen))
        .filter((item) => item !== undefined);
    }

    if (type === "object") {
      if (seen.has(value)) return undefined;
      seen.add(value);

      const output = {};
      for (const [key, item] of Object.entries(value)) {
        const sanitized = sanitizeBridgeValue(item, seen);
        if (sanitized !== undefined) output[key] = sanitized;
      }
      seen.delete(value);
      return output;
    }

    return undefined;
  }

  function postMessage(type, payload = {}) {
    const handler = window.webkit?.messageHandlers?.chiselo;
    if (!handler) return;

    const body = { type, ...payload };
    try {
      handler.postMessage(body);
    } catch {
      try {
        handler.postMessage(sanitizeBridgeValue(body) || { type });
      } catch {
        // Browser preview fallback.
      }
    }
  }

  function postDeckChanged() {
    if (editorMode === "html") return;
    postMessage("deckChanged", { deck, slideIndex: currentSlideIndex });
  }

  function selectionPayload() {
    const directNodes = editorMode === "html" ? directSelectionNodes() : [];
    const activePath = activeGesture?.mode === "html" ? activeGesture.selectionPayloadBase?.htmlPath : null;
    return {
      element: selectedElement(),
      slideIndex: currentSlideIndex,
      path: editorMode === "html" && directNodes.length > 1
        ? (activePath || `已选中 ${directNodes.length} 个对象`)
        : editorMode === "html" && directSelectedNode
          ? (activePath || directNodePath(directSelectedNode))
          : null
    };
  }

  function flushSelectionChanged() {
    const payload = pendingSelectionPayload || selectionPayload();
    pendingSelectionPayload = null;
    postMessage("selectionChanged", payload);
  }

  function postSelectionChanged(options = {}) {
    pendingSelectionPayload = options.payload || null;

    if (options.immediate) {
      clearTimeout(selectionBridgeTimer);
      selectionBridgeTimer = null;
      flushSelectionChanged();
      return;
    }

    if (selectionBridgeTimer) return;
    selectionBridgeTimer = setTimeout(() => {
      selectionBridgeTimer = null;
      flushSelectionChanged();
    }, 32);
  }

  function postHTMLTreeChanged() {
    if (editorMode !== "html") return;
    const tree = buildHTMLTree();
    const signature = JSON.stringify(tree);
    if (signature === lastHTMLTreeSignature) return;
    lastHTMLTreeSignature = signature;
    const diagnostics = getImportDiagnostics();
    lastHTMLDiagnosticsSignature = JSON.stringify(diagnostics);
    postMessage("htmlTreeChanged", { tree, diagnostics });
  }

  function postHTMLDiagnosticsChanged() {
    if (editorMode !== "html") return;
    const diagnostics = getImportDiagnostics();
    const signature = JSON.stringify(diagnostics);
    if (signature === lastHTMLDiagnosticsSignature) return;
    lastHTMLDiagnosticsSignature = signature;
    postMessage("htmlDiagnosticsChanged", { diagnostics });
  }

  function scheduleHTMLTreeChanged() {
    if (editorMode !== "html") return;
    clearTimeout(htmlTreeTimer);
    if (htmlTreeIdleId && window.cancelIdleCallback) {
      window.cancelIdleCallback(htmlTreeIdleId);
      htmlTreeIdleId = null;
    }
    htmlTreeTimer = setTimeout(() => {
      if (window.requestIdleCallback) {
        htmlTreeIdleId = window.requestIdleCallback(() => {
          htmlTreeIdleId = null;
          postHTMLTreeChanged();
        }, { timeout: 500 });
      } else {
        postHTMLTreeChanged();
      }
    }, 140);
  }

  function scheduleHTMLDiagnosticsChanged() {
    if (editorMode !== "html") return;
    clearTimeout(htmlDiagnosticsTimer);
    htmlDiagnosticsTimer = setTimeout(() => {
      htmlDiagnosticsTimer = null;
      postHTMLDiagnosticsChanged();
    }, 120);
  }

  function scheduleDirectLayoutRefresh() {
    if (editorMode !== "html") return;
    clearTimeout(directLayoutTimer);
    const delay = activeDirectTextEditNode?.isConnected ? 96 : 40;
    directLayoutTimer = setTimeout(() => {
      fitStage({ preserveScale: true });
      updatePageBoundaryOverlay();
      updateSelectionBox();
    }, delay);
  }

  function mutationsAffectHTMLTree(mutations) {
    for (const mutation of mutations) {
      if (mutation.type === "childList" || mutation.type === "characterData") {
        return true;
      }

      if (mutation.type !== "attributes") continue;
      const name = mutation.attributeName || "";
      if (name === "id" || name === "class" || name === "src" || name === "alt" || name === "href" || name === "title" || name === "hidden" || name === "aria-label") {
        return true;
      }

      if (name.startsWith("data-") && !name.startsWith("data-chiselo")) {
        return true;
      }
    }

    return false;
  }

  function scheduleSelectionBoxUpdate() {
    if (selectionBoxFrame) return;
    selectionBoxFrame = requestAnimationFrame(() => {
      selectionBoxFrame = 0;
      updateSelectionBox();
    });
  }

  function pushHistory(options = {}) {
    if (suppressHistory) return;
    markDocumentDirty();

    const key = options.coalesceKey || null;
    const interval = Number.isFinite(options.interval) ? options.interval : 700;
    const now = performance.now();
    if (key && historyCoalesceKey === key && now < historyCoalesceUntil) {
      historyCoalesceUntil = now + interval;
      return;
    }

    historyCoalesceKey = key;
    historyCoalesceUntil = key ? now + interval : 0;
    historyPast.push(currentSnapshot());
    if (historyPast.length > 100) historyPast.shift();
    historyFuture = [];
  }

  function resetHistoryCoalescing() {
    historyCoalesceKey = null;
    historyCoalesceUntil = 0;
  }

  function markDocumentDirty() {
    if (documentDirtyPosted) return;
    documentDirtyPosted = true;
    postMessage("documentDirty");
  }

  function clearDirty() {
    documentDirtyPosted = false;
  }

  function currentSnapshot() {
    if (editorMode === "html") {
      return JSON.stringify({ mode: "html", html: exportDirectHTML(), baseHref: directBaseHref });
    }

    return JSON.stringify({ mode: "deck", deck });
  }

  async function restoreFromSnapshot(snapshot) {
    suppressHistory = true;
    resetHistoryCoalescing();
    const parsed = JSON.parse(snapshot);

    if (parsed.mode === "html") {
      await loadDirectHTML(parsed.html, parsed.baseHref || directBaseHref, { resetView: false, preserveDirty: true, preserveBaseline: true });
    } else {
      deck = parsed.deck || parsed;
      editorMode = "deck";
      currentSlideIndex = Math.min(currentSlideIndex, deck.slides.length - 1);
      selectedId = null;
      clearDeckGroupSelection();
      directSelectedNode = null;
      render();
      postDeckChanged();
      postSelectionChanged({ immediate: true });
    }

    suppressHistory = false;
  }

  function undo() {
    if (!historyPast.length) return;
    resetHistoryCoalescing();
    historyFuture.push(currentSnapshot());
    markDocumentDirty();
    void restoreFromSnapshot(historyPast.pop());
  }

  function redo() {
    if (!historyFuture.length) return;
    resetHistoryCoalescing();
    historyPast.push(currentSnapshot());
    markDocumentDirty();
    void restoreFromSnapshot(historyFuture.pop());
  }

  function fitStage(options = {}) {
    const canvas = editorMode === "html" ? directCanvas() : deck.canvas;
    const bounds = viewport.getBoundingClientRect();
    const pad = 68;
    const previousScale = scale;
    const fitX = Math.max(0.1, (bounds.width - pad) / canvas.width);
    const fitY = Math.max(0.1, (bounds.height - pad) / canvas.height);
    fitScale = editorMode === "html"
      ? Math.min(fitX, 1.35)
      : Math.min(fitX, fitY, 1.35);
    if (options.preserveScale && Number.isFinite(previousScale) && previousScale > 0) {
      scale = clampNumber(previousScale, 0.05, 8);
      userZoom = scale / Math.max(fitScale, 0.001);
    } else {
      scale = clampNumber(fitScale * userZoom, 0.05, 8);
    }

    stage.style.width = `${canvas.width}px`;
    stage.style.height = `${canvas.height}px`;
    stage.style.transform = `scale(${scale})`;
    stageOuter.style.width = `${canvas.width * scale}px`;
    stageOuter.style.height = `${canvas.height * scale}px`;
    applyOverlayScaleVariables();
    const overflowsX = canvas.width * scale + pad > bounds.width;
    const overflowsY = canvas.height * scale + pad > bounds.height;
    viewport.classList.toggle("is-scrollable", overflowsX || overflowsY);
    viewport.classList.toggle("is-overflow-x", overflowsX);
    viewport.classList.toggle("is-overflow-y", overflowsY);
  }

  function clampNumber(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function resetZoom() {
    userZoom = 1;
  }

  function applyOverlayScaleVariables() {
    const inverse = 1 / Math.max(scale, 0.05);
    stage.style.setProperty("--selection-border-width", `${Math.max(1, 2 * inverse)}px`);
    stage.style.setProperty("--selection-radius", `${8 * inverse}px`);
    const handleSize = Math.max(12, 14 * inverse);
    stage.style.setProperty("--handle-size", `${handleSize}px`);
    stage.style.setProperty("--handle-half", `${handleSize / 2}px`);
    stage.style.setProperty("--handle-offset", `${-(handleSize / 2)}px`);
    stage.style.setProperty("--toolbar-offset", `${-42 * inverse}px`);
    stage.style.setProperty("--hover-label-offset", `${-28 * inverse}px`);
    stage.style.setProperty("--overlay-scale", `${inverse}`);
  }

  function viewportPointFromEvent(event) {
    if (directFrame?.contentWindow && event.view === directFrame.contentWindow) {
      const frameRect = directFrame.getBoundingClientRect();
      return {
        x: frameRect.left + event.clientX * scale,
        y: frameRect.top + event.clientY * scale
      };
    }

    return { x: event.clientX, y: event.clientY };
  }

  function zoomAtPoint(nextUserZoom, point) {
    const stageRect = stage.getBoundingClientRect();
    const localPoint = {
      x: (point.x - stageRect.left) / scale,
      y: (point.y - stageRect.top) / scale
    };

    userZoom = clampNumber(nextUserZoom, MIN_USER_ZOOM, MAX_USER_ZOOM);
    fitStage();

    const nextStageRect = stage.getBoundingClientRect();
    const nextPoint = {
      x: nextStageRect.left + localPoint.x * scale,
      y: nextStageRect.top + localPoint.y * scale
    };
    viewport.scrollLeft += nextPoint.x - point.x;
    viewport.scrollTop += nextPoint.y - point.y;
    updateSelectionBox();
  }

  function handleViewportWheel(event) {
    if (!(event.metaKey || event.ctrlKey)) return;

    event.preventDefault();
    event.stopPropagation();
    const point = viewportPointFromEvent(event);
    const zoomFactor = Math.exp(-event.deltaY * 0.002);
    zoomAtPoint(userZoom * zoomFactor, point);
  }

  function directCanvas() {
    const doc = directFrame?.contentDocument;
    const root = doc?.documentElement;
    const body = doc?.body;
    const width = Math.max(640, root?.scrollWidth || 0, body?.scrollWidth || 0, directFrame?.offsetWidth || 0);
    const height = Math.max(360, root?.scrollHeight || 0, body?.scrollHeight || 0, directFrame?.offsetHeight || 0);
    return { width: Math.ceil(width), height: Math.ceil(height), background: "#ffffff" };
  }

  function render() {
    if (editorMode === "html") {
      renderDirectHTML({ preserveScale: true });
      return;
    }

    stage.classList.remove("is-html-document");
    hoverBox.hidden = true;
    fitStage();
    surface.style.background = deck.canvas.background || "#ffffff";
    surface.innerHTML = "";
    layer.innerHTML = "";
    updatePageBoundaryOverlay();

    const elements = [...currentSlide().elements].sort((a, b) => a.z - b.z);
    for (const element of elements) {
      layer.appendChild(createElementNode(element));
    }

    updateSelectionBox();
    postDeckChanged();
  }

  function renderDirectHTML(options = {}) {
    stage.classList.add("is-html-document");
    fitStage({ preserveScale: Boolean(options.preserveScale) });
    surface.style.background = "#ffffff";
    layer.innerHTML = "";
    updatePageBoundaryOverlay();
    updateSelectionBox();
  }

  function createElementNode(element) {
    const node = document.createElement("div");
    node.className = "element";
    node.dataset.id = element.id;
    node.dataset.type = element.type;
    if (element.locked) node.classList.add("is-locked");
    applyElementStyle(node, element);

    if (element.type === "text") {
      const content = document.createElement("div");
      content.className = "text-content";
      content.textContent = element.text || "";
      applyTextStyle(content, element.style || {});
      content.addEventListener("dblclick", (event) => {
        event.stopPropagation();
        beginTextEdit(element.id, content);
      });
      node.appendChild(content);
    } else if (element.type === "image") {
      const image = document.createElement("img");
      image.className = "image-content";
      image.alt = element.imageAlt || "";
      image.draggable = false;
      image.src = element.imageSource || "";
      applyImageStyle(image, element.style || {});
      node.appendChild(image);
    } else {
      const shape = document.createElement("div");
      shape.className = "shape-content";
      applyShapeStyle(shape, element.style || {});
      node.appendChild(shape);
    }

    node.addEventListener("pointerdown", (event) => beginDrag(event, element.id));
    return node;
  }

  function applyElementStyle(node, element) {
    node.style.left = `${element.x}px`;
    node.style.top = `${element.y}px`;
    node.style.width = `${element.w}px`;
    node.style.height = `${element.h}px`;
    node.style.zIndex = `${element.z}`;
    node.style.transform = `rotate(${element.rotation || 0}deg)`;
  }

  function applyTextStyle(node, style) {
    node.style.fontFamily = style.fontFamily || "-apple-system, BlinkMacSystemFont, sans-serif";
    node.style.fontSize = `${style.fontSize || 28}px`;
    node.style.fontWeight = `${style.fontWeight || 400}`;
    node.style.lineHeight = `${style.lineHeight || 1.2}`;
    node.style.color = style.color || "#111827";
    node.style.textAlign = style.textAlign || "left";
    node.style.background = style.fill || "transparent";
    node.style.border = `${style.strokeWidth || 0}px solid ${style.stroke || "transparent"}`;
    node.style.borderRadius = `${style.radius || 0}px`;
    node.style.boxShadow = shadowValue(style.shadow);
  }

  function applyShapeStyle(node, style) {
    node.style.background = style.fill || "#ffffff";
    node.style.border = `${style.strokeWidth || 0}px solid ${style.stroke || "transparent"}`;
    node.style.borderRadius = `${style.radius || 0}px`;
    node.style.boxShadow = shadowValue(style.shadow);
  }

  function applyImageStyle(node, style) {
    node.style.width = "100%";
    node.style.height = "100%";
    node.style.display = "block";
    node.style.objectFit = objectFitValue(style.objectFit, "cover");
    node.style.border = `${style.strokeWidth || 0}px solid ${style.stroke || "transparent"}`;
    node.style.borderRadius = `${style.radius || 0}px`;
    node.style.boxShadow = shadowValue(style.shadow);
  }

  function updateSelectionBox() {
    if (editorMode === "html") {
      updateDirectSelectionBox();
      return;
    }

    const element = selectedElement();
    if (!element) {
      selectionBox.hidden = true;
      selectionBox.innerHTML = "";
      delete selectionBox.dataset.selectedId;
      delete selectionBox.dataset.locked;
      delete selectionBox.dataset.group;
      selectionBox.classList.remove("is-group");
      return;
    }

    const locked = Boolean(element.locked);
    const groupSelected = isDeckGroupSelection();
    const shouldRebuildChrome = selectionBox.dataset.selectedId !== element.id
      || selectionBox.dataset.locked !== String(locked)
      || selectionBox.dataset.group !== String(groupSelected);
    selectionBox.hidden = false;
    selectionBox.classList.toggle("is-locked", locked);
    selectionBox.classList.toggle("is-group", groupSelected);
    selectionBox.style.left = `${element.x}px`;
    selectionBox.style.top = `${element.y}px`;
    selectionBox.style.width = `${element.w}px`;
    selectionBox.style.height = `${element.h}px`;
    selectionBox.style.transform = `rotate(${element.rotation || 0}deg)`;

    if (!shouldRebuildChrome) return;

    selectionBox.dataset.selectedId = element.id;
    selectionBox.dataset.locked = String(locked);
    selectionBox.dataset.group = String(groupSelected);
    selectionBox.innerHTML = "";

    if (groupSelected) {
      const badge = document.createElement("div");
      badge.className = "group-badge";
      badge.textContent = element.groupLabel || "模块组";
      selectionBox.appendChild(badge);
    } else {
      for (const handle of handles) {
        const grip = document.createElement("div");
        grip.className = "resize-handle";
        grip.dataset.handle = handle;
        grip.addEventListener("pointerdown", (event) => beginResize(event, handle));
        selectionBox.appendChild(grip);
      }
    }

    if (element.locked) {
      const badge = document.createElement("div");
      badge.className = "lock-badge";
      badge.textContent = "Locked";
      selectionBox.appendChild(badge);
    }
  }

  function selectElement(id, options = {}) {
    const preserveGroup = options.preserveGroup && selectedDeckGroupId;
    const hadGroupSelection = Boolean(selectedDeckGroupId);
    if (!preserveGroup) clearDeckGroupSelection();
    if (selectedId === id && (preserveGroup || !hadGroupSelection)) return;
    selectedId = id;
    updateSelectionBox();
    postSelectionChanged({ immediate: true });
  }

  function selectElementById(id) {
    if (editorMode !== "deck") return null;
    const element = currentSlide().elements.find((item) => item.id === id);
    if (!element) return null;
    selectElement(id);
    return selectedElement();
  }

  function selectGroupById(groupId) {
    if (editorMode !== "deck") return null;
    const elements = deckGroupElements(groupId);
    if (!groupId || !elements.length) return null;
    const previousSelected = elements.find((element) => element.id === selectedId);
    selectedDeckGroupId = groupId;
    selectedId = previousSelected?.id || elements[0].id;
    updateSelectionBox();
    postSelectionChanged({ immediate: true });
    return selectedElement();
  }

  function selectCurrentGroup() {
    if (editorMode !== "deck") return null;
    const element = currentSlide().elements.find((item) => item.id === selectedId);
    if (!element?.groupId) return selectedElement();
    return selectGroupById(element.groupId);
  }

  function clearSelection() {
    if (editorMode === "html") {
      directSelectedNode = null;
      directSelectedNodes = [];
      selectedId = null;
      clearDeckGroupSelection();
      updateSelectionBox();
      postSelectionChanged();
      return;
    }

    selectedId = null;
    clearDeckGroupSelection();
    updateSelectionBox();
    postSelectionChanged({ immediate: true });
  }

  function pointFromEvent(event) {
    const rect = stage.getBoundingClientRect();
    return {
      x: (event.clientX - rect.left) / scale,
      y: (event.clientY - rect.top) / scale
    };
  }

  function beginDrag(event, id) {
    if (event.button !== 0) return;

    const element = currentSlide().elements.find((item) => item.id === id);
    if (!element) return;
    const dragGroupId = selectedDeckGroupId && element.groupId === selectedDeckGroupId ? selectedDeckGroupId : null;
    const dragGroupElements = dragGroupId ? deckGroupElements(dragGroupId) : [];
    const shouldDragGroup = dragGroupId && dragGroupElements.length > 1;

    selectElement(id, { preserveGroup: shouldDragGroup });
    if (element.locked || event.target.closest("[contenteditable='true']")) return;
    if (shouldDragGroup && deckGroupHasLocked(dragGroupId)) return;

    event.preventDefault();
    pushHistory();

    if (shouldDragGroup) {
      const startRect = deckGroupBounds(dragGroupId);
      if (!startRect) return;

      activeGesture = {
        mode: "deck",
        type: "group-drag",
        id,
        groupId: dragGroupId,
        groupElementIds: dragGroupElements.map((item) => item.id),
        startPoint: pointFromEvent(event),
        startRect,
        startRects: dragGroupElements.map((item) => ({ id: item.id, rect: rectOf(item) })),
        lastRect: startRect,
        selectionPayloadBase: deckGroupSelectionBase(dragGroupId)
      };

      try {
        event.currentTarget.setPointerCapture?.(event.pointerId);
      } catch {
        // Synthetic pointer events and some WebKit edge cases can reject capture.
      }
      document.addEventListener("pointermove", continueGesture);
      document.addEventListener("pointerup", endGesture, { once: true });
      return;
    }

    const startRect = rectOf(element);
    activeGesture = {
      mode: "deck",
      type: "drag",
      id,
      startPoint: pointFromEvent(event),
      startRect,
      lastRect: startRect,
      selectionPayloadBase: clone(element)
    };

    try {
      event.currentTarget.setPointerCapture?.(event.pointerId);
    } catch {
      // Synthetic pointer events and some WebKit edge cases can reject capture.
    }
    document.addEventListener("pointermove", continueGesture);
    document.addEventListener("pointerup", endGesture, { once: true });
  }

  function beginResize(event, handle) {
    if (editorMode === "html") {
      beginDirectResize(event, handle);
      return;
    }

    if (event.button !== 0) return;
    const element = selectedElement();
    if (!element || element.locked) return;
    if (isDeckGroupSelection()) return;

    event.preventDefault();
    event.stopPropagation();
    pushHistory();

    const startRect = rectOf(element);
    activeGesture = {
      mode: "deck",
      type: "resize",
      id: element.id,
      handle,
      startPoint: pointFromEvent(event),
      startRect,
      lastRect: startRect,
      selectionPayloadBase: clone(element),
      ratio: element.w / element.h
    };

    document.addEventListener("pointermove", continueGesture);
    document.addEventListener("pointerup", endGesture, { once: true });
  }

  function continueGesture(event) {
    if (!activeGesture) return;

    if (activeGesture.mode === "html") {
      continueDirectGesture(event);
      return;
    }

    const point = pointFromEvent(event);
    const dx = point.x - activeGesture.startPoint.x;
    const dy = point.y - activeGesture.startPoint.y;

    if (activeGesture.type === "group-drag") {
      const groupId = activeGesture.groupId;
      if (!groupId) return;

      const nextRect = {
        ...activeGesture.startRect,
        x: activeGesture.startRect.x + dx,
        y: activeGesture.startRect.y + dy
      };
      const snapped = snapRect(nextRect, activeGesture.groupElementIds || []);
      activeGesture.lastRect = snapped.rect;
      applyDeckGroupRect(groupId, snapped.rect, {
        startBounds: activeGesture.startRect,
        startRects: activeGesture.startRects,
        history: false,
        postDeck: false,
        render: false
      });
      scheduleSelectionBoxUpdate();
      showGuides(snapped.guides);
      postSelectionChanged();
      return;
    }

    const element = currentSlide().elements.find((item) => item.id === activeGesture.id);
    if (!element) return;

    let nextRect = rectOf(element);

    if (activeGesture.type === "drag") {
      nextRect = {
        ...activeGesture.startRect,
        x: activeGesture.startRect.x + dx,
        y: activeGesture.startRect.y + dy
      };
    }

    if (activeGesture.type === "resize") {
      nextRect = resizeRect(activeGesture.startRect, activeGesture.handle, dx, dy, event.shiftKey ? activeGesture.ratio : null);
    }

    const snapped = snapRect(nextRect, element.id);
    activeGesture.lastRect = snapped.rect;
    Object.assign(element, snapped.rect);
    updateDeckElementNode(element);
    scheduleSelectionBoxUpdate();
    showGuides(snapped.guides);
    postSelectionChanged();
  }

  function endGesture() {
    if (!activeGesture) return;
    const wasDirect = activeGesture.mode === "html";
    activeGesture = null;
    hideGuides();
    if (!wasDirect) postDeckChanged();
    if (wasDirect && directMutationRefreshPending) {
      directMutationRefreshPending = false;
      scheduleDirectLayoutRefresh();
      if (directTreeRefreshPending) {
        directTreeRefreshPending = false;
        scheduleHTMLTreeChanged();
      }
    }
    updateSelectionBox();
    postSelectionChanged({ immediate: true });
    document.removeEventListener("pointermove", continueGesture);

    const doc = directFrame?.contentDocument;
    doc?.removeEventListener("pointermove", continueGesture);
  }

  function rectOf(element) {
    return {
      x: Number(element.x),
      y: Number(element.y),
      w: Number(element.w),
      h: Number(element.h),
      rotation: Number(element.rotation || 0)
    };
  }

  function deckGroupHasLocked(groupId = selectedDeckGroupId) {
    return deckGroupElements(groupId).some((element) => element.locked);
  }

  function moveDeckGroupBy(groupId, dx, dy, options = {}) {
    const elements = deckGroupElements(groupId);
    if (!elements.length || deckGroupHasLocked(groupId)) return false;

    if (options.history !== false) pushHistory(options.historyOptions || {});
    for (const element of elements) {
      element.x = Math.round((Number(element.x) || 0) + dx);
      element.y = Math.round((Number(element.y) || 0) + dy);
      updateDeckElementNode(element);
    }
    updateSelectionBox();
    postSelectionChanged();
    if (options.postDeck !== false) postDeckChanged();
    return true;
  }

  function applyDeckGroupRect(groupId, nextBounds, options = {}) {
    const elements = deckGroupElements(groupId);
    if (!elements.length || deckGroupHasLocked(groupId)) return false;

    const startBounds = options.startBounds || deckGroupBounds(groupId);
    if (!startBounds) return false;

    const startRects = options.startRects || elements.map((element) => ({ id: element.id, rect: rectOf(element) }));
    const startRectMap = new Map(startRects.map((item) => [item.id, item.rect]));
    const scaleX = startBounds.w ? nextBounds.w / startBounds.w : 1;
    const scaleY = startBounds.h ? nextBounds.h / startBounds.h : 1;

    if (options.history !== false) pushHistory(options.historyOptions || {});
    for (const element of elements) {
      const startRect = startRectMap.get(element.id) || rectOf(element);
      element.x = Math.round(nextBounds.x + (startRect.x - startBounds.x) * scaleX);
      element.y = Math.round(nextBounds.y + (startRect.y - startBounds.y) * scaleY);
      element.w = Math.max(1, Math.round(startRect.w * scaleX));
      element.h = Math.max(1, Math.round(startRect.h * scaleY));
      updateDeckElementNode(element);
    }

    if (options.render) render();
    else updateSelectionBox();
    postSelectionChanged();
    if (!options.render && options.postDeck !== false) postDeckChanged();
    return true;
  }

  function deckGroupAnchorElement(groupId = selectedDeckGroupId) {
    const elements = deckGroupElements(groupId);
    return elements.find((element) => element.id === selectedId) || elements[0] || null;
  }

  function finishDeckGroupInternalEdit(elements, options = {}) {
    if (options.render) {
      render();
    } else {
      for (const element of elements) updateDeckElementNode(element);
      updateSelectionBox();
    }
    postSelectionChanged();
    if (!options.render && options.postDeck !== false) postDeckChanged();
  }

  function matchDeckGroupInternalSize(mode) {
    if (!isDeckGroupSelection()) return false;
    const groupId = selectedDeckGroupId;
    const elements = deckGroupElements(groupId).filter((element) => !element.locked);
    if (elements.length < 2 || deckGroupHasLocked(groupId)) return false;

    const anchor = deckGroupAnchorElement(groupId);
    if (!anchor) return false;

    pushHistory();
    for (const element of elements) {
      if (mode === "width") element.w = Math.max(1, Math.round(anchor.w));
      if (mode === "height") element.h = Math.max(1, Math.round(anchor.h));
    }
    finishDeckGroupInternalEdit(elements);
    return true;
  }

  function distributeDeckGroupInternal(axis) {
    if (!isDeckGroupSelection()) return false;
    const groupId = selectedDeckGroupId;
    const elements = deckGroupElements(groupId);
    if (elements.length < 3 || deckGroupHasLocked(groupId)) return false;

    const horizontal = axis === "horizontal";
    const sorted = [...elements].sort((left, right) => {
      const leftPrimary = horizontal ? left.x : left.y;
      const rightPrimary = horizontal ? right.x : right.y;
      if (leftPrimary === rightPrimary) return (left.z || 0) - (right.z || 0);
      return leftPrimary - rightPrimary;
    });
    const first = sorted[0];
    const last = sorted[sorted.length - 1];
    const start = horizontal ? first.x : first.y;
    const end = horizontal ? last.x + last.w : last.y + last.h;
    const totalSize = sorted.reduce((sum, element) => sum + (horizontal ? element.w : element.h), 0);
    const gap = (end - start - totalSize) / (sorted.length - 1);

    pushHistory();
    let cursor = start;
    for (const element of sorted) {
      if (horizontal) element.x = Math.round(cursor);
      else element.y = Math.round(cursor);
      cursor += (horizontal ? element.w : element.h) + gap;
    }
    finishDeckGroupInternalEdit(sorted);
    return true;
  }

  function resizeRect(rect, handle, dx, dy, ratio) {
    let next = { ...rect };

    if (handle.includes("e")) next.w = rect.w + dx;
    if (handle.includes("s")) next.h = rect.h + dy;
    if (handle.includes("w")) {
      next.x = rect.x + dx;
      next.w = rect.w - dx;
    }
    if (handle.includes("n")) {
      next.y = rect.y + dy;
      next.h = rect.h - dy;
    }

    if (ratio && handle.length === 2) {
      if (Math.abs(dx) > Math.abs(dy)) {
        const sign = handle.includes("n") ? -1 : 1;
        next.h = Math.max(MIN_SIZE, next.w / ratio);
        if (sign < 0) next.y = rect.y + rect.h - next.h;
      } else {
        const sign = handle.includes("w") ? -1 : 1;
        next.w = Math.max(MIN_SIZE, next.h * ratio);
        if (sign < 0) next.x = rect.x + rect.w - next.w;
      }
    }

    if (next.w < MIN_SIZE) {
      if (handle.includes("w")) next.x = rect.x + rect.w - MIN_SIZE;
      next.w = MIN_SIZE;
    }

    if (next.h < MIN_SIZE) {
      if (handle.includes("n")) next.y = rect.y + rect.h - MIN_SIZE;
      next.h = MIN_SIZE;
    }

    return next;
  }

  function snapRect(inputRect, activeId) {
    const rect = { ...inputRect };
    const guides = [];
    const canvas = deck.canvas;
    const activeIds = new Set(Array.isArray(activeId) ? activeId : activeId ? [activeId] : []);

    const xCandidates = [
      { value: 0, label: "页面左边" },
      { value: canvas.width / 2, label: "页面中线" },
      { value: canvas.width, label: "页面右边" }
    ];
    const yCandidates = [
      { value: 0, label: "页面顶部" },
      { value: canvas.height / 2, label: "页面中线" },
      { value: canvas.height, label: "页面底部" }
    ];

    for (const element of currentSlide().elements) {
      if (activeIds.has(element.id)) continue;
      xCandidates.push({ value: element.x, label: "对象左边" });
      xCandidates.push({ value: element.x + element.w / 2, label: "对象中线" });
      xCandidates.push({ value: element.x + element.w, label: "对象右边" });
      yCandidates.push({ value: element.y, label: "对象顶部" });
      yCandidates.push({ value: element.y + element.h / 2, label: "对象中线" });
      yCandidates.push({ value: element.y + element.h, label: "对象底部" });
    }

    const xEdges = [
      { value: () => rect.x, apply: (value) => { rect.x = value; } },
      { value: () => rect.x + rect.w / 2, apply: (value) => { rect.x = value - rect.w / 2; } },
      { value: () => rect.x + rect.w, apply: (value) => { rect.x = value - rect.w; } }
    ];
    const yEdges = [
      { value: () => rect.y, apply: (value) => { rect.y = value; } },
      { value: () => rect.y + rect.h / 2, apply: (value) => { rect.y = value - rect.h / 2; } },
      { value: () => rect.y + rect.h, apply: (value) => { rect.y = value - rect.h; } }
    ];

    const xSnap = bestSnap(xEdges, xCandidates);
    if (xSnap) {
      xSnap.edge.apply(xSnap.candidate.value);
      guides.push({ axis: "x", value: xSnap.candidate.value, label: xSnap.candidate.label });
    }

    const ySnap = bestSnap(yEdges, yCandidates);
    if (ySnap) {
      ySnap.edge.apply(ySnap.candidate.value);
      guides.push({ axis: "y", value: ySnap.candidate.value, label: ySnap.candidate.label });
    }

    rect.x = Math.round(rect.x);
    rect.y = Math.round(rect.y);
    rect.w = Math.round(rect.w);
    rect.h = Math.round(rect.h);

    return { rect, guides };
  }

  function bestSnap(edges, candidates) {
    let best = null;

    for (const edge of edges) {
      for (const candidate of candidates) {
        const distance = Math.abs(edge.value() - candidate.value);
        if (distance <= SNAP_DISTANCE && (!best || distance < best.distance)) {
          best = { edge, candidate, distance };
        }
      }
    }

    return best;
  }

  function showGuides(guides) {
    guideLayer.innerHTML = "";

    for (const guide of guides) {
      const node = document.createElement("div");
      node.className = `guide ${guide.axis}`;
      if (guide.axis === "x") node.style.left = `${guide.value}px`;
      if (guide.axis === "y") node.style.top = `${guide.value}px`;
      guideLayer.appendChild(node);

      if (guide.label) {
        const label = document.createElement("div");
        label.className = `guide-label ${guide.axis}`;
        label.textContent = guide.label;
        if (guide.axis === "x") {
          label.style.left = `${Math.round(guide.value) + 6}px`;
          label.style.top = "8px";
        } else {
          label.style.left = "8px";
          label.style.top = `${Math.round(guide.value) + 6}px`;
        }
        guideLayer.appendChild(label);
      }
    }
  }

  function hideGuides() {
    guideLayer.innerHTML = "";
  }

  function updatePageBoundaryOverlay() {
    if (!pageBoundaryLayer) return;
    pageBoundaryLayer.innerHTML = "";

    const frames = pageFramesForCurrentMode().slice(0, 80);
    for (const frame of frames) {
      const rect = frame.rect;
      if (!rect || rect.w < 24 || rect.h < 24) continue;

      const boundary = document.createElement("div");
      boundary.className = "page-boundary";
      boundary.style.left = `${Math.round(rect.x)}px`;
      boundary.style.top = `${Math.round(rect.y)}px`;
      boundary.style.width = `${Math.round(rect.w)}px`;
      boundary.style.height = `${Math.round(rect.h)}px`;
      boundary.dataset.pageIndex = String(frame.index + 1);

      const label = document.createElement("div");
      label.className = "page-boundary-label";
      label.textContent = `${frame.label} · ${Math.round(rect.w)}×${Math.round(rect.h)}`;
      boundary.appendChild(label);

      addBoundaryCenterLine(boundary, "x", rect.w / 2);
      addBoundaryCenterLine(boundary, "y", rect.h / 2);
      addBoundaryTicks(boundary, rect);
      pageBoundaryLayer.appendChild(boundary);
    }
  }

  function addBoundaryCenterLine(boundary, axis, value) {
    const line = document.createElement("div");
    line.className = `page-boundary-center ${axis}`;
    if (axis === "x") line.style.left = `${Math.round(value)}px`;
    if (axis === "y") line.style.top = `${Math.round(value)}px`;
    boundary.appendChild(line);
  }

  function addBoundaryTicks(boundary, rect) {
    const step = rect.w > 1400 || rect.h > 1400 ? 200 : 100;
    const maxTicks = 36;
    for (let x = step, count = 0; x < rect.w && count < maxTicks; x += step, count += 1) {
      const tick = document.createElement("div");
      tick.className = "page-boundary-tick x";
      tick.style.left = `${Math.round(x)}px`;
      boundary.appendChild(tick);
    }
    for (let y = step, count = 0; y < rect.h && count < maxTicks; y += step, count += 1) {
      const tick = document.createElement("div");
      tick.className = "page-boundary-tick y";
      tick.style.top = `${Math.round(y)}px`;
      boundary.appendChild(tick);
    }
  }

  function pageFramesForCurrentMode() {
    if (editorMode === "html") return directPageFrames();
    const canvas = deck.canvas;
    return [{
      index: currentSlideIndex,
      label: `Slide ${currentSlideIndex + 1}`,
      rect: { x: 0, y: 0, w: canvas.width, h: canvas.height }
    }];
  }

  function renderWithoutBridge() {
    suppressHistory = true;
    const previousSelected = selectedId;
    const previousGroup = selectedDeckGroupId;
    fitStage();
    surface.style.background = deck.canvas.background || "#ffffff";
    layer.innerHTML = "";
    const elements = [...currentSlide().elements].sort((a, b) => a.z - b.z);
    for (const element of elements) layer.appendChild(createElementNode(element));
    selectedId = previousSelected;
    selectedDeckGroupId = previousGroup;
    updateSelectionBox();
    updatePageBoundaryOverlay();
    suppressHistory = false;
  }

  function updateDeckElementNode(element) {
    const node = layer.querySelector(`[data-id="${cssEscape(element.id)}"]`);
    if (!node) {
      renderWithoutBridge();
      return;
    }
    applyElementStyle(node, element);
  }

  function beginTextEdit(id, content) {
    const element = currentSlide().elements.find((item) => item.id === id);
    if (!element || element.locked) return;

    selectElement(id);
    pushHistory();
    content.contentEditable = "true";
    content.focus();
    document.execCommand("selectAll", false, null);

    const finish = () => {
      content.contentEditable = "false";
      element.text = content.textContent || "";
      postDeckChanged();
      postSelectionChanged({ immediate: true });
      content.removeEventListener("blur", finish);
    };

    content.addEventListener("blur", finish);
  }

  function updateElement(nextElement) {
    if (editorMode === "html") {
      updateDirectElement(nextElement);
      return;
    }

    if (nextElement?.type === "deck-group") {
      const groupId = nextElement.groupId || selectedDeckGroupId;
      if (!groupId) return;
      const bounds = deckGroupBounds(groupId);
      if (!bounds) return;
      const nextBounds = {
        ...bounds,
        x: Number.isFinite(Number(nextElement.x)) ? Number(nextElement.x) : bounds.x,
        y: Number.isFinite(Number(nextElement.y)) ? Number(nextElement.y) : bounds.y,
        w: Math.max(1, Number.isFinite(Number(nextElement.w)) ? Number(nextElement.w) : bounds.w),
        h: Math.max(1, Number.isFinite(Number(nextElement.h)) ? Number(nextElement.h) : bounds.h),
        rotation: 0
      };
      applyDeckGroupRect(groupId, nextBounds, { render: true });
      return;
    }

    const elements = currentSlide().elements;
    const index = elements.findIndex((element) => element.id === nextElement.id);
    if (index < 0) return;

    pushHistory();
    elements[index] = { ...elements[index], ...nextElement };
    selectedId = nextElement.id;
    clearDeckGroupSelection();
    render();
    postSelectionChanged({ immediate: true });
  }

  function command(name) {
    switch (name) {
      case "undo":
        undo();
        return;
      case "redo":
        redo();
        return;
      case "delete":
        deleteSelected();
        return;
      case "duplicate":
        duplicateSelected();
        return;
      case "bringToFront":
        arrangeSelected("front");
        return;
      case "sendToBack":
        arrangeSelected("back");
        return;
      case "bringForward":
        arrangeSelected("forward");
        return;
      case "sendBackward":
        arrangeSelected("backward");
        return;
      case "toggleLock":
        toggleLock();
        return;
      case "selectModuleGroup":
        selectCurrentGroup();
        return;
      case "alignLeft":
        alignSelected("left");
        return;
      case "alignCenter":
        alignSelected("center");
        return;
      case "alignRight":
        alignSelected("right");
        return;
      case "alignTop":
        alignSelected("top");
        return;
      case "alignMiddle":
        alignSelected("middle");
        return;
      case "alignBottom":
        alignSelected("bottom");
        return;
      case "matchWidth":
        matchSelectedSize("width");
        return;
      case "matchHeight":
        matchSelectedSize("height");
        return;
      case "distributeHorizontal":
        distributeSelected("horizontal");
        return;
      case "distributeVertical":
        distributeSelected("vertical");
        return;
      case "fitWidth":
        fitSelected("width");
        return;
      case "fitHeight":
        fitSelected("height");
        return;
      case "fitPage":
        fitSelected("page");
        return;
      case "snapToGrid":
        snapSelectedToGrid();
        return;
      case "nudgeLeft":
        nudgeSelected(-1, 0);
        return;
      case "nudgeRight":
        nudgeSelected(1, 0);
        return;
      case "nudgeUp":
        nudgeSelected(0, -1);
        return;
      case "nudgeDown":
        nudgeSelected(0, 1);
        return;
      case "nudgeLeftBig":
        nudgeSelected(-10, 0);
        return;
      case "nudgeRightBig":
        nudgeSelected(10, 0);
        return;
      case "nudgeUpBig":
        nudgeSelected(0, -10);
        return;
      case "nudgeDownBig":
        nudgeSelected(0, 10);
        return;
      case "selectParent":
        selectDirectRelative("parent");
        return;
      case "selectFirstChild":
        selectDirectRelative("child");
        return;
      case "selectPreviousSibling":
        selectDirectRelative("previous");
        return;
      case "selectNextSibling":
        selectDirectRelative("next");
        return;
      case "selectVisibleChildren":
        selectDirectVisibleChildren();
        return;
      case "selectSameClass":
        selectDirectSameClass();
        return;
      case "clearSelection":
        clearSelection();
        return;
      case "setLayoutFree":
        setDirectLayoutMode("free");
        return;
      case "setLayoutTransform":
        setDirectLayoutMode("transform");
        return;
      case "tableAddRowAfter":
        tableAddRowAfter();
        return;
      case "tableDeleteRow":
        tableDeleteRow();
        return;
      case "tableAddColumnAfter":
        tableAddColumnAfter();
        return;
      case "tableDeleteColumn":
        tableDeleteColumn();
        return;
      case "cellAlignLeft":
        styleSelectedTableCell({ textAlign: "left" });
        return;
      case "cellAlignCenter":
        styleSelectedTableCell({ textAlign: "center" });
        return;
      case "cellAlignRight":
        styleSelectedTableCell({ textAlign: "right" });
        return;
      case "cellStyleHeader":
        styleSelectedTableCell({
          fill: "rgb(243, 244, 246)",
          color: "rgb(17, 24, 39)",
          fontWeight: 700,
          stroke: "rgb(209, 213, 219)",
          strokeWidth: 1
        });
        return;
      case "cellStyleSoft":
        styleSelectedTableCell({
          fill: "rgb(239, 246, 255)",
          color: "rgb(30, 64, 175)",
          stroke: "rgb(147, 197, 253)",
          strokeWidth: 1
        });
        return;
      default:
        return;
    }
  }

  function deleteSelected() {
    if (editorMode === "html") {
      deleteDirectSelected();
      return;
    }

    if (isDeckGroupSelection()) {
      const groupId = selectedDeckGroupId;
      const ids = new Set(deckGroupElements(groupId).map((element) => element.id));
      if (!ids.size) return;
      pushHistory();
      currentSlide().elements = currentSlide().elements.filter((element) => !ids.has(element.id));
      clearSelection();
      render();
      return;
    }

    if (!selectedId) return;
    pushHistory();
    currentSlide().elements = currentSlide().elements.filter((element) => element.id !== selectedId);
    clearSelection();
    render();
  }

  function duplicateSelected() {
    if (editorMode === "html") {
      duplicateDirectSelected();
      return;
    }

    if (isDeckGroupSelection()) {
      const groupId = selectedDeckGroupId;
      const elements = deckGroupElements(groupId);
      if (!elements.length) return;

      pushHistory();
      const nextGroupId = uniqueDeckGroupId(`${groupId}-copy`);
      const nextZ = Math.max(...currentSlide().elements.map((item) => item.z), 0) + 1;
      const copies = elements.map((element, index) => {
        const copy = clone(element);
        copy.id = uniqueDeckElementId(`${element.id}-copy`);
        copy.groupId = nextGroupId;
        copy.x = Math.round(copy.x + 18);
        copy.y = Math.round(copy.y + 18);
        copy.z = nextZ + index;
        return copy;
      });
      currentSlide().elements.push(...copies);
      selectedDeckGroupId = nextGroupId;
      selectedId = copies[0]?.id || null;
      render();
      postSelectionChanged({ immediate: true });
      return;
    }

    const element = selectedElement();
    if (!element) return;

    pushHistory();
    const copy = clone(element);
    copy.id = uniqueDeckElementId(`${element.id}-copy`);
    copy.x = Math.round(copy.x + 18);
    copy.y = Math.round(copy.y + 18);
    copy.z = Math.max(...currentSlide().elements.map((item) => item.z), 0) + 1;
    currentSlide().elements.push(copy);
    selectedId = copy.id;
    clearDeckGroupSelection();
    render();
    postSelectionChanged({ immediate: true });
  }

  function uniqueDeckElementId(base) {
    const ids = new Set(currentSlide().elements.map((element) => element.id));
    let id = base;
    let index = 2;
    while (ids.has(id)) {
      id = `${base}-${index}`;
      index += 1;
    }
    return id;
  }

  function uniqueDeckGroupId(base) {
    const ids = new Set(currentSlide().elements.map((element) => element.groupId).filter(Boolean));
    let id = base;
    let index = 2;
    while (ids.has(id)) {
      id = `${base}-${index}`;
      index += 1;
    }
    return id;
  }

  function arrangeSelected(mode) {
    if (editorMode === "html") {
      arrangeDirectSelected(mode);
      return;
    }

    if (isDeckGroupSelection()) {
      const elements = deckGroupElements(selectedDeckGroupId);
      if (!elements.length) return;
      pushHistory();
      const allElements = currentSlide().elements;
      const zValues = allElements.map((item) => item.z);
      const minZ = Math.min(...zValues);
      const maxZ = Math.max(...zValues);
      const sorted = [...elements].sort((a, b) => a.z - b.z);

      if (mode === "front") sorted.forEach((element, index) => { element.z = maxZ + 1 + index; });
      if (mode === "back") sorted.forEach((element, index) => { element.z = minZ - sorted.length + index; });
      if (mode === "forward") sorted.forEach((element) => { element.z += 1; });
      if (mode === "backward") sorted.forEach((element) => { element.z -= 1; });

      normalizeZ();
      render();
      postSelectionChanged();
      return;
    }

    const element = selectedElement();
    if (!element) return;

    pushHistory();
    const elements = currentSlide().elements;
    const zValues = elements.map((item) => item.z);
    const minZ = Math.min(...zValues);
    const maxZ = Math.max(...zValues);

    if (mode === "front") element.z = maxZ + 1;
    if (mode === "back") element.z = minZ - 1;
    if (mode === "forward") element.z += 1;
    if (mode === "backward") element.z -= 1;

    normalizeZ();
    render();
    postSelectionChanged();
  }

  function normalizeZ() {
    const sorted = [...currentSlide().elements].sort((a, b) => a.z - b.z);
    sorted.forEach((element, index) => {
      element.z = index + 1;
    });
  }

  function toggleLock() {
    if (isDeckGroupSelection()) {
      const elements = deckGroupElements(selectedDeckGroupId);
      if (!elements.length) return;
      const nextLocked = !elements.every((element) => element.locked);
      pushHistory();
      for (const element of elements) element.locked = nextLocked;
      render();
      postSelectionChanged();
      return;
    }

    const element = selectedElement();
    if (!element) return;

    pushHistory();
    element.locked = !element.locked;
    render();
    postSelectionChanged();
  }

  function alignSelected(edge) {
    if (editorMode === "html") {
      alignDirectSelected(edge);
      return;
    }

    if (isDeckGroupSelection()) {
      const groupId = selectedDeckGroupId;
      const bounds = deckGroupBounds(groupId);
      if (!bounds || deckGroupHasLocked(groupId)) return;
      const canvas = deck.canvas;
      let dx = 0;
      let dy = 0;
      if (edge === "left") dx = -bounds.x;
      if (edge === "center") dx = Math.round((canvas.width - bounds.w) / 2) - bounds.x;
      if (edge === "right") dx = Math.round(canvas.width - bounds.w) - bounds.x;
      if (edge === "top") dy = -bounds.y;
      if (edge === "middle") dy = Math.round((canvas.height - bounds.h) / 2) - bounds.y;
      if (edge === "bottom") dy = Math.round(canvas.height - bounds.h) - bounds.y;
      moveDeckGroupBy(groupId, dx, dy);
      return;
    }

    const element = selectedElement();
    if (!element || element.locked) return;

    pushHistory();
    const canvas = deck.canvas;
    if (edge === "left") element.x = 0;
    if (edge === "center") element.x = Math.round((canvas.width - element.w) / 2);
    if (edge === "right") element.x = Math.round(canvas.width - element.w);
    if (edge === "top") element.y = 0;
    if (edge === "middle") element.y = Math.round((canvas.height - element.h) / 2);
    if (edge === "bottom") element.y = Math.round(canvas.height - element.h);
    render();
    postSelectionChanged();
  }

  function fitSelected(mode) {
    if (editorMode === "html") {
      fitDirectSelected(mode);
      return;
    }

    if (isDeckGroupSelection()) {
      const groupId = selectedDeckGroupId;
      const bounds = deckGroupBounds(groupId);
      if (!bounds || deckGroupHasLocked(groupId)) return;
      const canvas = deck.canvas;
      const nextBounds = { ...bounds };
      if (mode === "width" || mode === "page") {
        nextBounds.x = 0;
        nextBounds.w = canvas.width;
      }
      if (mode === "height" || mode === "page") {
        nextBounds.y = 0;
        nextBounds.h = canvas.height;
      }
      applyDeckGroupRect(groupId, nextBounds, { render: true });
      return;
    }

    const element = selectedElement();
    if (!element || element.locked) return;

    pushHistory();
    const canvas = deck.canvas;
    if (mode === "width" || mode === "page") {
      element.x = 0;
      element.w = canvas.width;
    }
    if (mode === "height" || mode === "page") {
      element.y = 0;
      element.h = canvas.height;
    }
    render();
    postSelectionChanged();
  }

  function matchSelectedSize(mode) {
    if (editorMode === "html") {
      matchDirectSelectedSize(mode);
      return;
    }

    matchDeckGroupInternalSize(mode);
  }

  function distributeSelected(axis) {
    if (editorMode === "html") {
      distributeDirectSelected(axis);
      return;
    }

    distributeDeckGroupInternal(axis);
  }

  function snapSelectedToGrid(grid = 8) {
    if (editorMode === "html") {
      snapDirectSelectedToGrid(grid);
      return;
    }

    if (isDeckGroupSelection()) {
      const groupId = selectedDeckGroupId;
      const bounds = deckGroupBounds(groupId);
      if (!bounds || deckGroupHasLocked(groupId)) return;
      moveDeckGroupBy(groupId, snapNumber(bounds.x, grid) - bounds.x, snapNumber(bounds.y, grid) - bounds.y);
      return;
    }

    const element = selectedElement();
    if (!element || element.locked) return;
    pushHistory();
    element.x = snapNumber(element.x, grid);
    element.y = snapNumber(element.y, grid);
    element.w = Math.max(MIN_SIZE, snapNumber(element.w, grid));
    element.h = Math.max(MIN_SIZE, snapNumber(element.h, grid));
    render();
    postSelectionChanged();
  }

  function snapNumber(value, grid) {
    return Math.round(value / grid) * grid;
  }

  function nudgeSelected(dx, dy) {
    if (editorMode === "html") {
      const nodes = directSelectionNodes();
      if (!nodes.length) return;
      pushHistory();
      for (const node of nodes) {
        const rect = directNodeRect(node);
        rect.x += dx;
        rect.y += dy;
        applyDirectRect(node, rect);
      }
      updateSelectionBox();
      postSelectionChanged();
      return;
    }

    if (isDeckGroupSelection()) {
      moveDeckGroupBy(selectedDeckGroupId, dx, dy);
      return;
    }

    const element = selectedElement();
    if (!element || element.locked) return;
    pushHistory();
    element.x = Math.round(element.x + dx);
    element.y = Math.round(element.y + dy);
    render();
    postSelectionChanged();
  }

  function directSelectedElement() {
    if (activeGesture?.mode === "html" && activeGesture.selectionPayloadBase && activeGesture.lastRect) {
      return {
        ...activeGesture.selectionPayloadBase,
        x: activeGesture.lastRect.x,
        y: activeGesture.lastRect.y,
        w: activeGesture.lastRect.w,
        h: activeGesture.lastRect.h
      };
    }

    const nodes = directSelectionNodes();
    if (nodes.length > 1) {
      const rect = directNodesBounds(nodes);
      return directSelectionPayloadBase(nodes, rect);
    }

    if (!directSelectedNode || !directSelectedNode.isConnected) return null;

    const rect = directNodeRect(directSelectedNode);
    return directElementPayloadForNode(directSelectedNode, rect);
  }

  function directSelectionPayloadBase(nodes, rect) {
    const frame = directElementFramePayload(nodes[0]);
    if (nodes.length > 1) {
      return {
        id: "chiselo-selection-group",
        type: "html-group",
        tagName: "group",
        htmlPath: `已选中 ${nodes.length} 个对象`,
        semanticRole: "selection-group",
        semanticLabel: "多选对象",
        layoutMode: directLayoutMode,
        x: rect.x,
        y: rect.y,
        w: rect.w,
        h: rect.h,
        frame,
        rotation: 0,
        z: 0,
        text: `已选中 ${nodes.length} 个对象`,
        style: null
      };
    }

    const node = nodes[0];
    if (!node || !node.isConnected) return null;
    return directElementPayloadForNode(node, rect || directNodeRect(node));
  }

  function directElementPayloadForNode(node, rect) {
    const style = node.ownerDocument.defaultView.getComputedStyle(node);
    const semantic = directSemanticForNode(node);
    const frame = directElementFramePayload(node);
    const payloadStyle = {
      fontFamily: style.fontFamily || "-apple-system, BlinkMacSystemFont, sans-serif",
      fontSize: parseFloat(style.fontSize) || 16,
      fontWeight: fontWeightNumber(style.fontWeight),
      lineHeight: style.lineHeight === "normal" ? 1.2 : Math.max(0.8, (parseFloat(style.lineHeight) || 19.2) / (parseFloat(style.fontSize) || 16)),
      color: style.color || "#111827",
      fill: isTransparent(style.backgroundColor) ? "transparent" : style.backgroundColor,
      stroke: firstBorderColor(style),
      strokeWidth: firstBorderWidth(style),
      radius: parseFloat(style.borderTopLeftRadius) || 0,
      textAlign: textAlignValue(style.textAlign)
    };
    const shadow = shadowValue(style.boxShadow);
    if (shadow !== "none") payloadStyle.shadow = shadow;
    if (node.matches?.("img")) payloadStyle.objectFit = objectFitValue(style.objectFit, "fill");

    return {
      id: ensureDirectId(node),
      type: "html",
      tagName: node.tagName.toLowerCase(),
      htmlPath: directNodePath(node),
      semanticRole: semantic.role,
      semanticLabel: semantic.label,
      layoutMode: directLayoutMode,
      imageSource: node.matches?.("img") ? (node.currentSrc || node.getAttribute("src") || "") : null,
      imageAlt: node.matches?.("img") ? (node.getAttribute("alt") || "") : null,
      x: rect.x,
      y: rect.y,
      w: rect.w,
      h: rect.h,
      frame,
      rotation: rotationFromTransform(style.transform),
      z: parseFloat(style.zIndex) || 0,
      text: normalizedText(node),
      style: payloadStyle
    };
  }

  function directElementFramePayload(node) {
    if (!node || !node.isConnected) return null;
    const frameNode = directPageFrameNodeFor(node);
    const rect = frameNode ? directNodeRect(frameNode) : directCanvasRect();
    return {
      label: frameNode ? pageFrameLabel(frameNode, 0, 1) : "画布",
      x: rect.x,
      y: rect.y,
      w: rect.w,
      h: rect.h
    };
  }

  function updateDirectSelectionBox() {
    const nodes = directSelectionNodes();
    if (!nodes.length) {
      selectionBox.hidden = true;
      selectionBox.innerHTML = "";
      delete selectionBox.dataset.directSignature;
      return;
    }

    const rect = nodes.length > 1 ? directNodesBounds(nodes) : directNodeRect(nodes[0]);
    const signature = nodes.map((node) => node.dataset.chiseloId || ensureDirectId(node)).join("|");
    const shouldRebuildChrome = selectionBox.dataset.directSignature !== signature;
    selectionBox.hidden = false;
    selectionBox.classList.remove("is-locked");
    selectionBox.classList.toggle("is-group", nodes.length > 1);
    selectionBox.style.left = `${rect.x}px`;
    selectionBox.style.top = `${rect.y}px`;
    selectionBox.style.width = `${rect.w}px`;
    selectionBox.style.height = `${rect.h}px`;
    selectionBox.style.transform = "none";

    if (!shouldRebuildChrome) {
      if (activeGesture?.mode === "html") return;
      const chip = selectionBox.querySelector(".quick-chip");
      if (chip) chip.textContent = directQuickLabel(nodes, rect);
      const bar = selectionBox.querySelector(".quick-action-bar");
      if (bar) {
        bar.className = `quick-action-bar${rect.y < 42 ? " is-below" : ""}`;
        requestAnimationFrame(() => clampDirectQuickActions(bar, rect));
      }
      return;
    }

    selectionBox.dataset.directSignature = signature;
    selectionBox.innerHTML = "";

    for (const handle of handles) {
      const grip = document.createElement("div");
      grip.className = "resize-handle";
      grip.dataset.handle = handle;
      grip.addEventListener("pointerdown", (event) => beginResize(event, handle));
      selectionBox.appendChild(grip);
    }

    appendDirectQuickActions(nodes, rect);
  }

  async function openHTMLFromBase64(base64, baseHref = "") {
    const html = decodeBase64(base64);
    await loadDirectHTML(html, baseHref);
  }

  async function loadDirectHTML(html, baseHref = "", options = {}) {
    const normalized = normalizeDirectHTMLSource(html);
    editorMode = "html";
    if (options.resetView !== false) resetZoom();
    directHadDoctype = normalized.hadDoctype;
    directBaseHref = baseHref || directBaseHref || "";
    lastHTMLTreeSignature = "";
    lastHTMLDiagnosticsSignature = "";
    directMutationRefreshPending = false;
    directTreeRefreshPending = false;
    activeDirectTextEditNode = null;
    pendingDirectTextEditNode = null;
    if (!options.preserveDirty) clearDirty();
    if (!options.preserveBaseline) {
      directVisualBaseline = null;
    }
    resetHistoryCoalescing();
    directSelectedNode = null;
    directSelectedNodes = [];
    selectedId = null;
    clearDeckGroupSelection();
    layer.innerHTML = "";
    hideGuides();

    if (directFrame) directFrame.remove();
    hoverBox.hidden = true;
    directFrame = document.createElement("iframe");
    directFrame.className = "html-frame";
    directFrame.setAttribute("sandbox", "allow-scripts allow-same-origin allow-forms");
    surface.innerHTML = "";
    surface.appendChild(directFrame);

    await writeDirectFrameHTML(directFrame, withBaseElement(normalized.html, directBaseHref));
    setupDirectDocument();
    renderDirectHTML({ preserveScale: options.resetView === false });
    if (!options.preserveBaseline) {
      scheduleDirectVisualBaselineCapture();
    }
    postHTMLTreeChanged();
    postSelectionChanged();
  }

  function scheduleDirectVisualBaselineCapture(delay = 250) {
    if (directVisualBaselineTimer) clearTimeout(directVisualBaselineTimer);
    directVisualBaselineTimer = setTimeout(() => {
      directVisualBaselineTimer = null;
      const doc = directFrame?.contentDocument;
      if (editorMode !== "html" || !doc?.body) return;
      directVisualBaseline = captureDirectVisualSnapshot(doc);
      scheduleHTMLDiagnosticsChanged();
    }, delay);
  }

  function captureDirectVisualSnapshot(doc) {
    const entries = new Map();
    for (const node of diagnosticLayoutNodes(doc)) {
      const key = directVisualSnapshotKey(node);
      if (!key || entries.has(key)) continue;
      entries.set(key, directVisualSnapshotEntry(node));
    }
    return {
      capturedAt: Date.now(),
      entries
    };
  }

  function directVisualSnapshotKey(node) {
    return directNodePath(node);
  }

  function directVisualSnapshotEntry(node) {
    const style = node.ownerDocument.defaultView.getComputedStyle(node);
    const rect = directNodeRect(node);
    const image = node.matches?.("img") ? node : null;
    return {
      elementId: optionalDirectId(node),
      label: diagnosticNodeLabel(node),
      text: normalizedText(node).slice(0, 180),
      imageSource: image ? (image.currentSrc || image.getAttribute("src") || "") : "",
      rect: {
        x: Math.round(rect.x),
        y: Math.round(rect.y),
        w: Math.round(rect.w),
        h: Math.round(rect.h)
      },
      style: {
        color: style.color || "",
        background: cssBackground(style),
        borderColor: firstBorderColor(style),
        borderWidth: Math.round(firstBorderWidth(style) * 10) / 10,
        radius: Math.round((parseFloat(style.borderTopLeftRadius) || 0) * 10) / 10,
        fontSize: Math.round((parseFloat(style.fontSize) || 0) * 10) / 10,
        fontWeight: `${fontWeightNumber(style.fontWeight)}`,
        textAlign: textAlignValue(style.textAlign),
        objectFit: image ? objectFitValue(style.objectFit, "fill") : "",
        opacity: Math.round((parseFloat(style.opacity) || 1) * 100) / 100,
        shadow: shadowValue(style.boxShadow)
      }
    };
  }

  function normalizeDirectHTMLSource(input) {
    let html = String(input || "");
    const hadDoctype = /^\s*<!doctype/i.test(html);
    const hasHTML = /<html[\s>]/i.test(html);
    const hasHead = /<head[\s>]/i.test(html);
    const hasBody = /<body[\s>]/i.test(html);

    if (!hasHTML) {
      const head = hasHead ? "" : "<head><meta charset=\"utf-8\"></head>";
      const body = hasBody ? html : `<body>${html}</body>`;
      return { html: `<html>${head}${body}</html>`, hadDoctype };
    }

    if (!hasHead) {
      html = html.replace(/<html([^>]*)>/i, "<html$1><head><meta charset=\"utf-8\"></head>");
    }

    if (!hasBody) {
      html = html.replace(/<\/head>/i, "</head><body>");
      html = html.replace(/<\/html>\s*$/i, "</body></html>");
    }

    return { html, hadDoctype };
  }

  function waitForFrame(frame) {
    return new Promise((resolve) => {
      let settled = false;
      const finish = () => {
        if (settled) return;
        settled = true;
        setTimeout(resolve, 120);
      };
      frame.addEventListener("load", finish, { once: true });
      setTimeout(finish, 700);
    });
  }

  function writeDirectFrameHTML(frame, html) {
    return new Promise((resolve) => {
      let settled = false;
      let objectURL = "";
      const finish = () => {
        if (settled) return;
        settled = true;
        if (objectURL) {
          setTimeout(() => URL.revokeObjectURL(objectURL), 1200);
        }
        setTimeout(resolve, 220);
      };

      frame.addEventListener("load", finish, { once: true });
      setTimeout(finish, 1400);

      try {
        objectURL = URL.createObjectURL(new Blob([html], { type: "text/html;charset=utf-8" }));
        frame.src = objectURL;
      } catch {
        frame.srcdoc = html;
      }
    });
  }

  function setupDirectDocument() {
    const doc = directFrame.contentDocument;
    if (!doc) return;
    const win = doc.defaultView;

    const style = doc.createElement("style");
    style.setAttribute("data-chiselo-style", "");
    style.textContent = `
      [data-chiselo-id] { cursor: grab; }
      [data-chiselo-id]:active { cursor: grabbing; }
      img[data-chiselo-id], [data-chiselo-id] img { cursor: grab; }
      [data-chiselo-selection-pass-through="true"] { pointer-events: none !important; }
      [contenteditable="true"] {
        outline: 2px solid #1769ff !important;
        outline-offset: 2px !important;
        cursor: text !important;
        -webkit-user-select: text !important;
        user-select: text !important;
      }
      [contenteditable="true"][data-chiselo-edit-font-lock="true"] {
        font-family: var(--chiselo-edit-font-family) !important;
        font-size: var(--chiselo-edit-font-size) !important;
        font-weight: var(--chiselo-edit-font-weight) !important;
        line-height: var(--chiselo-edit-line-height) !important;
        letter-spacing: var(--chiselo-edit-letter-spacing) !important;
        color: var(--chiselo-edit-color) !important;
      }
      strong[contenteditable="true"],
      em[contenteditable="true"],
      b[contenteditable="true"],
      i[contenteditable="true"],
      u[contenteditable="true"],
      small[contenteditable="true"],
      code[contenteditable="true"],
      mark[contenteditable="true"],
      time[contenteditable="true"],
      sub[contenteditable="true"],
      sup[contenteditable="true"] {
        display: inline-block !important;
        min-width: 1ch !important;
      }
    `;
    doc.head?.appendChild(style);

    prepareDirectSubtree(doc.body);

    doc.addEventListener("paste", handleDirectPlainTextPaste, true);

    doc.addEventListener("click", (event) => {
      const link = event.target.closest?.("a");
      if (link) event.preventDefault();
    }, true);

    doc.addEventListener("pointerdown", (event) => {
      if (event.button !== 0) return;
      const node = directSelectionTargetFromEvent(event);
      if (!node) return;
      if (event.shiftKey || event.metaKey || event.ctrlKey) {
        event.preventDefault();
        event.stopPropagation();
        toggleDirectSelection(node);
        return;
      }
      if (event.target.closest?.("[contenteditable='true']")) return;

      if (event.detail >= 2) {
        const textNode = directTextEditTargetFromEvent(event);
        if (textNode) {
          event.preventDefault();
          event.stopPropagation();
          scheduleDirectTextEdit(textNode);
          return;
        }
      }

      beginDirectDrag(event, node);
    }, true);

    doc.addEventListener("mousemove", (event) => {
      if (activeGesture) {
        cancelDirectHover();
        return;
      }
      const node = directSelectionTargetFromEvent(event);
      if (!node || isDirectSelected(node)) {
        cancelDirectHover();
        return;
      }
      scheduleDirectHover(node);
    }, true);

    doc.addEventListener("mouseleave", () => {
      cancelDirectHover();
    });

    doc.addEventListener("dblclick", (event) => {
      if (pendingDirectTextEditNode) {
        event.preventDefault();
        event.stopPropagation();
        return;
      }
      if (event.target.closest?.("[contenteditable='true']")) return;
      const node = directTextEditTargetFromEvent(event);
      if (!node) return;
      event.preventDefault();
      event.stopPropagation();
      scheduleDirectTextEdit(node);
    }, true);

    doc.addEventListener("keydown", handleEditorKeydown);
    doc.addEventListener("wheel", handleViewportWheel, { passive: false });

    win.addEventListener("scroll", () => {
      scheduleSelectionBoxUpdate();
    });

    win.addEventListener("resize", () => {
      scheduleSelectionBoxUpdate();
    });

    const observer = new MutationObserver((mutations) => {
      let sawAddedEditableNodes = false;
      for (const mutation of mutations) {
        if (mutation.type === "attributes" && mutation.target?.nodeType === Node.ELEMENT_NODE) {
          applyDirectEditingAssist(mutation.target);
        }
        for (const node of mutation.addedNodes || []) {
          if (node.nodeType !== Node.ELEMENT_NODE) continue;
          prepareDirectSubtree(node);
          sawAddedEditableNodes = true;
        }
      }
      const affectsTree = mutationsAffectHTMLTree(mutations);
      if (activeGesture?.mode === "html") {
        directMutationRefreshPending = true;
        if (affectsTree) directTreeRefreshPending = true;
        return;
      }
      if (activeDirectTextEditNode?.isConnected) {
        scheduleDirectLayoutRefresh();
        if (affectsTree) directTreeRefreshPending = true;
        return;
      }
      scheduleDirectLayoutRefresh();
      if (affectsTree) scheduleHTMLTreeChanged();
      if (sawAddedEditableNodes) scheduleHTMLDiagnosticsChanged();
    });
    observer.observe(doc.body, {
      attributes: true,
      childList: true,
      subtree: true,
      characterData: true
    });
  }

  function directEditableTarget(target) {
    if (!target || target.nodeType !== Node.ELEMENT_NODE) return null;
    const doc = target.ownerDocument;
    if (target === doc.documentElement) return doc.body;
    return target.closest("body *") || doc.body;
  }

  function prepareDirectSubtree(root) {
    if (!root || root.nodeType !== Node.ELEMENT_NODE) return;
    const nodes = [root, ...(root.querySelectorAll?.("*") || [])];
    for (const node of nodes) {
      ensureDirectId(node);
      applyDirectEditingAssist(node);
    }
    setupDirectResourceTracking(root);
    normalizeDirectTablesForEditing(root);
  }

  function applyDirectEditingAssist(node) {
    if (!node || node.matches?.("html,body")) return;
    if (isLikelySelectionBlockingOverlay(node)) {
      node.dataset.chiseloSelectionPassThrough = "true";
    } else if (node.dataset.chiseloSelectionPassThrough === "true") {
      delete node.dataset.chiseloSelectionPassThrough;
    }
  }

  function directSelectionTargetFromEvent(event) {
    const targetNode = directEditableTarget(event.target);
    if (!targetNode) return null;

    if (!shouldResolveSelectionTargetFromPoint(targetNode)) {
      return targetNode;
    }

    return directSelectableElementAtPoint(event, targetNode) || targetNode;
  }

  function shouldResolveSelectionTargetFromPoint(node) {
    if (!node || !node.matches) return true;
    if (node.matches("html,body")) return true;
    if (isDecorativeDirectNode(node)) return true;

    const rect = node.getBoundingClientRect();
    const canvas = directCanvas();
    const coversMostCanvas = rect.width > canvas.width * 0.72 && rect.height > canvas.height * 0.28;
    return coversMostCanvas && !normalizedText(node);
  }

  function isLikelySelectionBlockingOverlay(node) {
    if (!node || !node.matches || node.matches("html,body,dialog,iframe,canvas,video,audio,svg,img,picture,button,a,input,textarea,select,table")) {
      return false;
    }
    if (node.closest?.("[contenteditable='true']")) return false;
    if (normalizedText(node)) return false;
    if (node.querySelector?.("img,svg,canvas,video,audio,iframe,table,button,a,input,textarea,select,[role='button'],[role='dialog']")) return false;

    const doc = node.ownerDocument;
    const win = doc.defaultView;
    const style = win.getComputedStyle(node);
    if (style.display === "none" || style.visibility === "hidden") return false;
    if (style.pointerEvents === "none" && node.dataset.chiseloSelectionPassThrough !== "true") return false;
    const overlayName = `${node.id || ""} ${typeof node.className === "string" ? node.className : ""} ${node.getAttribute("role") || ""}`.toLowerCase();
    const namedOverlay = /overlay|backdrop|scrim|mask|hit-layer|hitlayer|blocker|shield/.test(overlayName);
    const hiddenOverlay = node.getAttribute("aria-hidden") === "true";
    if (style.position !== "fixed" && style.position !== "absolute" && style.position !== "sticky" && !namedOverlay) return false;

    const rect = overlayDiagnosticRect(node, style, win);
    const viewportArea = Math.max(1, win.innerWidth * win.innerHeight);
    const overlayRatio = (rect.width * rect.height) / viewportArea;
    if (!namedOverlay && !hiddenOverlay && (rect.width < win.innerWidth * 0.35 || rect.height < win.innerHeight * 0.25 || overlayRatio < 0.28)) return false;

    const visualOpacity = Number(style.opacity || 1);
    const emptyBackground = !style.backgroundImage || style.backgroundImage === "none";
    const transparentFill = isTransparentColor(style.backgroundColor);
    const borderWidth = firstBorderWidth(style);
    const hasVisiblePaint = !emptyBackground || !transparentFill || borderWidth > 0 || !isTransparentColor(firstBorderColor(style));

    return visualOpacity <= 0.18 || !hasVisiblePaint;
  }

  function overlayDiagnosticRect(node, style, win) {
    const rect = node.getBoundingClientRect();
    let width = rect.width;
    let height = rect.height;
    const fillsHorizontal = style.left === "0px" && style.right === "0px";
    const fillsVertical = style.top === "0px" && style.bottom === "0px";
    if (style.position === "fixed" && fillsHorizontal && width < win.innerWidth * 0.35) {
      width = win.innerWidth;
    }
    if (style.position === "fixed" && fillsVertical && height < win.innerHeight * 0.25) {
      height = win.innerHeight;
    }
    return { width, height };
  }

  function directSelectableElementAtPoint(event, fallbackNode = null) {
    const doc = event.target?.ownerDocument || directFrame?.contentDocument;
    if (!doc) return null;

    const elements = doc.elementsFromPoint?.(event.clientX, event.clientY) || [];
    const candidates = uniqueElements(elements.map((node) => directEditableTarget(node)));
    const fallback = fallbackNode && fallbackNode !== doc.body && !isSelectionPassThroughCandidate(fallbackNode) ? fallbackNode : null;

    const meaningful = candidates
      .filter((node) => node && node !== doc.body && isDirectNodeVisible(node) && !isDecorativeDirectNode(node) && !isSelectionPassThroughCandidate(node))
      .sort((a, b) => directSelectionScore(a) - directSelectionScore(b));

    return meaningful[0] || fallback;
  }

  function isSelectionPassThroughCandidate(node) {
    return Boolean(node?.dataset?.chiseloSelectionPassThrough === "true" || isLikelySelectionBlockingOverlay(node));
  }

  function directSelectionScore(node) {
    const tag = node.tagName.toLowerCase();
    const rect = node.getBoundingClientRect();
    const area = rect.width * rect.height;
    const semanticBonus = node.matches?.("td,th,p,h1,h2,h3,h4,h5,h6,li,img,table,button,a") ? -120000 : 0;
    const textBonus = normalizedText(node) ? -60000 : 0;
    const depthBonus = -directTextEditDepth(node) * 1200;
    return area + semanticBonus + textBonus + depthBonus;
  }

  function isDecorativeDirectNode(node) {
    if (!node || !node.matches) return false;
    if (node.hasAttribute("data-chiselo-style")) return true;
    if (node.getAttribute("aria-hidden") === "true" && !normalizedText(node)) return true;

    const tag = node.tagName.toLowerCase();
    const svg = node.closest?.("svg");
    if (svg) {
      const svgClass = typeof svg.className === "object" ? svg.className.baseVal : String(svg.className || "");
      const nodeClass = typeof node.className === "object" ? node.className.baseVal : String(node.className || "");
      const names = `${svg.id || ""} ${svgClass} ${node.id || ""} ${nodeClass}`.toLowerCase();
      const graphicOnly = !normalizedText(svg);
      const explicitDecor = /watermark|decor|decoration|background|bg|ornament|cap|hero-cap/.test(names);
      if (explicitDecor || graphicOnly || ["path", "line", "circle", "rect", "ellipse", "polygon", "polyline", "g", "defs", "use"].includes(tag)) {
        return true;
      }
    }

    const style = node.ownerDocument.defaultView.getComputedStyle(node);
    return style.pointerEvents === "none" || style.visibility === "hidden" || style.display === "none";
  }

  function directTextEditTarget(target) {
    return directTextEditTargetFromNode(directEditableTarget(target));
  }

  function directTextEditTargetFromEvent(event) {
    const targetNode = directEditableTarget(event.target);
    if (isDirectNonTextMediaTarget(targetNode)) return null;

    const eventTarget = directTextEditTargetFromNode(targetNode);
    if (eventTarget && !shouldResolveTextTargetFromPoint(targetNode)) return eventTarget;

    const caretNode = directTextElementAtPoint(event);
    const caretTarget = directTextEditTargetFromNode(caretNode);

    if (caretTarget && !shouldResolveTextTargetFromPoint(caretNode)) return caretTarget;

    const pointTarget = nearestDirectTextEditTargetAtPoint(event, targetNode);
    if (pointTarget) return pointTarget;

    if (caretTarget) return caretTarget;
    return eventTarget || directTextEditTarget(event.target);
  }

  function shouldResolveTextTargetFromPoint(node) {
    if (!node || !node.matches) return true;
    if (node.matches(`${DIRECT_TEXT_BLOCK_SELECTOR},${DIRECT_SAFE_INLINE_SELECTOR},${DIRECT_FORMATTING_INLINE_SELECTOR}`)) return false;
    return node.matches("div,section,article,header,footer,aside,body");
  }

  function directTextElementAtPoint(event) {
    const doc = event.target?.ownerDocument || directFrame?.contentDocument;
    if (!doc) return null;

    const range = doc.caretRangeFromPoint?.(event.clientX, event.clientY);
    let node = range?.startContainer || null;

    if (!node && doc.caretPositionFromPoint) {
      node = doc.caretPositionFromPoint(event.clientX, event.clientY)?.offsetNode || null;
    }

    if (node?.nodeType === Node.TEXT_NODE && normalizedText(node.parentElement).length > 0) {
      return node.parentElement;
    }

    return node?.nodeType === Node.ELEMENT_NODE ? node : null;
  }

  function nearestDirectTextEditTargetAtPoint(event, targetNode) {
    const doc = event.target?.ownerDocument || directFrame?.contentDocument;
    if (!doc) return null;

    const x = event.clientX;
    const y = event.clientY;
    const pointElements = doc.elementsFromPoint?.(x, y) || [];
    const roots = uniqueElements([
      targetNode,
      ...pointElements,
      ...pointElements.map((node) => node.closest?.("section,article,header,footer,aside,main,div,td,th")).filter(Boolean)
    ]);

    const candidates = [];
    for (const root of roots) {
      collectDirectTextCandidates(root, candidates);
    }

    const scored = uniqueElements(candidates)
      .filter((node) => isDirectNodeVisible(node) && directNodeAllowsTextEdit(node) && shouldEditNodeDirectly(node))
      .map((node) => {
        const rect = node.getBoundingClientRect();
        const distance = distanceToRect(x, y, rect);
        const inside = distance === 0;
        const depthBonus = Math.min(directTextEditDepth(node), 12) * 0.35;
        const areaPenalty = Math.min(rect.width * rect.height, 120000) / 120000;
        const maxDistance = inside ? 0 : Math.max(28, Math.min(88, Math.max(rect.height * 1.4, 34)));
        return {
          node,
          distance,
          score: distance - depthBonus + areaPenalty,
          allowed: inside || distance <= maxDistance
        };
      })
      .filter((item) => item.allowed)
      .sort((a, b) => a.score - b.score);

    return scored[0]?.node || null;
  }

  function collectDirectTextCandidates(root, output) {
    if (!root || root.nodeType !== Node.ELEMENT_NODE) return;

    const direct = directTextEditTargetFromNode(root);
    if (direct) output.push(direct);

    const searchRoot = root.matches?.("body") ? root : root.closest?.("body *") || root;
    for (const node of searchRoot.querySelectorAll?.(DIRECT_TEXT_SELECTOR) || []) {
      const candidate = directTextEditTargetFromNode(node);
      if (candidate) output.push(candidate);
    }
  }

  function uniqueElements(nodes) {
    const unique = [];
    const seen = new Set();
    for (const node of nodes) {
      if (!node || node.nodeType !== Node.ELEMENT_NODE || seen.has(node)) continue;
      seen.add(node);
      unique.push(node);
    }
    return unique;
  }

  function distanceToRect(x, y, rect) {
    const dx = x < rect.left ? rect.left - x : x > rect.right ? x - rect.right : 0;
    const dy = y < rect.top ? rect.top - y : y > rect.bottom ? y - rect.bottom : 0;
    return Math.hypot(dx, dy);
  }

  function directTextEditTargetFromNode(node) {
    if (!node) return null;

    const blockParent = node.closest?.(DIRECT_TEXT_BLOCK_SELECTOR);
    if (blockParent && directNodeAllowsTextEdit(blockParent)) return blockParent;

    if (node.matches?.(DIRECT_FORMATTING_INLINE_SELECTOR) && directNodeAllowsTextEdit(node)) return node;

    const inlineParent = node.closest?.(DIRECT_SAFE_INLINE_SELECTOR);
    if (inlineParent && directNodeAllowsTextEdit(inlineParent)) return inlineParent;

    if (directNodeAllowsTextEdit(node) && shouldEditNodeDirectly(node)) return node;

    const childCandidate = deepestVisibleTextChild(node);
    if (childCandidate) return childCandidate;

    const textCandidate = node.closest?.(DIRECT_TEXT_SELECTOR);
    if (textCandidate && directNodeAllowsTextEdit(textCandidate)) {
      if (shouldEditNodeDirectly(textCandidate)) return textCandidate;
      return deepestVisibleTextChild(textCandidate);
    }

    return directNodeAllowsTextEdit(node) && shouldEditNodeDirectly(node) ? node : null;
  }

  function shouldEditNodeDirectly(node) {
    if (!node || !directNodeAllowsTextEdit(node)) return false;
    const tag = node.tagName.toLowerCase();
    if (node.matches?.(`${DIRECT_TEXT_BLOCK_SELECTOR},${DIRECT_TEXT_INLINE_SELECTOR}`)) return true;
    if (hasMeaningfulDirectText(node)) return true;
    if (hasMixedMediaChildren(node)) return false;

    const visibleTextChildren = [...node.children].filter((child) => isDirectNodeVisible(child) && directNodeAllowsTextEdit(child));
    return ["div", "section", "article", "header", "footer", "aside"].includes(tag) && visibleTextChildren.length <= 1;
  }

  function hasMixedMediaChildren(node) {
    return Boolean(node?.querySelector?.("img,picture,svg,canvas,video,audio,iframe,table"));
  }

  function deepestVisibleTextChild(node) {
    const candidates = [...node.querySelectorAll(DIRECT_TEXT_SELECTOR)]
      .filter((child) => isDirectNodeVisible(child) && directNodeAllowsTextEdit(child));

    if (!candidates.length) return null;
    return candidates
      .sort((a, b) => directTextEditDepth(b) - directTextEditDepth(a))
      .find((child) => shouldEditNodeDirectly(child)) || candidates[0];
  }

  function directTextEditDepth(node) {
    let depth = 0;
    let current = node;
    while (current?.parentElement) {
      depth += 1;
      current = current.parentElement;
    }
    return depth;
  }

  function hasMeaningfulDirectText(node) {
    return [...node.childNodes].some((child) => child.nodeType === Node.TEXT_NODE && child.textContent.trim().length > 0);
  }

  function ensureDirectId(node) {
    if (!node.dataset.chiseloId) {
      node.dataset.chiseloId = `html-${Math.random().toString(36).slice(2, 9)}`;
    }
    return node.dataset.chiseloId;
  }

  function optionalDirectId(node) {
    return node ? ensureDirectId(node) : null;
  }

  function directNodePath(node) {
    const doc = node.ownerDocument;
    const parts = [];
    let current = node;

    while (current && current.nodeType === Node.ELEMENT_NODE && current !== doc.documentElement) {
      const tag = current.tagName.toLowerCase();
      const id = current.id ? `#${current.id}` : "";
      const className = [...current.classList || []]
        .filter((name) => !name.startsWith("chiselo"))
        .slice(0, 2)
        .map((name) => `.${name}`)
        .join("");
      const siblingIndex = elementSiblingIndex(current);
      parts.unshift(`${tag}${id}${className}${siblingIndex > 1 ? `:nth-of-type(${siblingIndex})` : ""}`);
      current = current.parentElement;
    }

    return parts.join(" > ");
  }

  function buildHTMLTree() {
    const doc = directFrame?.contentDocument;
    if (!doc?.body) return [];

    const budget = { remaining: MAX_HTML_TREE_NODES };
    htmlTreeTextCache = new WeakMap();
    try {
      const roots = visibleTreeChildren(doc.body).slice(0, 18);
      return roots.map((node) => htmlTreeNode(node, 0, budget)).filter(Boolean);
    } finally {
      htmlTreeTextCache = null;
    }
  }

  function htmlTreeNode(node, depth, budget) {
    if (!node || node.nodeType !== Node.ELEMENT_NODE) return null;
    if (budget.remaining <= 0) return null;
    budget.remaining -= 1;

    const children = [];
    if (depth < 6 && budget.remaining > 0) {
      const childLimit = depth === 0 ? 14 : 10;
      for (const child of visibleTreeChildren(node)) {
        if (children.length >= childLimit || budget.remaining <= 0) break;
        const childNode = htmlTreeNode(child, depth + 1, budget);
        if (childNode) children.push(childNode);
      }
    }

    return {
      id: ensureDirectId(node),
      label: htmlTreeLabel(node),
      path: directNodePath(node),
      tagName: node.tagName.toLowerCase(),
      semanticRole: directSemanticForNode(node).role,
      semanticLabel: directSemanticForNode(node).label,
      children: children.length ? children : null
    };
  }

  function directSemanticForNode(node) {
    if (!node || !node.matches) return { role: "object", label: "对象" };

    const tag = node.tagName.toLowerCase();
    const names = `${node.id || ""} ${[...node.classList || []].join(" ")}`.toLowerCase();

    if (tag === "body") return { role: "page", label: "页面" };
    if (tag === "main") return { role: "main", label: "正文区" };
    if (tag === "header") return { role: "header", label: "标题区" };
    if (tag === "footer") return { role: "footer", label: "页脚" };
    if (tag === "nav") return { role: "navigation", label: "导航" };
    if (tag === "aside") return { role: "sidebar", label: "侧栏" };
    if (/^(h[1-6])$/.test(tag)) return { role: "heading", label: `标题 ${tag.toUpperCase()}` };
    if (tag === "p") return { role: "paragraph", label: "段落" };
    if (tag === "span" || tag === "strong" || tag === "em" || tag === "small") return { role: "text", label: "文本" };
    if (tag === "ul" || tag === "ol") return { role: "list", label: "列表" };
    if (tag === "li") return { role: "list-item", label: "列表项" };
    if (tag === "img" || tag === "picture") return { role: "image", label: "图片" };
    if (tag === "figure") return { role: "figure", label: "图文组" };
    if (tag === "figcaption") return { role: "caption", label: "图注" };
    if (tag === "table") return { role: "table", label: "表格" };
    if (tag === "thead" || tag === "tbody" || tag === "tfoot") return { role: "table-section", label: "表格区域" };
    if (tag === "tr") return { role: "table-row", label: "表格行" };
    if (tag === "th") return { role: "table-header-cell", label: "表头单元格" };
    if (tag === "td") return { role: "table-cell", label: "单元格" };
    if (tag === "a") return { role: "link", label: "链接" };
    if (tag === "button") return { role: "button", label: "按钮" };
    if (tag === "form") return { role: "form", label: "表单" };
    if (["input", "textarea", "select", "label"].includes(tag)) return { role: "form-control", label: "表单项" };
    if (["video", "audio", "iframe"].includes(tag)) return { role: "media", label: "媒体" };
    if (["svg", "canvas"].includes(tag)) return { role: "graphic", label: "图形" };

    if (/slide|page|sheet|canvas|screen|cover/.test(names)) return { role: "page", label: "页面" };
    if (/hero|banner|masthead|title/.test(names)) return { role: "header", label: "标题区" };
    if (/card|panel|tile|box/.test(names)) return { role: "card", label: "卡片" };
    if (/table|matrix|grid/.test(names)) return { role: "table-like", label: "表格/矩阵" };
    if (/chart|graph|figure|visual/.test(names)) return { role: "visual", label: "图表" };
    if (/module|block|section|content|item/.test(names)) return { role: "module", label: "模块" };

    if (tag === "section" || tag === "article") return { role: "module", label: "模块" };
    if (tag === "div") return { role: "container", label: "容器" };
    return { role: "object", label: "对象" };
  }

  function visibleTreeChildren(node) {
    return [...node.children].filter((child) => {
      const tag = child.tagName.toLowerCase();
      if (["script", "style", "meta", "link", "base", "title", "noscript"].includes(tag)) return false;
      if (child.hasAttribute("data-chiselo-style")) return false;

      const style = child.ownerDocument.defaultView.getComputedStyle(child);
      const rect = child.getBoundingClientRect();
      const hasText = htmlTreeText(child).length > 0;
      return isVisibleStyle(style) && (rect.width > 3 || rect.height > 3 || hasText);
    });
  }

  function htmlTreeLabel(node) {
    const id = node.id ? `#${node.id}` : "";
    const className = [...node.classList || []]
      .slice(0, 2)
      .map((name) => `.${name}`)
      .join("");
    const text = htmlTreeText(node).slice(0, 42);
    return `${id}${className}${text ? ` ${text}` : ""}`.trim() || node.tagName.toLowerCase();
  }

  function htmlTreeText(node) {
    if (!htmlTreeTextCache) return normalizedText(node);
    if (!htmlTreeTextCache.has(node)) {
      htmlTreeTextCache.set(node, normalizedText(node));
    }
    return htmlTreeTextCache.get(node);
  }

  function elementSiblingIndex(node) {
    let index = 1;
    let sibling = node.previousElementSibling;
    while (sibling) {
      if (sibling.tagName === node.tagName) index += 1;
      sibling = sibling.previousElementSibling;
    }
    return index;
  }

  function selectDirectNode(node) {
    setDirectSelection([node], node);
  }

  function setDirectSelection(nodes, activeNode = null) {
    const uniqueNodes = [];
    const seen = new Set();

    for (const node of nodes || []) {
      if (!node || !node.isConnected || node.nodeType !== Node.ELEMENT_NODE) continue;
      if (seen.has(node)) continue;
      seen.add(node);
      uniqueNodes.push(node);
      ensureDirectId(node);
    }

    const nextActiveNode = activeNode && uniqueNodes.includes(activeNode) ? activeNode : uniqueNodes[uniqueNodes.length - 1] || uniqueNodes[0] || null;
    if (directSelectionMatches(uniqueNodes, nextActiveNode)) return;

    directSelectedNodes = uniqueNodes;
    directSelectedNode = nextActiveNode;
    hoverBox.hidden = true;
    selectedId = directSelectedNode ? ensureDirectId(directSelectedNode) : null;
    updateSelectionBox();
    postSelectionChanged();
  }

  function directSelectionMatches(nodes, activeNode) {
    if (directSelectedNode !== activeNode) return false;
    if (directSelectedNodes.length !== nodes.length) return false;
    return nodes.every((node, index) => directSelectedNodes[index] === node);
  }

  function directHistoryCoalesceKey(prefix, nodes) {
    return `${prefix}:${(nodes || []).map((node) => ensureDirectId(node)).join("|")}`;
  }

  function directSelectionNodes() {
    directSelectedNodes = directSelectedNodes.filter((node) => node?.isConnected);

    if (directSelectedNode?.isConnected && !directSelectedNodes.includes(directSelectedNode)) {
      directSelectedNodes = [directSelectedNode];
    }

    if (!directSelectedNodes.length) {
      directSelectedNode = null;
      selectedId = null;
    } else if (!directSelectedNode || !directSelectedNode.isConnected || !directSelectedNodes.includes(directSelectedNode)) {
      directSelectedNode = directSelectedNodes[directSelectedNodes.length - 1];
      selectedId = ensureDirectId(directSelectedNode);
    }

    return directSelectedNodes;
  }

  function isDirectSelected(node) {
    return directSelectionNodes().includes(node);
  }

  function toggleDirectSelection(node) {
    const nodes = directSelectionNodes();
    if (nodes.includes(node)) {
      setDirectSelection(nodes.filter((item) => item !== node));
      return;
    }

    setDirectSelection([...nodes, node], node);
  }

  function selectDirectVisibleChildren() {
    if (editorMode !== "html" || !directSelectedNode) return;
    const children = visibleTreeChildren(directSelectedNode).filter((node) => isDirectNodeVisible(node));
    if (children.length) setDirectSelection(children, children[children.length - 1]);
  }

  function selectDirectSameClass() {
    if (editorMode !== "html" || !directSelectedNode) return;
    const doc = directSelectedNode.ownerDocument;
    const className = [...directSelectedNode.classList || []].find((name) => !name.startsWith("chiselo"));
    const parent = directSelectedNode.parentElement;
    const selector = className ? `.${cssEscape(className)}` : directSelectedNode.tagName.toLowerCase();
    const scope = parent && parent !== doc.documentElement ? parent : doc.body;
    const nodes = [...scope.querySelectorAll(selector)].filter((node) => isDirectNodeVisible(node));
    if (nodes.length > 1) setDirectSelection(nodes, directSelectedNode);
  }

  function updateHoverBox(node) {
    if (!node || !node.isConnected) {
      hoverBox.hidden = true;
      return;
    }

    const rect = directNodeRect(node);
    if (rect.w < 3 || rect.h < 3) {
      hoverBox.hidden = true;
      return;
    }

    hoverBox.hidden = false;
    hoverBox.style.left = `${rect.x}px`;
    hoverBox.style.top = `${rect.y}px`;
    hoverBox.style.width = `${rect.w}px`;
    hoverBox.style.height = `${rect.h}px`;
    hoverBox.innerHTML = `<div class="hover-label">${escapeHTML(directHoverLabel(node, rect))}</div>`;
  }

  function scheduleDirectHover(node) {
    pendingDirectHoverNode = node;
    if (directHoverFrame) return;

    directHoverFrame = requestAnimationFrame(() => {
      directHoverFrame = 0;
      const nextNode = pendingDirectHoverNode;
      pendingDirectHoverNode = null;

      if (!nextNode || isDirectSelected(nextNode)) {
        hoverBox.hidden = true;
        return;
      }

      updateHoverBox(nextNode);
    });
  }

  function cancelDirectHover() {
    pendingDirectHoverNode = null;
    if (directHoverFrame) {
      cancelAnimationFrame(directHoverFrame);
      directHoverFrame = 0;
    }
    hoverBox.hidden = true;
  }

  function directHoverLabel(node, rect) {
    const tag = node.tagName.toLowerCase();
    const size = `${Math.round(rect.w)} x ${Math.round(rect.h)}`;
    const resource = directResourceStatus(node);
    if (isImageLikeNode(node)) return `IMG ${size}${resource ? ` - ${resource}` : ""} - drag, resize, replace`;
    if (node.closest?.("td, th")) return `CELL ${size} - click, drag, edit table`;
    if (node.matches?.("table")) return `TABLE ${size} - click, drag, edit rows/cols`;
    if (normalizedText(node)) return `${tag.toUpperCase()} ${size} - double-click text`;
    return `${tag.toUpperCase()} ${size} - click, drag, resize`;
  }

  function appendDirectQuickActions(nodes, rect) {
    const bar = document.createElement("div");
    bar.className = `quick-action-bar${rect.y < 42 ? " is-below" : ""}`;
    bar.addEventListener("pointerdown", (event) => {
      event.preventDefault();
      event.stopPropagation();
    });

    const chip = document.createElement("span");
    chip.className = "quick-chip";
    chip.textContent = directQuickLabel(nodes, rect);
    bar.appendChild(chip);

    const actions = directQuickActions(nodes);
    for (const item of actions) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `quick-action${item.primary ? " is-primary" : ""}${item.danger ? " is-danger" : ""}`;
      button.textContent = item.label;
      button.title = item.title;
      button.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        runDirectQuickAction(item.action);
      });
      bar.appendChild(button);
    }

    selectionBox.appendChild(bar);
    requestAnimationFrame(() => clampDirectQuickActions(bar, rect));
  }

  function clampDirectQuickActions(bar, rect) {
    if (!bar.isConnected) return;
    const canvas = directCanvas();
    const width = bar.offsetWidth / Math.max(scale, 0.05);
    let left = 0;
    if (rect.x + width > canvas.width - 8) {
      left = Math.max(8 - rect.x, canvas.width - 8 - rect.x - width);
    }
    bar.style.left = `${Math.round(left)}px`;
  }

  function directQuickLabel(nodes, rect) {
    if (nodes.length > 1) return `${nodes.length} items ${Math.round(rect.w)} x ${Math.round(rect.h)}`;
    const node = nodes[0];
    if (!node) return "Selection";
    const tag = node.tagName.toLowerCase();
    const id = node.id ? `#${node.id}` : "";
    const className = [...node.classList || []]
      .filter((name) => !name.startsWith("chiselo"))
      .slice(0, 1)
      .map((name) => `.${name}`)
      .join("");
    return `${tag}${id}${className} ${Math.round(rect.w)} x ${Math.round(rect.h)}`;
  }

  function directQuickActions(nodes) {
    const actions = [];
    const single = nodes.length === 1 ? nodes[0] : null;
    const tableContext = directTableContext();

    if (single && directNodeAllowsTextEdit(single)) {
      actions.push({ action: "editText", label: "文字", title: "编辑文字", primary: true });
    }

    if (single && isImageLikeNode(single)) {
      actions.push({ action: "replaceImage", label: "替换", title: "替换图片", primary: true });
      actions.push({ action: "imageContain", label: "适应", title: "完整显示图片" });
      actions.push({ action: "imageCover", label: "填充", title: "填满图片框" });
    }

    if (tableContext?.table) {
      actions.push({ action: "addRow", label: "+行", title: "在选区后添加表格行" });
      actions.push({ action: "addColumn", label: "+列", title: "在选区后添加表格列" });
    }

    actions.push(
      { action: "duplicate", label: "复制", title: "复制选中对象" },
      { action: "fitWidth", label: "等宽", title: "适配页面宽度" },
      { action: "front", label: "置顶", title: "置于顶层" },
      { action: "back", label: "置底", title: "置于底层" },
      { action: "delete", label: "删除", title: "删除选中对象", danger: true }
    );

    return actions;
  }

  function runDirectQuickAction(action) {
    switch (action) {
      case "editText":
        if (directSelectedNode) beginDirectTextEdit(directSelectedNode);
        return;
      case "replaceImage":
        postMessage("requestReplaceImage");
        return;
      case "imageContain":
        styleSelectedImage({ objectFit: "contain" });
        return;
      case "imageCover":
        styleSelectedImage({ objectFit: "cover" });
        return;
      case "addRow":
        tableAddRowAfter();
        return;
      case "addColumn":
        tableAddColumnAfter();
        return;
      case "duplicate":
        duplicateSelected();
        return;
      case "fitWidth":
        fitSelected("width");
        return;
      case "front":
        arrangeSelected("front");
        return;
      case "back":
        arrangeSelected("back");
        return;
      case "delete":
        deleteSelected();
        return;
      default:
        return;
    }
  }

  function directNodeAllowsTextEdit(node) {
    if (!node || isImageLikeNode(node)) return false;
    if (["table", "thead", "tbody", "tfoot", "tr", "svg", "path", "line", "circle", "rect", "canvas", "video", "audio", "iframe", "input", "textarea", "select"].includes(node.tagName.toLowerCase())) return false;
    return normalizedText(node).length > 0 || node.matches?.("p,h1,h2,h3,h4,h5,h6,li,span,div,td,th,button,a");
  }

  function insertPlainTextAtSelection(doc, text) {
    if (!text) return;
    if (doc.queryCommandSupported?.("insertText")) {
      doc.execCommand("insertText", false, text);
      return;
    }

    const selection = doc.getSelection();
    if (!selection || selection.rangeCount === 0) return;
    const range = selection.getRangeAt(0);
    range.deleteContents();
    const textNode = doc.createTextNode(text);
    range.insertNode(textNode);
    range.setStartAfter(textNode);
    range.collapse(true);
    selection.removeAllRanges();
    selection.addRange(range);
  }

  function handleDirectPlainTextPaste(event) {
    const editable = event.target.closest?.("[contenteditable='true']");
    if (!editable) return;
    const text = event.clipboardData?.getData("text/plain") || "";
    if (!text) return;
    event.preventDefault();
    insertPlainTextAtSelection(editable.ownerDocument, text);
  }

  function lockDirectEditTypography(node) {
    const computed = node.ownerDocument.defaultView.getComputedStyle(node);
    const previous = {
      attr: node.getAttribute("data-chiselo-edit-font-lock"),
      vars: new Map()
    };

    const assignments = {
      "--chiselo-edit-font-family": computed.fontFamily || "inherit",
      "--chiselo-edit-font-size": computed.fontSize || "inherit",
      "--chiselo-edit-font-weight": computed.fontWeight || "inherit",
      "--chiselo-edit-line-height": computed.lineHeight || "normal",
      "--chiselo-edit-letter-spacing": computed.letterSpacing || "normal",
      "--chiselo-edit-color": computed.color || "inherit"
    };

    for (const [name, value] of Object.entries(assignments)) {
      previous.vars.set(name, {
        value: node.style.getPropertyValue(name),
        priority: node.style.getPropertyPriority(name)
      });
      node.style.setProperty(name, value);
    }
    node.setAttribute("data-chiselo-edit-font-lock", "true");

    return () => {
      if (previous.attr === null) node.removeAttribute("data-chiselo-edit-font-lock");
      else node.setAttribute("data-chiselo-edit-font-lock", previous.attr);
      for (const [name, item] of previous.vars) {
        if (item.value) node.style.setProperty(name, item.value, item.priority);
        else node.style.removeProperty(name);
      }
    };
  }

  function isImageLikeNode(node) {
    return Boolean(node?.matches?.("img,picture,source"));
  }

  function isDirectNonTextMediaTarget(node) {
    return Boolean(node?.closest?.("img,picture,video,audio,canvas,iframe"));
  }

  function directResourceStatus(node) {
    const image = node?.matches?.("img") ? node : node?.querySelector?.("img");
    if (!image) return "";
    const state = image.dataset.chiseloResourceState;
    if (state === "broken") return "missing";
    if (state === "loading") return "loading";
    if (image.getAttribute("original-src")) return "has preview source";
    if ((image.getAttribute("src") || "").startsWith("data:image/svg")) return "inline svg";
    if ((image.getAttribute("src") || "").startsWith("data:")) return "embedded";
    return "";
  }

  function setupDirectResourceTracking(doc) {
    for (const image of directSubtreeMatches(doc, "img")) {
      trackDirectImageResource(image);
    }

    for (const media of directSubtreeMatches(doc, "video, audio")) {
      trackDirectMediaResource(media);
    }
  }

  function trackDirectImageResource(image) {
    if (image.dataset.chiseloResourceTracked === "true") {
      const state = image.dataset.chiseloResourceState || "";
      if (!state || state === "loading") setDirectResourceState(image, image.complete ? (image.naturalWidth > 0 ? "ok" : "broken") : "loading", image.getAttribute("src") || "");
      return;
    }
    image.dataset.chiseloResourceTracked = "true";

    const update = () => {
      const src = image.currentSrc || image.getAttribute("src") || "";
      if (!src.trim()) {
        setDirectResourceState(image, "broken", "empty image source");
      } else if (image.complete && image.naturalWidth > 0) {
        setDirectResourceState(image, "ok", "");
      } else if (image.complete) {
        setDirectResourceState(image, "broken", src);
      } else {
        setDirectResourceState(image, "loading", src);
      }
      scheduleDirectLayoutRefresh();
    };

    image.addEventListener("load", update);
    image.addEventListener("error", update);
    update();
  }

  function trackDirectMediaResource(media) {
    if (media.dataset.chiseloResourceTracked === "true") return;
    media.dataset.chiseloResourceTracked = "true";
    const src = media.currentSrc || media.getAttribute("src") || media.querySelector("source")?.getAttribute("src") || "";
    setDirectResourceState(media, src ? "ok" : "broken", src || "empty media source");
  }

  function setDirectResourceState(node, state, detail) {
    const previousState = node.dataset.chiseloResourceState || "";
    const previousDetail = node.dataset.chiseloResourceDetail || "";
    node.dataset.chiseloResourceState = state;
    if (detail) {
      node.dataset.chiseloResourceDetail = detail;
    } else {
      delete node.dataset.chiseloResourceDetail;
    }
    if (state === "broken") {
      node.dataset.chiseloBrokenResource = "true";
    } else {
      delete node.dataset.chiseloBrokenResource;
    }
    if (previousState !== state || previousDetail !== (detail || "")) {
      scheduleHTMLDiagnosticsChanged();
    }
  }

  function normalizeDirectTablesForEditing(doc) {
    for (const table of directSubtreeMatches(doc, "table")) {
      if (!table.style.borderCollapse && table.getAttribute("border")) {
        table.style.borderCollapse = "collapse";
      }

      for (const cell of table.querySelectorAll("td, th")) {
        if (!cell.textContent.trim() && !cell.children.length) {
          cell.dataset.chiseloEmptyCell = "true";
        }
      }
    }
  }

  function directSubtreeMatches(root, selector) {
    if (!root?.querySelectorAll) return [];
    return uniqueElements([
      root.matches?.(selector) ? root : null,
      ...root.querySelectorAll(selector)
    ]);
  }

  function selectDirectRelative(kind) {
    if (editorMode !== "html" || !directSelectedNode) return;

    const doc = directSelectedNode.ownerDocument;
    let target = null;

    if (kind === "parent") {
      target = directSelectedNode.parentElement;
      if (target === doc.documentElement) target = doc.body;
    }

    if (kind === "child") {
      target = [...directSelectedNode.children].find((node) => isDirectNodeVisible(node)) || directSelectedNode.firstElementChild;
    }

    if (kind === "previous") {
      target = directSelectedNode.previousElementSibling;
    }

    if (kind === "next") {
      target = directSelectedNode.nextElementSibling;
    }

    if (target && target !== doc.documentElement) {
      selectDirectNode(target);
    }
  }

  function beginDirectDrag(event, node) {
    event.preventDefault();
    event.stopPropagation();
    if (!isDirectSelected(node)) {
      selectDirectNode(node);
    }

    pushHistory();
    const nodes = directSelectionNodes().length > 1 && isDirectSelected(node) ? [...directSelectionNodes()] : [node];
    const startRect = nodes.length > 1 ? directNodesBounds(nodes) : directNodeRect(node);
    const gestureContext = buildDirectGestureContext(nodes);
    const selectionPayloadBase = directSelectionPayloadBase(nodes, startRect);

    activeGesture = {
      mode: "html",
      type: "drag",
      node,
      nodes,
      startPoint: directPointFromEvent(event),
      startRect,
      lastRect: startRect,
      selectionPayloadBase,
      startRects: nodes.map((item) => ({ node: item, rect: gestureContext.rectContexts.get(item)?.startRect || directNodeRect(item) })),
      rectContexts: gestureContext.rectContexts,
      snapCandidates: gestureContext.snapCandidates
    };

    const doc = node.ownerDocument;
    doc.addEventListener("pointermove", continueGesture);
    doc.addEventListener("pointerup", endGesture, { once: true });
  }

  function beginDirectResize(event, handle) {
    if (event.button !== 0 || !directSelectedNode) return;
    event.preventDefault();
    event.stopPropagation();
    pushHistory();
    const nodes = directSelectionNodes();
    const startRect = nodes.length > 1 ? directNodesBounds(nodes) : directNodeRect(directSelectedNode);
    const gestureContext = buildDirectGestureContext(nodes);
    const selectionPayloadBase = directSelectionPayloadBase(nodes, startRect);

    activeGesture = {
      mode: "html",
      type: "resize",
      node: directSelectedNode,
      nodes,
      handle,
      startPoint: pointFromEvent(event),
      startRect,
      lastRect: startRect,
      selectionPayloadBase,
      startRects: nodes.map((item) => ({ node: item, rect: gestureContext.rectContexts.get(item)?.startRect || directNodeRect(item) })),
      rectContexts: gestureContext.rectContexts,
      snapCandidates: gestureContext.snapCandidates,
      ratio: startRect.w / startRect.h
    };

    document.addEventListener("pointermove", continueGesture);
    document.addEventListener("pointerup", endGesture, { once: true });
  }

  function continueDirectGesture(event) {
    const point = event.view === directFrame.contentWindow ? directPointFromEvent(event) : pointFromEvent(event);
    applyDirectGestureUpdate(point, event.shiftKey);
  }

  function applyDirectGestureUpdate(point, shiftKey = false) {
    if (!activeGesture || !point) return;
    const node = activeGesture.node;
    if (!node || !node.isConnected) return;

    const dx = point.x - activeGesture.startPoint.x;
    const dy = point.y - activeGesture.startPoint.y;
    const gestureNodes = (activeGesture.nodes || []).filter((item) => item?.isConnected);
    let nextRect = activeGesture.startRect;

    if (activeGesture.type === "drag") {
      nextRect = {
        ...activeGesture.startRect,
        x: activeGesture.startRect.x + dx,
        y: activeGesture.startRect.y + dy
      };
    }

    if (activeGesture.type === "resize") {
      nextRect = resizeRect(activeGesture.startRect, activeGesture.handle, dx, dy, shiftKey ? activeGesture.ratio : null);
    }

    const activeSet = new Set(gestureNodes.length ? gestureNodes : [node]);
    const snapped = snapDirectRect(nextRect, activeSet, activeGesture.snapCandidates);
    activeGesture.lastRect = snapped.rect;
    if (gestureNodes.length > 1) {
      applyDirectGroupRects(activeGesture.startRects, activeGesture.startRect, snapped.rect, activeGesture.rectContexts);
    } else {
      applyDirectRect(node, snapped.rect, activeGesture.rectContexts?.get(node));
    }
    showGuides(snapped.guides);
    scheduleSelectionBoxUpdate();
    postSelectionChanged();
  }

  function directPointFromEvent(event) {
    const win = event.view || directFrame.contentWindow;
    return {
      x: event.clientX + (win?.scrollX || 0),
      y: event.clientY + (win?.scrollY || 0)
    };
  }

  function directNodeRect(node) {
    const win = node.ownerDocument.defaultView;
    const rect = node.getBoundingClientRect();
    return {
      x: Math.round(rect.left + win.scrollX),
      y: Math.round(rect.top + win.scrollY),
      w: Math.round(rect.width),
      h: Math.round(rect.height),
      rotation: 0
    };
  }

  function directNodesBounds(nodes) {
    const rects = nodes
      .filter((node) => node?.isConnected)
      .map((node) => directNodeRect(node));

    if (!rects.length) return { x: 0, y: 0, w: 0, h: 0, rotation: 0 };

    const left = Math.min(...rects.map((rect) => rect.x));
    const top = Math.min(...rects.map((rect) => rect.y));
    const right = Math.max(...rects.map((rect) => rect.x + rect.w));
    const bottom = Math.max(...rects.map((rect) => rect.y + rect.h));

    return {
      x: Math.round(left),
      y: Math.round(top),
      w: Math.round(right - left),
      h: Math.round(bottom - top),
      rotation: 0
    };
  }

  function buildDirectGestureContext(nodes) {
    const activeSet = new Set((nodes || []).filter((node) => node?.isConnected));
    const rectContexts = new Map();

    for (const node of activeSet) {
      rectContexts.set(node, directRectContext(node, activeSet));
    }

    return {
      rectContexts,
      snapCandidates: buildDirectSnapCandidates(activeSet)
    };
  }

  function directRectContext(node, activeSet) {
    const startRect = directNodeRect(node);
    const anchor = positionedAncestor(node);
    const selectedAncestor = directSelectedAncestor(node, activeSet);

    if (directLayoutMode === "transform" && !node.dataset.chiseloBaseTransform) {
      node.dataset.chiseloBaseTransform = node.style.transform || "none";
      node.dataset.chiseloTranslateX = "0";
      node.dataset.chiseloTranslateY = "0";
    }

    return {
      startRect,
      anchor,
      anchorRect: anchor ? directNodeRect(anchor) : { x: 0, y: 0 },
      canUseAnchorCache: !anchor || !activeSet.has(anchor),
      canUseTransformCache: !selectedAncestor,
      baseTransform: node.dataset.chiseloBaseTransform || node.style.transform || "none",
      translateX: Number(node.dataset.chiseloTranslateX || 0),
      translateY: Number(node.dataset.chiseloTranslateY || 0)
    };
  }

  function directSelectedAncestor(node, activeSet) {
    let parent = node.parentElement;
    const doc = node.ownerDocument;
    while (parent && parent !== doc.body && parent !== doc.documentElement) {
      if (activeSet.has(parent)) return parent;
      parent = parent.parentElement;
    }
    return null;
  }

  function buildDirectSnapCandidates(activeNodes) {
    const canvas = directCanvas();
    const x = [
      { value: 0, label: "文档左边" },
      { value: canvas.width / 2, label: "文档中线" },
      { value: canvas.width, label: "文档右边" }
    ];
    const y = [
      { value: 0, label: "文档顶部" },
      { value: canvas.height / 2, label: "文档中线" },
      { value: canvas.height, label: "文档底部" }
    ];

    const doc = directFrame?.contentDocument;
    if (!doc) return { x, y };

    for (const frame of directPageFrames()) {
      const rect = frame.rect;
      const label = frame.label || "页面";
      x.push(
        { value: rect.x, label: `${label}左边` },
        { value: rect.x + rect.w / 2, label: `${label}中线` },
        { value: rect.x + rect.w, label: `${label}右边` }
      );
      y.push(
        { value: rect.y, label: `${label}顶部` },
        { value: rect.y + rect.h / 2, label: `${label}中线` },
        { value: rect.y + rect.h, label: `${label}底部` }
      );
    }

    const nodes = [...doc.querySelectorAll("[data-chiselo-id]")].slice(0, 600);
    for (const node of nodes) {
      if (activeNodes.has(node) || !isDirectNodeVisible(node)) continue;
      const nodeRect = directNodeRect(node);
      const label = directSemanticForNode(node).label || "对象";
      x.push(
        { value: nodeRect.x, label: `${label}左边` },
        { value: nodeRect.x + nodeRect.w / 2, label: `${label}中线` },
        { value: nodeRect.x + nodeRect.w, label: `${label}右边` }
      );
      y.push(
        { value: nodeRect.y, label: `${label}顶部` },
        { value: nodeRect.y + nodeRect.h / 2, label: `${label}中线` },
        { value: nodeRect.y + nodeRect.h, label: `${label}底部` }
      );
    }

    return { x, y };
  }

  function applyDirectRect(node, rect, context = null) {
    if (directLayoutMode === "transform") {
      applyDirectTransformRect(node, rect, context);
      return;
    }

    applyDirectFreeRect(node, rect, context);
  }

  function applyDirectFreeRect(node, rect, context = null) {
    const anchor = context?.canUseAnchorCache ? context.anchor : positionedAncestor(node);
    const anchorRect = context?.canUseAnchorCache
      ? context.anchorRect
      : anchor
        ? directNodeRect(anchor)
        : { x: 0, y: 0 };
    node.style.position = "absolute";
    node.style.boxSizing = "border-box";
    node.style.left = `${Math.round(rect.x - anchorRect.x)}px`;
    node.style.top = `${Math.round(rect.y - anchorRect.y)}px`;
    node.style.width = `${Math.max(MIN_SIZE, Math.round(rect.w))}px`;
    node.style.height = `${Math.max(MIN_SIZE, Math.round(rect.h))}px`;
  }

  function applyDirectGroupRects(startRects, startGroupRect, nextGroupRect, rectContexts = null) {
    const scaleX = startGroupRect.w ? nextGroupRect.w / startGroupRect.w : 1;
    const scaleY = startGroupRect.h ? nextGroupRect.h / startGroupRect.h : 1;

    for (const item of startRects) {
      const rect = item.rect;
      applyDirectRect(item.node, {
        x: nextGroupRect.x + (rect.x - startGroupRect.x) * scaleX,
        y: nextGroupRect.y + (rect.y - startGroupRect.y) * scaleY,
        w: Math.max(MIN_SIZE, rect.w * scaleX),
        h: Math.max(MIN_SIZE, rect.h * scaleY)
      }, rectContexts?.get(item.node));
    }
  }

  function applyDirectTransformRect(node, rect, context = null) {
    if (!node.dataset.chiseloBaseTransform) {
      node.dataset.chiseloBaseTransform = node.style.transform || "none";
      node.dataset.chiseloTranslateX = "0";
      node.dataset.chiseloTranslateY = "0";
    }

    const useCache = context?.canUseTransformCache && context.startRect;
    const currentRect = useCache ? null : directNodeRect(node);
    const tx = useCache
      ? context.translateX + (rect.x - context.startRect.x)
      : Number(node.dataset.chiseloTranslateX || 0) + (rect.x - currentRect.x);
    const ty = useCache
      ? context.translateY + (rect.y - context.startRect.y)
      : Number(node.dataset.chiseloTranslateY || 0) + (rect.y - currentRect.y);
    const baseTransform = useCache ? context.baseTransform : node.dataset.chiseloBaseTransform;
    const base = baseTransform === "none" ? "" : baseTransform;

    node.dataset.chiseloTranslateX = String(Math.round(tx));
    node.dataset.chiseloTranslateY = String(Math.round(ty));
    node.style.boxSizing = "border-box";
    node.style.width = `${Math.max(MIN_SIZE, Math.round(rect.w))}px`;
    node.style.height = `${Math.max(MIN_SIZE, Math.round(rect.h))}px`;
    node.style.transform = `${base} translate(${Math.round(tx)}px, ${Math.round(ty)}px)`.trim();
  }

  function positionedAncestor(node) {
    const doc = node.ownerDocument;
    let parent = node.parentElement;
    while (parent && parent !== doc.body && parent !== doc.documentElement) {
      const style = doc.defaultView.getComputedStyle(parent);
      if (style.position !== "static") return parent;
      parent = parent.parentElement;
    }
    return null;
  }

  function snapDirectRect(inputRect, activeNode, cachedCandidates = null) {
    const rect = { ...inputRect };
    const guides = [];
    const activeNodes = activeNode instanceof Set ? activeNode : new Set(activeNode ? [activeNode] : []);
    const candidates = cachedCandidates || buildDirectSnapCandidates(activeNodes);
    const xCandidates = candidates.x;
    const yCandidates = candidates.y;

    const xEdges = [
      { value: () => rect.x, apply: (value) => { rect.x = value; } },
      { value: () => rect.x + rect.w / 2, apply: (value) => { rect.x = value - rect.w / 2; } },
      { value: () => rect.x + rect.w, apply: (value) => { rect.x = value - rect.w; } }
    ];
    const yEdges = [
      { value: () => rect.y, apply: (value) => { rect.y = value; } },
      { value: () => rect.y + rect.h / 2, apply: (value) => { rect.y = value - rect.h / 2; } },
      { value: () => rect.y + rect.h, apply: (value) => { rect.y = value - rect.h; } }
    ];

    const xSnap = bestSnap(xEdges, xCandidates);
    if (xSnap) {
      xSnap.edge.apply(xSnap.candidate.value);
      guides.push({ axis: "x", value: xSnap.candidate.value, label: xSnap.candidate.label });
    }

    const ySnap = bestSnap(yEdges, yCandidates);
    if (ySnap) {
      ySnap.edge.apply(ySnap.candidate.value);
      guides.push({ axis: "y", value: ySnap.candidate.value, label: ySnap.candidate.label });
    }

    rect.x = Math.round(rect.x);
    rect.y = Math.round(rect.y);
    rect.w = Math.round(rect.w);
    rect.h = Math.round(rect.h);
    return { rect, guides };
  }

  function isDirectNodeVisible(node) {
    const style = node.ownerDocument.defaultView.getComputedStyle(node);
    const rect = node.getBoundingClientRect();
    return isVisibleStyle(style) && rect.width > 3 && rect.height > 3;
  }

  function beginDirectTextEdit(node) {
    if (!node || !directNodeAllowsTextEdit(node)) return null;
    pendingDirectTextEditNode = null;
    selectDirectNode(node);
    pushHistory();
    activeDirectTextEditNode = node;
    const unlockTypography = lockDirectEditTypography(node);
    node.setAttribute("contenteditable", "true");
    node.setAttribute("spellcheck", "true");
    node.focus();

    selectDirectTextContents(node);
    node.ownerDocument.defaultView.requestAnimationFrame(() => selectDirectTextContents(node));
    setTimeout(() => {
      if (node.isConnected && node.getAttribute("contenteditable") === "true") {
        selectDirectTextContents(node);
      }
    }, 80);

    const finish = () => {
      if (activeDirectTextEditNode === node) activeDirectTextEditNode = null;
      node.removeAttribute("contenteditable");
      node.removeAttribute("spellcheck");
      unlockTypography();
      node.removeEventListener("blur", finish);
      node.removeEventListener("keydown", handleEditingKeydown);
      scheduleHTMLTreeChanged();
      scheduleHTMLDiagnosticsChanged();
      postSelectionChanged();
    };

    const handleEditingKeydown = (event) => {
      if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
        event.preventDefault();
        node.blur();
      }
      if (event.key === "Escape") {
        event.preventDefault();
        node.blur();
      }
    };

    node.addEventListener("blur", finish);
    node.addEventListener("keydown", handleEditingKeydown);
    postSelectionChanged();
    return node;
  }

  function scheduleDirectTextEdit(node) {
    pendingDirectTextEditNode = node;
    setTimeout(() => {
      if (pendingDirectTextEditNode !== node) return;
      pendingDirectTextEditNode = null;
      if (node?.isConnected) beginDirectTextEdit(node);
    }, 35);
  }

  function selectDirectTextContents(node) {
    const selection = node.ownerDocument.defaultView.getSelection();
    const range = node.ownerDocument.createRange();
    range.selectNodeContents(node);
    selection.removeAllRanges();
    selection.addRange(range);
  }

  function updateDirectElement(nextElement) {
    const nodes = directSelectionNodes();
    if (nodes.length > 1) {
      updateDirectGroupElement(nodes, nextElement);
      return;
    }

    if (!directSelectedNode || !directSelectedNode.isConnected) return;
    pushHistory({ coalesceKey: directHistoryCoalesceKey("direct-update", nodes), interval: 800 });
    applyDirectRect(directSelectedNode, nextElement);
    applyDirectStyle(directSelectedNode, nextElement.style || {});
    applyDirectImageMetadata(directSelectedNode, nextElement);
    updateSelectionBox();
    scheduleHTMLDiagnosticsChanged();
    postSelectionChanged();
  }

  function updateDirectGroupElement(nodes, nextElement) {
    if (!nodes.length) return;

    pushHistory({ coalesceKey: directHistoryCoalesceKey("direct-group-update", nodes), interval: 800 });
    const currentRect = directNodesBounds(nodes);
    const nextRect = {
      x: Number.isFinite(nextElement.x) ? nextElement.x : currentRect.x,
      y: Number.isFinite(nextElement.y) ? nextElement.y : currentRect.y,
      w: Number.isFinite(nextElement.w) ? nextElement.w : currentRect.w,
      h: Number.isFinite(nextElement.h) ? nextElement.h : currentRect.h
    };
    const startRects = nodes.map((node) => ({ node, rect: directNodeRect(node) }));
    applyDirectGroupRects(startRects, currentRect, nextRect);

    if (nextElement.style) {
      for (const node of nodes) {
        applyDirectStyle(node, nextElement.style);
      }
    }

    updateSelectionBox();
    scheduleHTMLDiagnosticsChanged();
    postSelectionChanged();
  }

  function applyDirectStyle(node, style) {
    if (style.fontFamily) node.style.fontFamily = style.fontFamily;
    if (Number.isFinite(style.fontSize)) node.style.fontSize = `${style.fontSize}px`;
    if (Number.isFinite(style.fontWeight)) node.style.fontWeight = `${style.fontWeight}`;
    if (Number.isFinite(style.lineHeight)) node.style.lineHeight = `${style.lineHeight}`;
    if (style.color) node.style.color = style.color;
    if (style.textAlign) node.style.textAlign = style.textAlign;
    if (style.fill) node.style.background = style.fill;

    if (Number.isFinite(style.strokeWidth)) {
      const color = style.stroke || node.ownerDocument.defaultView.getComputedStyle(node).borderTopColor || "transparent";
      node.style.border = `${Math.max(0, style.strokeWidth)}px solid ${color}`;
    } else if (style.stroke) {
      node.style.borderColor = style.stroke;
    }

    if (Number.isFinite(style.radius)) node.style.borderRadius = `${Math.max(0, style.radius)}px`;
    if (style.shadow) node.style.boxShadow = shadowValue(style.shadow);

    if (style.objectFit) {
      const image = node.matches?.("img") ? node : node.querySelector?.("img");
      if (image) image.style.objectFit = objectFitValue(style.objectFit, "cover");
    }
  }

  function applyDirectImageMetadata(node, nextElement) {
    if (!node.matches?.("img")) return;
    if (typeof nextElement.imageSource === "string") node.setAttribute("src", nextElement.imageSource);
    if (typeof nextElement.imageAlt === "string") node.setAttribute("alt", nextElement.imageAlt);
  }

  function nextFrame() {
    return new Promise((resolve) => {
      let settled = false;
      const finish = () => {
        if (settled) return;
        settled = true;
        resolve();
      };
      requestAnimationFrame(finish);
      setTimeout(finish, 50);
    });
  }

  function waitForImageReady(image, timeout = 700) {
    if (!image || !image.isConnected) return Promise.resolve();
    return new Promise((resolve) => {
      let settled = false;
      let timer = null;
      const cleanup = () => {
        image.removeEventListener("load", finish);
        image.removeEventListener("error", finish);
        if (timer) clearTimeout(timer);
      };
      const finish = () => {
        if (settled) return;
        settled = true;
        cleanup();
        resolve();
      };

      if (image.complete) {
        queueMicrotask(finish);
      } else {
        image.addEventListener("load", finish, { once: true });
        image.addEventListener("error", finish, { once: true });
        timer = setTimeout(finish, timeout);
      }
    });
  }

  async function settleDirectImageNode(image) {
    if (editorMode !== "html" || !image || !image.isConnected) return null;
    await waitForImageReady(image);
    await nextFrame();
    await nextFrame();
    if (!image.isConnected) return null;

    scheduleDirectLayoutRefresh();
    scheduleHTMLTreeChanged();
    scheduleHTMLDiagnosticsChanged();

    if (isDirectSelected(image)) {
      updateSelectionBox();
      postSelectionChanged();
    }

    return isDirectSelected(image) ? selectedElement() : directElementPayloadForNode(image, directNodeRect(image));
  }

  function replaceSelectedImageSrc(src) {
    if (editorMode !== "html" || !directSelectedNode) return null;
    const image = selectedImageNode();
    if (!image) return null;

    pushHistory();
    image.setAttribute("src", src);
    selectDirectNode(image);
    scheduleHTMLTreeChanged();
    postSelectionChanged();
    const result = selectedElement();
    settleDirectImageNode(image);
    return result;
  }

  function replaceSelectedImageFromBase64(mimeType, base64) {
    if (!mimeType || !base64) return null;
    return replaceSelectedImageSrc(`data:${mimeType};base64,${base64}`);
  }

  function settleSelectedImage() {
    return settleDirectImageNode(selectedImageNode());
  }

  function selectedImageNode() {
    if (!directSelectedNode || !directSelectedNode.isConnected) return null;
    if (directSelectedNode.matches?.("img")) return directSelectedNode;
    return directSelectedNode.querySelector?.("img") || null;
  }

  function styleSelectedImage(style) {
    const image = selectedImageNode();
    if (!image) return null;
    pushHistory();
    image.style.width = "100%";
    image.style.height = "100%";
    image.style.objectFit = objectFitValue(style.objectFit, "contain");
    if (style.shadow) image.style.boxShadow = shadowValue(style.shadow);
    selectDirectNode(image);
    scheduleHTMLTreeChanged();
    postSelectionChanged();
    return selectedElement();
  }

  function tableAddRowAfter() {
    const context = directTableContext();
    if (!context?.row) return null;

    pushHistory();
    const row = cloneTableRow(context);
    context.row.insertAdjacentElement("afterend", row);
    const target = row.cells[Math.min(context.columnIndex, Math.max(0, row.cells.length - 1))] || row;
    selectDirectNode(target);
    scheduleHTMLTreeChanged();
    return selectedElement();
  }

  function tableDeleteRow() {
    const context = directTableContext();
    if (!context?.row || context.rows.length <= 1) return null;

    pushHistory();
    const currentIndex = context.rows.indexOf(context.row);
    const targetRow = context.rows[currentIndex + 1] || context.rows[currentIndex - 1] || null;
    context.row.remove();
    if (targetRow?.isConnected) {
      selectDirectNode(targetRow.cells[Math.min(context.columnIndex, Math.max(0, targetRow.cells.length - 1))] || targetRow);
    } else {
      directSelectedNode = null;
      selectedId = null;
      updateSelectionBox();
      postSelectionChanged();
    }
    scheduleHTMLTreeChanged();
    return selectedElement();
  }

  function tableAddColumnAfter() {
    const context = directTableContext();
    if (!context?.table || !context.rows.length) return null;

    pushHistory();
    let selectedCell = null;
    const insertAfterColumn = context.columnIndex;
    const grid = tableGrid(context.table);

    for (let rowIndex = 0; rowIndex < context.rows.length; rowIndex += 1) {
      const row = context.rows[rowIndex];
      const rowEntries = uniqueTableEntries(grid.rows[rowIndex] || []);
      const spanning = rowEntries.find((entry) => entry.start <= insertAfterColumn && entry.end > insertAfterColumn + 1);
      if (spanning) {
        spanning.cell.setAttribute("colspan", String(spanning.colspan + 1));
        if (row === context.row) selectedCell = spanning.cell;
        continue;
      }

      const previous = [...rowEntries].reverse().find((entry) => entry.end <= insertAfterColumn + 1);
      const next = rowEntries.find((entry) => entry.start > insertAfterColumn);
      const reference = previous?.cell || next?.cell || context.cell || context.table.querySelector("td, th");
      const cell = cloneTableCell(reference || row.ownerDocument.createElement("td"));
      if (previous?.cell) {
        previous.cell.insertAdjacentElement("afterend", cell);
      } else if (next?.cell) {
        row.insertBefore(cell, next.cell);
      } else {
        row.appendChild(cell);
      }
      if (row === context.row) selectedCell = cell;
    }

    if (selectedCell) selectDirectNode(selectedCell);
    scheduleHTMLTreeChanged();
    return selectedElement();
  }

  function tableDeleteColumn() {
    const context = directTableContext();
    if (!context?.table || maxTableColumns(context.table) <= 1) return null;

    pushHistory();
    let nextSelection = null;
    const grid = tableGrid(context.table);
    const touched = new Set();

    for (let rowIndex = 0; rowIndex < context.rows.length; rowIndex += 1) {
      const entry = grid.rows[rowIndex]?.[context.columnIndex];
      if (!entry || touched.has(entry.cell)) continue;
      touched.add(entry.cell);
      const fallback = entry.cell.nextElementSibling || entry.cell.previousElementSibling || entry.cell.parentElement;
      if (entry.cell === context.cell || entry.row === context.row) nextSelection = fallback;

      if (entry.colspan > 1) {
        entry.cell.setAttribute("colspan", String(entry.colspan - 1));
      } else {
        entry.cell.remove();
      }
    }

    if (nextSelection?.isConnected) selectDirectNode(nextSelection);
    scheduleHTMLTreeChanged();
    return selectedElement();
  }

  function styleSelectedTableCell(style) {
    const context = directTableContext();
    if (!context?.cell) return null;

    pushHistory();
    applyDirectStyle(context.cell, style);
    selectDirectNode(context.cell);
    scheduleHTMLTreeChanged();
    postSelectionChanged();
    return selectedElement();
  }

  function directTableContext() {
    if (editorMode !== "html" || !directSelectedNode || !directSelectedNode.isConnected) return null;
    const selected = directSelectedNode;
    const table = selected.matches?.("table") ? selected : selected.closest?.("table");
    if (!table) return null;

    const rows = [...table.rows];
    const cell = selected.matches?.("td, th") ? selected : selected.closest?.("td, th");
    const row = cell?.parentElement || (selected.matches?.("tr") ? selected : selected.closest?.("tr")) || rows[0] || null;
    const grid = tableGrid(table);
    const rowIndex = row ? rows.indexOf(row) : 0;
    const columnIndex = cell ? tableLogicalColumnIndex(grid, cell) : 0;

    return { table, rows, cell, row, rowIndex, columnIndex, grid };
  }

  function cloneTableRow(context) {
    const doc = context.row.ownerDocument;
    const row = doc.createElement("tr");
    const grid = tableGrid(context.table);
    const insertAfterRow = Math.max(0, context.rowIndex);
    const occupiedColumns = new Set();

    for (const entry of grid.entries) {
      if (entry.rowStart <= insertAfterRow && entry.rowEnd > insertAfterRow + 1) {
        entry.cell.setAttribute("rowspan", String(entry.rowspan + 1));
        for (let column = entry.start; column < entry.end; column += 1) {
          occupiedColumns.add(column);
        }
      }
    }

    const reference = context.cell || context.row.cells[0] || context.table.querySelector("td, th");
    const columns = Math.max(1, grid.maxColumns);
    for (let column = 0; column < columns; column += 1) {
      if (occupiedColumns.has(column)) continue;
      const cell = cloneTableCell(reference || doc.createElement("td"));
      resetInsertedTableCell(cell, reference?.tagName?.toLowerCase() === "th" ? "新表头" : "新单元格");
      row.appendChild(cell);
    }

    prepareClonedDirectSubtree(row);
    return row;
  }

  function cloneTableCell(referenceCell) {
    const cell = referenceCell.cloneNode(true);
    prepareClonedDirectSubtree(cell);
    resetInsertedTableCell(cell, referenceCell.tagName.toLowerCase() === "th" ? "新表头" : "新单元格");
    return cell;
  }

  function prepareClonedDirectSubtree(root) {
    for (const node of [root, ...root.querySelectorAll("*")]) {
      stripChiseloAttributes(node);
      ensureDirectId(node);
    }
  }

  function resetInsertedTableCell(cell, label) {
    cell.removeAttribute("rowspan");
    cell.removeAttribute("colspan");
    while (cell.firstChild) cell.firstChild.remove();
    cell.textContent = label;
  }

  function maxTableColumns(table) {
    return tableGrid(table).maxColumns;
  }

  function tableGrid(table) {
    const rows = [...table.rows];
    const gridRows = [];
    const entries = [];
    let maxColumns = 0;

    for (let rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
      const row = rows[rowIndex];
      gridRows[rowIndex] = gridRows[rowIndex] || [];
      let column = 0;

      for (const cell of row.cells) {
        while (gridRows[rowIndex][column]) column += 1;
        const colspan = positiveSpan(cell.getAttribute("colspan"));
        const rowspan = positiveSpan(cell.getAttribute("rowspan"));
        const entry = {
          cell,
          row,
          rowStart: rowIndex,
          rowEnd: rowIndex + rowspan,
          start: column,
          end: column + colspan,
          colspan,
          rowspan
        };
        entries.push(entry);

        for (let r = rowIndex; r < rowIndex + rowspan; r += 1) {
          gridRows[r] = gridRows[r] || [];
          for (let c = column; c < column + colspan; c += 1) {
            gridRows[r][c] = entry;
          }
        }
        column += colspan;
      }

      maxColumns = Math.max(maxColumns, gridRows[rowIndex].length);
    }

    return { rows: gridRows, entries, maxColumns };
  }

  function positiveSpan(value) {
    const parsed = parseInt(value || "1", 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 1;
  }

  function uniqueTableEntries(entries) {
    const unique = [];
    const seen = new Set();
    for (const entry of entries) {
      if (!entry || seen.has(entry.cell)) continue;
      seen.add(entry.cell);
      unique.push(entry);
    }
    return unique.sort((a, b) => a.start - b.start);
  }

  function tableLogicalColumnIndex(grid, cell) {
    return grid.entries.find((entry) => entry.cell === cell)?.start || 0;
  }

  function topLevelDirectNodes(nodes) {
    return nodes.filter((node) => !nodes.some((other) => other !== node && other.contains?.(node)));
  }

  function deleteDirectSelected() {
    const nodes = topLevelDirectNodes(directSelectionNodes());
    if (!nodes.length) return false;
    pushHistory();
    for (const node of nodes) {
      node.remove();
    }
    directSelectedNode = null;
    directSelectedNodes = [];
    selectedId = null;
    updateSelectionBox();
    scheduleHTMLTreeChanged();
    postSelectionChanged();
    return true;
  }

  function duplicateDirectSelected() {
    const nodes = topLevelDirectNodes(directSelectionNodes());
    if (!nodes.length) return false;

    pushHistory();
    const copies = [];
    for (const node of nodes) {
      const copy = node.cloneNode(true);
      prepareClonedDirectSubtree(copy);
      node.insertAdjacentElement("afterend", copy);
      const rect = directNodeRect(node);
      applyDirectFreeRect(copy, {
        ...rect,
        x: rect.x + 18,
        y: rect.y + 18
      });
      copies.push(copy);
    }

    setDirectSelection(copies, copies[copies.length - 1]);
    scheduleHTMLTreeChanged();
    return true;
  }

  function alignDirectSelected(edge) {
    const nodes = directSelectionNodes();
    if (!nodes.length) return;
    pushHistory();
    const rect = nodes.length > 1 ? directNodesBounds(nodes) : directNodeRect(directSelectedNode);
    const frame = directAlignmentFrame(directSelectedNode);
    const original = { ...rect };
    if (edge === "left") rect.x = frame.x;
    if (edge === "center") rect.x = Math.round(frame.x + (frame.w - rect.w) / 2);
    if (edge === "right") rect.x = Math.round(frame.x + frame.w - rect.w);
    if (edge === "top") rect.y = frame.y;
    if (edge === "middle") rect.y = Math.round(frame.y + (frame.h - rect.h) / 2);
    if (edge === "bottom") rect.y = Math.round(frame.y + frame.h - rect.h);
    if (nodes.length > 1) {
      for (const node of nodes) {
        const nodeRect = directNodeRect(node);
        nodeRect.x += rect.x - original.x;
        nodeRect.y += rect.y - original.y;
        applyDirectRect(node, nodeRect);
      }
    } else {
      applyDirectRect(directSelectedNode, rect);
    }
    updateSelectionBox();
    postSelectionChanged();
  }

  function matchDirectSelectedSize(mode) {
    const nodes = topLevelDirectNodes(directSelectionNodes());
    if (nodes.length < 2 || !directSelectedNode?.isConnected) return;

    const reference = nodes.includes(directSelectedNode) ? directSelectedNode : nodes[0];
    const referenceRect = directNodeRect(reference);

    pushHistory();
    for (const node of nodes) {
      const rect = directNodeRect(node);
      if (mode === "width") rect.w = referenceRect.w;
      if (mode === "height") rect.h = referenceRect.h;
      applyDirectRect(node, rect);
    }
    setDirectSelection(nodes, reference);
    updateSelectionBox();
    scheduleDirectLayoutRefresh();
    postSelectionChanged();
  }

  function distributeDirectSelected(axis) {
    const nodes = topLevelDirectNodes(directSelectionNodes());
    if (nodes.length < 3) return;

    const ordered = [...nodes].sort((a, b) => {
      const rectA = directNodeRect(a);
      const rectB = directNodeRect(b);
      return axis === "horizontal" ? rectA.x - rectB.x : rectA.y - rectB.y;
    });
    const rects = ordered.map((node) => ({ node, rect: directNodeRect(node) }));
    const bounds = directNodesBounds(ordered);
    const totalSize = rects.reduce((sum, item) => sum + (axis === "horizontal" ? item.rect.w : item.rect.h), 0);
    const span = axis === "horizontal" ? bounds.w : bounds.h;
    const gap = (span - totalSize) / Math.max(1, rects.length - 1);

    pushHistory();
    let cursor = axis === "horizontal" ? bounds.x : bounds.y;
    for (const item of rects) {
      const nextRect = { ...item.rect };
      if (axis === "horizontal") {
        nextRect.x = cursor;
        cursor += nextRect.w + gap;
      } else {
        nextRect.y = cursor;
        cursor += nextRect.h + gap;
      }
      applyDirectRect(item.node, nextRect);
    }

    setDirectSelection(nodes, directSelectedNode && nodes.includes(directSelectedNode) ? directSelectedNode : nodes[nodes.length - 1]);
    updateSelectionBox();
    scheduleDirectLayoutRefresh();
    postSelectionChanged();
  }

  function fitDirectSelected(mode) {
    const nodes = directSelectionNodes();
    if (!nodes.length) return;

    pushHistory();
    const rect = nodes.length > 1 ? directNodesBounds(nodes) : directNodeRect(directSelectedNode);
    const original = { ...rect };
    const frame = directAlignmentFrame(directSelectedNode);
    if (mode === "width" || mode === "page") {
      rect.x = frame.x;
      rect.w = frame.w;
    }
    if (mode === "height" || mode === "page") {
      rect.y = frame.y;
      rect.h = frame.h;
    }
    if (nodes.length > 1) {
      const startRects = nodes.map((node) => ({ node, rect: directNodeRect(node) }));
      applyDirectGroupRects(startRects, original, rect);
    } else {
      applyDirectRect(directSelectedNode, rect);
    }
    updateSelectionBox();
    postSelectionChanged();
  }

  function snapDirectSelectedToGrid(grid) {
    const nodes = directSelectionNodes();
    if (!nodes.length) return;

    pushHistory();
    const rect = nodes.length > 1 ? directNodesBounds(nodes) : directNodeRect(directSelectedNode);
    const original = { ...rect };
    rect.x = snapNumber(rect.x, grid);
    rect.y = snapNumber(rect.y, grid);
    rect.w = Math.max(MIN_SIZE, snapNumber(rect.w, grid));
    rect.h = Math.max(MIN_SIZE, snapNumber(rect.h, grid));
    if (nodes.length > 1) {
      const startRects = nodes.map((node) => ({ node, rect: directNodeRect(node) }));
      applyDirectGroupRects(startRects, original, rect);
    } else {
      applyDirectRect(directSelectedNode, rect);
    }
    updateSelectionBox();
    postSelectionChanged();
  }

  function directAlignmentFrame(node) {
    const page = directPageFrameNodeFor(node);
    if (page) return directNodeRect(page);
    return directCanvasRect();
  }

  function directCanvasRect() {
    const canvas = directCanvas();
    return { x: 0, y: 0, w: canvas.width, h: canvas.height };
  }

  function directPageFrames() {
    const doc = directFrame?.contentDocument;
    if (!doc?.body) {
      return [{ index: 0, label: "页面", rect: directCanvasRect() }];
    }

    const candidates = directPageFrameCandidates(doc);
    const candidateSet = new Set(candidates);
    const topLevelPages = candidates.filter((node) => {
      let parent = node.parentElement;
      while (parent && parent !== doc.body && parent !== doc.documentElement) {
        if (candidateSet.has(parent)) return false;
        parent = parent.parentElement;
      }
      return true;
    });

    const pages = topLevelPages.length ? topLevelPages : [doc.body];
    return pages.map((node, index) => {
      const rect = node === doc.body ? directCanvasRect() : directNodeRect(node);
      return {
        index,
        label: pageFrameLabel(node, index, pages.length),
        rect
      };
    });
  }

  function pageFrameLabel(node, index, total) {
    if (!node || node.matches?.("body")) {
      return total > 1 ? `页面 ${index + 1}` : "页面";
    }
    const explicit = node.getAttribute("data-title")
      || node.getAttribute("aria-label")
      || node.getAttribute("title")
      || "";
    if (explicit.trim()) return explicit.trim().slice(0, 28);
    const semantic = directSemanticForNode(node);
    if (semantic.role === "page") return total > 1 ? `页面 ${index + 1}` : "页面";
    return total > 1 ? `${semantic.label} ${index + 1}` : semantic.label;
  }

  function directPageFrameCandidates(doc) {
    if (!doc?.body) return [];
    return uniqueElements([...doc.querySelectorAll(DIRECT_FIXED_FRAME_SELECTOR)])
      .filter((node) => node !== doc.body && node !== doc.documentElement && isDirectPageFrameCandidate(node));
  }

  function isDirectPageFrameCandidate(node) {
    if (!node?.getBoundingClientRect || !isDirectNodeVisible(node)) return false;
    const rect = node.getBoundingClientRect();
    return rect.width >= 240 && rect.height >= 160;
  }

  function directPageFrameNodeFor(node) {
    let page = node?.closest?.(DIRECT_FIXED_FRAME_SELECTOR);
    const doc = node?.ownerDocument;
    while (page && doc && page !== doc.body && page !== doc.documentElement) {
      if (page !== node && isDirectPageFrameCandidate(page)) return page;
      page = page.parentElement?.closest?.(DIRECT_FIXED_FRAME_SELECTOR);
    }
    return null;
  }

  function arrangeDirectSelected(mode) {
    const nodes = directSelectionNodes();
    if (!nodes.length) return false;
    pushHistory();
    for (const node of nodes) {
      const style = node.ownerDocument.defaultView.getComputedStyle(node);
      const current = parseInt(style.zIndex, 10);
      const z = Number.isFinite(current) ? current : 1;
      node.style.zIndex = String(mode === "back" ? 0 : mode === "backward" ? Math.max(0, z - 1) : z + 1);
      if (mode === "front") node.style.zIndex = "9999";
    }
    postSelectionChanged();
    return true;
  }

  function setDirectLayoutMode(mode) {
    if (editorMode !== "html") return;
    directLayoutMode = mode === "transform" ? "transform" : "free";
    postSelectionChanged();
  }

  function loadDeck(nextDeck) {
    editorMode = "deck";
    resetZoom();
    if (directFrame) {
      directFrame.remove();
      directFrame = null;
    }
    directSelectedNode = null;
    directSelectedNodes = [];
    deck = nextDeck;
    currentSlideIndex = 0;
    selectedId = null;
    clearDeckGroupSelection();
    historyPast = [];
    historyFuture = [];
    clearDirty();
    render();
    postSelectionChanged();
  }

  function selectSlide(index) {
    if (editorMode === "html") return;
    const nextIndex = Math.min(Math.max(Number(index) || 0, 0), deck.slides.length - 1);
    if (currentSlideIndex === nextIndex) return;
    currentSlideIndex = nextIndex;
    selectedId = null;
    clearDeckGroupSelection();
    render();
    postSelectionChanged();
  }

  function loadDeckFromBase64(base64) {
    const json = decodeBase64(base64);
    loadDeck(JSON.parse(json));
  }

  function newDeck() {
    loadDeck(sampleDeck());
  }

  async function importHTMLFromBase64(base64, baseHref = "") {
    const html = decodeBase64(base64);
    return await importHTML(html, baseHref);
  }

  async function importHTML(html, baseHref = "") {
    const iframe = document.createElement("iframe");
    iframe.style.position = "fixed";
    iframe.style.left = "-10000px";
    iframe.style.top = "0";
    iframe.style.width = "1600px";
    iframe.style.height = "2200px";
    iframe.style.border = "0";
    iframe.style.visibility = "hidden";
    iframe.setAttribute("aria-hidden", "true");
    document.body.appendChild(iframe);

    await writeImportFrameHTML(iframe, withBaseElement(html, baseHref));
    await waitForImportStability(iframe);

    const doc = iframe.contentDocument;
    stabilizeImportDocument(doc);
    const fallbackPages = capturePageNodes(doc);
    const firstRect = roundedRect(fallbackPages[0].getBoundingClientRect(), fallbackPages[0].getBoundingClientRect());
    const firstStyle = doc.defaultView.getComputedStyle(fallbackPages[0]);

    const importedDeck = {
      version: 1,
      irVersion: "layout-ir-v1",
      sourceKind: "runtime-html-snapshot",
      canvas: {
        width: Math.max(320, firstRect.w),
        height: Math.max(180, firstRect.h),
        background: cssBackground(firstStyle)
      },
      slides: fallbackPages.map((page, index) => extractHTMLPage(doc, page, index))
    };

    iframe.remove();
    loadDeck(importedDeck);
    return importedDeck;
  }

  function writeImportFrameHTML(frame, html) {
    return new Promise((resolve) => {
      let settled = false;
      let objectURL = "";
      const finish = () => {
        if (settled) return;
        settled = true;
        if (objectURL) setTimeout(() => URL.revokeObjectURL(objectURL), 1600);
        setTimeout(resolve, 180);
      };

      frame.addEventListener("load", finish, { once: true });
      setTimeout(finish, 900);

      try {
        objectURL = URL.createObjectURL(new Blob([html], { type: "text/html;charset=utf-8" }));
        frame.src = objectURL;
      } catch {
        try {
          const doc = frame.contentDocument;
          doc.open();
          doc.write(html);
          doc.close();
        } catch {
          frame.srcdoc = html;
        }
      }
    });
  }

  async function waitForImportStability(frame) {
    const doc = frame?.contentDocument;
    if (!doc) return;
    const win = doc.defaultView;
    const start = performance.now();
    let lastSignature = "";
    let stableSamples = 0;

    await waitForImportAssets(doc, 900);

    while (performance.now() - start < 1800) {
      await importAnimationFrame(win);
      const signature = importStabilitySignature(doc);
      if (signature === lastSignature) {
        stableSamples += 1;
        if (stableSamples >= 3) break;
      } else {
        stableSamples = 0;
        lastSignature = signature;
      }
    }
  }

  function importAnimationFrame(win) {
    return new Promise((resolve) => {
      let settled = false;
      const finish = () => {
        if (settled) return;
        settled = true;
        resolve();
      };
      try {
        win?.requestAnimationFrame?.(finish);
      } catch {}
      setTimeout(finish, 48);
    });
  }

  function importStabilitySignature(doc) {
    const bodyRect = doc.body?.getBoundingClientRect?.() || { width: 0, height: 0 };
    const visibleNodes = [...doc.body.querySelectorAll("*")]
      .filter((node) => {
        const rect = node.getBoundingClientRect();
        return rect.width > 2 && rect.height > 2;
      })
      .slice(0, 220)
      .map((node) => {
        const rect = node.getBoundingClientRect();
        return `${node.tagName}:${Math.round(rect.left)},${Math.round(rect.top)},${Math.round(rect.width)},${Math.round(rect.height)}:${normalizedText(node).slice(0, 18)}`;
      });
    return `${Math.round(bodyRect.width)}x${Math.round(bodyRect.height)}:${visibleNodes.length}:${visibleNodes.join("|")}`;
  }

  function waitForImportAssets(doc, timeout = 900) {
    const pendingImages = [...doc.images || []].filter((image) => !image.complete);
    const fontReady = doc.fonts?.ready?.catch?.(() => null) || Promise.resolve();
    const imageReady = Promise.allSettled(pendingImages.map((image) => new Promise((resolve) => {
      image.addEventListener("load", resolve, { once: true });
      image.addEventListener("error", resolve, { once: true });
    })));
    return Promise.race([
      Promise.allSettled([fontReady, imageReady]),
      new Promise((resolve) => setTimeout(resolve, timeout))
    ]);
  }

  function stabilizeImportDocument(doc) {
    if (!doc?.head) return;
    let style = doc.getElementById("__chiselo_import_stability");
    if (!style) {
      style = doc.createElement("style");
      style.id = "__chiselo_import_stability";
      doc.head.appendChild(style);
    }
    style.textContent = `
      html { scroll-behavior: auto !important; }
      *, *::before, *::after {
        animation-play-state: paused !important;
        transition-property: none !important;
        transition-duration: 0s !important;
        transition-delay: 0s !important;
      }
    `;
    for (const video of doc.querySelectorAll("video")) {
      try { video.pause(); } catch {}
    }
    doc.defaultView?.scrollTo(0, 0);
  }

  function extractHTMLPage(doc, page, pageIndex) {
    const pageRect = page.getBoundingClientRect();
    const elements = [];
    let z = 1;

    for (const node of visualNodes(page)) {
      const element = rectElementFromNode(doc, node, pageRect, pageIndex + 1, z);
      if (element) {
        elements.push(element);
        z += 1;
      }
    }

    let imageZ = z + 50;
    for (const node of imageNodes(page)) {
      const element = imageElementFromNode(doc, node, pageRect, pageIndex + 1, imageZ);
      if (element) {
        elements.push(element);
        imageZ += 1;
      }
    }

    const textStartZ = imageZ + 100;
    let textZ = textStartZ;
    for (const node of textNodes(page)) {
      const element = textElementFromNode(doc, node, pageRect, pageIndex + 1, textZ);
      if (element) {
        elements.push(element);
        textZ += 1;
      }
    }

    let pseudoZ = textZ + 100;
    for (const node of pseudoNodes(page)) {
      for (const pseudo of ["::before", "::after"]) {
        const element = pseudoElementFromNode(doc, node, pseudo, pageRect, pageIndex + 1, pseudoZ);
        if (element) {
          elements.push(element);
          pseudoZ += 1;
        }
      }
    }

    let fallbackZ = pseudoZ + 100;
    for (const node of fallbackNodes(page)) {
      const element = fallbackElementFromNode(doc, node, pageRect, pageIndex + 1, fallbackZ);
      if (element) {
        elements.push(element);
        fallbackZ += 1;
      }
    }

    return {
      id: `page-${pageIndex + 1}`,
      title: `${doc.title || "Imported HTML"} ${pageIndex + 1}`,
      elements: optimizeCapturedElements(elements)
    };
  }

  function capturePageNodes(doc) {
    if (!doc?.body) return [];
    const candidates = uniqueElements([...doc.querySelectorAll(CAPTURE_PAGE_SELECTOR)])
      .filter((node) => node !== doc.body && node !== doc.documentElement && isCapturePageCandidate(node));
    const candidateSet = new Set(candidates);
    const topLevelPages = candidates.filter((node) => {
      let parent = node.parentElement;
      while (parent && parent !== doc.body && parent !== doc.documentElement) {
        if (candidateSet.has(parent)) return false;
        parent = parent.parentElement;
      }
      return true;
    });
    if (topLevelPages.length) return topLevelPages;

    const runtimeRoot = [...doc.querySelectorAll(DIRECT_RUNTIME_ROOT_SELECTOR)]
      .find((node) => isCapturePageCandidate(node) && node.children.length > 0);
    if (runtimeRoot) return [runtimeRoot];

    const sections = [...doc.body.querySelectorAll(":scope > main, :scope > article, :scope > section")]
      .filter(isCapturePageCandidate);
    if (sections.length >= 2) return sections;

    return [doc.body];
  }

  function isCapturePageCandidate(node) {
    if (!node?.getBoundingClientRect) return false;
    const style = node.ownerDocument.defaultView.getComputedStyle(node);
    if (!isVisibleStyle(style)) return false;
    const rect = node.getBoundingClientRect();
    return rect.width >= 240 && rect.height >= 160;
  }

  function visualNodes(page) {
    return [...page.querySelectorAll("*")]
      .filter((node) => {
        if (node.matches?.("img")) return false;
        if (node.matches?.("iframe,canvas,video,object,embed")) return false;
        if (node.closest("svg")) return false;
        const rect = node.getBoundingClientRect();
        if (rect.width < 8 || rect.height < 8) return false;

        const style = node.ownerDocument.defaultView.getComputedStyle(node);
        if (!isVisibleStyle(style)) return false;

        const hasBackground = style.backgroundImage !== "none" || !isTransparent(style.backgroundColor);
        const hasBorder = ["Top", "Right", "Bottom", "Left"].some((side) => parseFloat(style[`border${side}Width`]) > 0 && !isTransparent(style[`border${side}Color`]));
        const isTinyDecoration = rect.width < 18 && rect.height < 18;

        return !isTinyDecoration && (hasBackground || hasBorder);
      })
      .filter((node) => {
        const style = node.ownerDocument.defaultView.getComputedStyle(node);
        if (style.position === "absolute") return true;
        const parent = node.parentElement;
        if (!parent) return true;
        const parentStyle = node.ownerDocument.defaultView.getComputedStyle(parent);
        const sameBackground = cssBackground(style) === cssBackground(parentStyle);
        const noBorder = ["Top", "Right", "Bottom", "Left"].every((side) => parseFloat(style[`border${side}Width`]) === 0);
        return !(sameBackground && noBorder && node.children.length > 3);
      });
  }

  function textNodes(page) {
    const selectors = [
      "h1,h2,h3,h4,h5,h6,p,li,blockquote,figcaption,caption,dt,dd,button,a,label,td,th,pre,code",
      ".eyebrow,.band-subtitle,.role-emphasis,.section-title,.stat strong,.stat span,.location-text,.email",
      "[class*='title'],[class*='heading'],[class*='subtitle'],[class*='caption'],[class*='label'],[class*='metric'],[class*='value']"
    ];
    const seen = new Set();
    const nodes = [];

    for (const selector of selectors) {
      for (const node of page.querySelectorAll(selector)) {
        if (seen.has(node) || node.closest("svg,script,style,noscript")) continue;
        seen.add(node);
        nodes.push(node);
      }
    }

    for (const node of page.querySelectorAll("span,div")) {
      if (seen.has(node) || node.closest("svg,script,style,noscript")) continue;
      if (!hasMeaningfulDirectText(node)) continue;
      const text = normalizedText(node);
      if (!text || text.length > 220) continue;
      seen.add(node);
      nodes.push(node);
    }

    return nodes.filter((node) => {
      const rect = node.getBoundingClientRect();
      if (rect.width < 5 || rect.height < 5) return false;
      const style = node.ownerDocument.defaultView.getComputedStyle(node);
      if (!isVisibleStyle(style)) return false;
      return normalizedText(node).length > 0;
    });
  }

  function imageNodes(page) {
    return [...page.querySelectorAll("img")]
      .filter((node) => {
        const rect = node.getBoundingClientRect();
        if (rect.width < 8 || rect.height < 8) return false;
        const style = node.ownerDocument.defaultView.getComputedStyle(node);
        return isVisibleStyle(style);
      });
  }

  function pseudoNodes(page) {
    return [...page.querySelectorAll("*")]
      .filter((node) => !node.closest("svg"))
      .filter((node) => {
        const rect = node.getBoundingClientRect();
        if (rect.width < 1 || rect.height < 1) return false;
        const style = node.ownerDocument.defaultView.getComputedStyle(node);
        return isVisibleStyle(style);
      });
  }

  function fallbackNodes(page) {
    return [...page.querySelectorAll("iframe,canvas,video,object,embed")]
      .filter((node) => {
        const rect = node.getBoundingClientRect();
        if (rect.width < 8 || rect.height < 8) return false;
        const style = node.ownerDocument.defaultView.getComputedStyle(node);
        return style.display !== "none" && style.visibility !== "hidden";
      });
  }

  function rectElementFromNode(doc, node, pageRect, pageNumber, z) {
    const style = doc.defaultView.getComputedStyle(node);
    const rect = roundedRect(node.getBoundingClientRect(), pageRect);
    if (rect.w < 8 || rect.h < 8) return null;

    return {
      id: uniqueElementId(`p${pageNumber}-${nodeNameSlug(node)}-box`, z),
      type: "rect",
      tagName: node.tagName.toLowerCase(),
      htmlPath: directNodePath(node),
      semanticRole: capturedSemanticForNode(node).role,
      semanticLabel: capturedSemanticForNode(node).label,
      ...capturedGroupForNode(node),
      sourceKind: "computed-style",
      editability: "style-editable",
      fidelity: "native",
      captureNote: "由浏览器计算后的背景、边框或形状转换",
      x: rect.x,
      y: rect.y,
      w: rect.w,
      h: rect.h,
      rotation: rotationFromTransform(style.transform),
      z,
      style: {
        fill: cssBackground(style),
        stroke: firstBorderColor(style),
        strokeWidth: firstBorderWidth(style),
        radius: parseFloat(style.borderTopLeftRadius) || 0,
        ...(shadowValue(style.boxShadow) !== "none" ? { shadow: shadowValue(style.boxShadow) } : {})
      }
    };
  }

  function imageElementFromNode(doc, node, pageRect, pageNumber, z) {
    const style = doc.defaultView.getComputedStyle(node);
    const rect = roundedRect(node.getBoundingClientRect(), pageRect);
    if (rect.w < 8 || rect.h < 8) return null;

    return {
      id: uniqueElementId(`p${pageNumber}-${nodeNameSlug(node)}-image`, z),
      type: "image",
      tagName: "img",
      htmlPath: directNodePath(node),
      semanticRole: "image",
      semanticLabel: "图片",
      ...capturedGroupForNode(node),
      sourceKind: "image",
      editability: "replaceable",
      fidelity: "native",
      captureNote: "保留为可替换图片对象",
      imageSource: node.currentSrc || node.src || node.getAttribute("src") || "",
      imageAlt: node.getAttribute("alt") || "",
      x: rect.x,
      y: rect.y,
      w: rect.w,
      h: rect.h,
      rotation: rotationFromTransform(style.transform),
      z,
      style: {
        stroke: firstBorderColor(style),
        strokeWidth: firstBorderWidth(style),
        radius: parseFloat(style.borderTopLeftRadius) || 0,
        objectFit: objectFitValue(style.objectFit, "fill"),
        ...(shadowValue(style.boxShadow) !== "none" ? { shadow: shadowValue(style.boxShadow) } : {})
      }
    };
  }

  function textElementFromNode(doc, node, pageRect, pageNumber, z) {
    const style = doc.defaultView.getComputedStyle(node);
    const rect = roundedRect(node.getBoundingClientRect(), pageRect);
    const text = normalizedText(node);
    if (!text || rect.w < 5 || rect.h < 5) return null;

    const fontSize = parseFloat(style.fontSize) || 16;
    const lineHeight = style.lineHeight === "normal" ? 1.2 : Math.max(0.8, (parseFloat(style.lineHeight) || fontSize * 1.2) / fontSize);

    return {
      id: uniqueElementId(`p${pageNumber}-${nodeNameSlug(node)}-text`, z),
      type: "text",
      tagName: node.tagName.toLowerCase(),
      htmlPath: directNodePath(node),
      semanticRole: capturedSemanticForNode(node).role,
      semanticLabel: capturedSemanticForNode(node).label,
      ...capturedGroupForNode(node),
      sourceKind: "text",
      editability: "text-editable",
      fidelity: "native",
      captureNote: "保留为可直接修改的文本对象",
      x: rect.x,
      y: rect.y,
      w: rect.w,
      h: Math.max(rect.h, Math.ceil(fontSize * lineHeight)),
      rotation: rotationFromTransform(style.transform),
      z,
      text,
      style: {
        fontFamily: style.fontFamily || "-apple-system, BlinkMacSystemFont, sans-serif",
        fontSize,
        fontWeight: fontWeightNumber(style.fontWeight),
        lineHeight,
        color: style.color || "#111827",
        textAlign: textAlignValue(style.textAlign)
      }
    };
  }

  function pseudoElementFromNode(doc, node, pseudo, pageRect, pageNumber, z) {
    const style = doc.defaultView.getComputedStyle(node, pseudo);
    if (!style || !isVisibleStyle(style)) return null;
    const text = cssPseudoContentText(style.content, node);
    const hasBox = style.backgroundImage !== "none"
      || !isTransparent(style.backgroundColor)
      || firstBorderWidth(style) > 0;
    if (!text && !hasBox) return null;

    const parentRect = node.getBoundingClientRect();
    const fontSize = parseFloat(style.fontSize) || 16;
    const lineHeightPX = style.lineHeight === "normal" ? fontSize * 1.2 : parseFloat(style.lineHeight) || fontSize * 1.2;
    const paddingX = (parseFloat(style.paddingLeft) || 0) + (parseFloat(style.paddingRight) || 0);
    const paddingY = (parseFloat(style.paddingTop) || 0) + (parseFloat(style.paddingBottom) || 0);
    const width = style.width === "auto"
      ? Math.max(8, Math.min(parentRect.width, text ? text.length * fontSize * 0.62 + paddingX : parentRect.width))
      : Math.max(1, parseFloat(style.width) || parentRect.width);
    const height = style.height === "auto"
      ? Math.max(8, text ? lineHeightPX + paddingY : Math.min(parentRect.height, lineHeightPX + paddingY))
      : Math.max(1, parseFloat(style.height) || parentRect.height);

    let left = parentRect.left;
    let top = parentRect.top;
    if (style.position === "absolute" || style.position === "fixed") {
      if (style.left !== "auto") left = parentRect.left + (parseFloat(style.left) || 0);
      else if (style.right !== "auto") left = parentRect.right - (parseFloat(style.right) || 0) - width;
      else if (pseudo === "::after") left = parentRect.right - width;

      if (style.top !== "auto") top = parentRect.top + (parseFloat(style.top) || 0);
      else if (style.bottom !== "auto") top = parentRect.bottom - (parseFloat(style.bottom) || 0) - height;
    } else if (pseudo === "::after") {
      left = Math.max(parentRect.left, parentRect.right - width);
    }

    const rect = {
      x: Math.round(left - pageRect.left),
      y: Math.round(top - pageRect.top),
      w: Math.round(width),
      h: Math.round(height)
    };
    if (rect.w < 1 || rect.h < 1) return null;

    if (text) {
      const lineHeight = Math.max(0.8, lineHeightPX / fontSize);
      return {
        id: uniqueElementId(`p${pageNumber}-${nodeNameSlug(node)}-${pseudo.slice(2)}-text`, z),
        type: "text",
        tagName: pseudo,
        htmlPath: `${directNodePath(node)} ${pseudo}`,
        semanticRole: "text",
        semanticLabel: "伪元素文本",
        ...capturedGroupForNode(node),
        sourceKind: "pseudo-element",
        editability: "text-editable",
        fidelity: "approximated",
        captureNote: "由 CSS 伪元素内容提取为真实文本对象",
        x: rect.x,
        y: rect.y,
        w: rect.w,
        h: Math.max(rect.h, Math.ceil(fontSize * lineHeight)),
        rotation: rotationFromTransform(style.transform),
        z,
        text,
        style: {
          fontFamily: style.fontFamily || "-apple-system, BlinkMacSystemFont, sans-serif",
          fontSize,
          fontWeight: fontWeightNumber(style.fontWeight),
          lineHeight,
          color: style.color || "#111827",
          textAlign: textAlignValue(style.textAlign)
        }
      };
    }

    return {
      id: uniqueElementId(`p${pageNumber}-${nodeNameSlug(node)}-${pseudo.slice(2)}-box`, z),
      type: "rect",
      tagName: pseudo,
      htmlPath: `${directNodePath(node)} ${pseudo}`,
      semanticRole: "visual",
      semanticLabel: "伪元素图形",
      ...capturedGroupForNode(node),
      sourceKind: "pseudo-element",
      editability: "style-editable",
      fidelity: "approximated",
      captureNote: "由 CSS 伪元素视觉效果近似为形状对象",
      x: rect.x,
      y: rect.y,
      w: rect.w,
      h: rect.h,
      rotation: rotationFromTransform(style.transform),
      z,
      style: {
        fill: cssBackground(style),
        stroke: firstBorderColor(style),
        strokeWidth: firstBorderWidth(style),
        radius: parseFloat(style.borderTopLeftRadius) || 0,
        ...(shadowValue(style.boxShadow) !== "none" ? { shadow: shadowValue(style.boxShadow) } : {})
      }
    };
  }

  function fallbackElementFromNode(doc, node, pageRect, pageNumber, z) {
    const style = doc.defaultView.getComputedStyle(node);
    const rect = roundedRect(node.getBoundingClientRect(), pageRect);
    if (rect.w < 8 || rect.h < 8) return null;

    const tag = node.tagName.toLowerCase();
    const imageSource = fallbackImageSource(node);
    const base = {
      id: uniqueElementId(`p${pageNumber}-${nodeNameSlug(node)}-fallback`, z),
      type: imageSource ? "image" : "rect",
      tagName: tag,
      htmlPath: directNodePath(node),
      semanticRole: tag === "iframe" ? "embedded-page" : tag === "canvas" ? "canvas" : "media",
      semanticLabel: tag === "iframe" ? "嵌入页面" : tag === "canvas" ? "画布整体" : "媒体整体",
      ...capturedGroupForNode(node),
      sourceKind: tag,
      editability: "whole-object",
      fidelity: imageSource ? "snapshot" : "fallback",
      captureNote: fallbackCaptureNote(node, imageSource),
      x: rect.x,
      y: rect.y,
      w: rect.w,
      h: rect.h,
      rotation: rotationFromTransform(style.transform),
      z,
      style: {
        fill: imageSource ? "transparent" : fallbackFillForNode(tag),
        stroke: firstBorderColor(style),
        strokeWidth: firstBorderWidth(style),
        radius: parseFloat(style.borderTopLeftRadius) || 0,
        ...(imageSource ? { objectFit: objectFitValue(style.objectFit, "fill") } : {}),
        ...(shadowValue(style.boxShadow) !== "none" ? { shadow: shadowValue(style.boxShadow) } : {})
      }
    };

    if (imageSource) {
      base.imageSource = imageSource;
      base.imageAlt = fallbackAltForNode(node);
    }

    return base;
  }

  function fallbackImageSource(node) {
    if (node.matches?.("canvas")) {
      try {
        return node.toDataURL("image/png");
      } catch {
        return "";
      }
    }
    if (node.matches?.("video") && node.poster) return node.poster;
    return "";
  }

  function fallbackCaptureNote(node, imageSource) {
    const tag = node.tagName.toLowerCase();
    if (tag === "canvas") {
      return imageSource ? "Canvas 已捕获为当前像素图，不能拆成文本或图形对象" : "Canvas 无法读取像素，保留为整体占位对象";
    }
    if (tag === "iframe") return "嵌入页面受安全边界限制，保留为整体对象";
    if (tag === "video") return imageSource ? "视频以封面图保留为整体对象" : "视频保留为整体占位对象";
    return "复杂嵌入内容保留为整体对象";
  }

  function fallbackAltForNode(node) {
    const tag = node.tagName.toLowerCase();
    if (tag === "canvas") return "Canvas snapshot";
    if (tag === "video") return node.getAttribute("aria-label") || node.getAttribute("title") || "Video poster";
    return node.getAttribute("aria-label") || node.getAttribute("title") || tag;
  }

  function fallbackFillForNode(tag) {
    if (tag === "iframe") return "rgba(245, 158, 11, 0.18)";
    if (tag === "canvas") return "rgba(15, 23, 42, 0.10)";
    return "rgba(59, 130, 246, 0.12)";
  }

  function capturedSemanticForNode(node) {
    const semantic = directSemanticForNode(node);
    if (semantic.role !== "container" || node.tagName.toLowerCase() === "div") return semantic;
    return semantic;
  }

  function capturedGroupForNode(node) {
    const groupNode = capturedGroupNodeFor(node);
    if (!groupNode) return {};

    const semantic = directSemanticForNode(groupNode);
    return {
      groupId: stableGroupId(groupNode),
      groupRole: semantic.role === "container" ? "module" : semantic.role,
      groupLabel: semantic.label === "容器" ? "模块" : semantic.label
    };
  }

  function capturedGroupNodeFor(node) {
    if (!node?.parentElement) return null;
    let current = node;
    const doc = node.ownerDocument;

    while (current && current !== doc.body && current !== doc.documentElement) {
      if (isCapturedGroupCandidate(current) && (current !== node || canUseNodeAsOwnGroup(current))) return current;
      current = current.parentElement;
    }

    return null;
  }

  function canUseNodeAsOwnGroup(node) {
    if (!node) return false;
    if (node.children.length > 0) return true;
    const tag = node.tagName.toLowerCase();
    return ["section", "article", "figure", "table", "header", "footer", "aside", "nav"].includes(tag);
  }

  function isCapturedGroupCandidate(node) {
    if (!node || node.matches?.("html,body,script,style,noscript,svg")) return false;
    if (node.matches?.(CAPTURE_PAGE_SELECTOR)) return false;

    const rect = node.getBoundingClientRect();
    if (rect.width < 48 || rect.height < 36) return false;

    const semantic = directSemanticForNode(node);
    if (["card", "module", "figure", "table", "table-like", "header", "sidebar", "navigation"].includes(semantic.role)) return true;

    const tag = node.tagName.toLowerCase();
    if (["section", "article", "figure", "table", "header", "footer", "aside", "nav"].includes(tag)) return true;

    const name = `${node.id || ""} ${[...node.classList || []].join(" ")}`.toLowerCase();
    return /(card|panel|module|section|block|tile|item|feature|hero|banner|stat|metric|table|chart|figure|visual)/.test(name);
  }

  function stableGroupId(node) {
    return `group-${hashString(directNodePath(node))}`;
  }

  function hashString(value) {
    let hash = 5381;
    const text = String(value || "");
    for (let index = 0; index < text.length; index += 1) {
      hash = ((hash << 5) + hash) ^ text.charCodeAt(index);
    }
    return (hash >>> 0).toString(36);
  }

  function optimizeCapturedElements(elements) {
    const sorted = [...elements].sort((a, b) => {
      if (a.z === b.z) return elementArea(b) - elementArea(a);
      return a.z - b.z;
    });
    const output = [];

    for (const element of sorted) {
      if (shouldDropCapturedElement(element, output)) continue;
      output.push(element);
    }

    return output.sort((a, b) => a.z - b.z).map((element, index) => ({
      ...element,
      z: index + 1
    }));
  }

  function shouldDropCapturedElement(element, accepted) {
    if (element.type !== "rect") return false;
    if (element.sourceKind === "pseudo-element") return false;
    const fill = String(element.style?.fill || "").toLowerCase();
    const strokeWidth = Number(element.style?.strokeWidth || 0);
    const shadow = shadowValue(element.style?.shadow);
    if (shadow !== "none") return false;
    if ((fill === "transparent" || isTransparentColor(fill)) && strokeWidth <= 0) return true;

    return accepted.some((other) => {
      if (other.type !== "rect") return false;
      if (other.sourceKind === "pseudo-element") return false;
      if (Math.abs(element.x - other.x) > 2 || Math.abs(element.y - other.y) > 2) return false;
      if (Math.abs(element.w - other.w) > 2 || Math.abs(element.h - other.h) > 2) return false;
      return cssEquivalent(element.style?.fill, other.style?.fill) && cssEquivalent(element.style?.stroke, other.style?.stroke);
    });
  }

  function elementArea(element) {
    return Math.max(1, Number(element.w || 0) * Number(element.h || 0));
  }

  function cssEquivalent(left, right) {
    return String(left || "").trim().toLowerCase() === String(right || "").trim().toLowerCase();
  }

  function roundedRect(rect, parentRect) {
    return {
      x: Math.round(rect.left - parentRect.left),
      y: Math.round(rect.top - parentRect.top),
      w: Math.round(rect.width),
      h: Math.round(rect.height)
    };
  }

  function isVisibleStyle(style) {
    return style.display !== "none" && style.visibility !== "hidden" && Number(style.opacity || 1) > 0.01;
  }

  function cssBackground(style) {
    if (style.backgroundImage && style.backgroundImage !== "none") return style.backgroundImage;
    return isTransparent(style.backgroundColor) ? "transparent" : style.backgroundColor;
  }

  function isTransparent(color) {
    return isTransparentColor(color);
  }

  function isTransparentColor(color) {
    const value = String(color || "").trim().toLowerCase();
    if (!value || value === "transparent") return true;
    const rgba = value.match(/^rgba?\(([^)]+)\)$/);
    if (!rgba) return false;
    const parts = rgba[1].split(",").map((part) => part.trim());
    if (parts.length < 4) return false;
    return Number(parts[3]) <= 0.01;
  }

  function firstBorderWidth(style) {
    return parseFloat(style.borderTopWidth) || parseFloat(style.borderRightWidth) || parseFloat(style.borderBottomWidth) || parseFloat(style.borderLeftWidth) || 0;
  }

  function firstBorderColor(style) {
    return [style.borderTopColor, style.borderRightColor, style.borderBottomColor, style.borderLeftColor].find((color) => !isTransparent(color)) || "transparent";
  }

  function fontWeightNumber(value) {
    if (value === "bold") return 700;
    if (value === "normal") return 400;
    return parseFloat(value) || 400;
  }

  function textAlignValue(value) {
    if (value === "center" || value === "right") return value;
    return "left";
  }

  function shadowValue(value) {
    const normalized = String(value || "").trim();
    if (!normalized || normalized.toLowerCase() === "none") return "none";
    return normalized;
  }

  function objectFitValue(value, fallback = "cover") {
    const normalized = String(value || "").trim().toLowerCase();
    if (["contain", "cover", "fill", "none", "scale-down"].includes(normalized)) return normalized;
    return fallback;
  }

  function normalizedText(node) {
    if (node.matches("h1") && node.children.length) {
      return [...node.children].map((child) => child.textContent.trim()).filter(Boolean).join("\n");
    }
    return node.textContent.replace(/\s+/g, " ").trim();
  }

  function cssPseudoContentText(value, node) {
    if (!value || value === "none" || value === "normal") return "";
    const attr = String(value).match(/^attr\(([^)]+)\)$/i);
    if (attr) return (node.getAttribute(attr[1].trim()) || "").trim();
    const quoted = String(value).match(/^["']([\s\S]*)["']$/);
    if (!quoted) return "";
    return quoted[1]
      .replace(/\\A/gi, "\n")
      .replace(/\\([0-9a-f]{1,6})\s?/gi, (_, hex) => String.fromCodePoint(parseInt(hex, 16)))
      .replace(/\s+/g, " ")
      .trim();
  }

  function nodeNameSlug(node) {
    const className = [...node.classList || []].slice(0, 2).join("-");
    const raw = className || node.id || node.tagName.toLowerCase();
    return raw.replace(/[^a-z0-9_-]+/gi, "-").replace(/^-|-$/g, "").toLowerCase() || "element";
  }

  function uniqueElementId(base, index) {
    return `${base}-${index}`;
  }

  function rotationFromTransform(transform) {
    if (!transform || transform === "none") return 0;
    const match = transform.match(/^matrix\(([^)]+)\)$/);
    if (!match) return 0;
    const [a, b] = match[1].split(",").map((value) => parseFloat(value.trim()));
    return Math.round(Math.atan2(b, a) * (180 / Math.PI));
  }

  function withBaseElement(html, baseHref) {
    if (!baseHref) return html;
    const base = `<base data-chiselo-base href="${escapeHTML(baseHref)}">`;
    if (/<head[\s>]/i.test(html)) {
      return html.replace(/<head([^>]*)>/i, `<head$1>${base}`);
    }
    return `${base}${html}`;
  }

  function decodeBase64(base64) {
    const bytes = Uint8Array.from(atob(base64), (char) => char.charCodeAt(0));
    return new TextDecoder().decode(bytes);
  }

  function exportHTML() {
    if (editorMode === "html") return exportDirectHTML();

    const canvas = deck.canvas;
    const htmlSlides = deck.slides.map((slide, index) => {
      const elements = [...slide.elements].sort((a, b) => a.z - b.z);
      const htmlElements = elements.map(staticElementHTML).join("\n");
      return `  <section class="slide${index < deck.slides.length - 1 ? " page-break" : ""}" aria-label="${escapeHTML(slide.title || `Slide ${index + 1}`)}">
${htmlElements}
  </section>`;
    }).join("\n");

    return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHTML(deck.slides[0]?.title || "Chiselo Project")}</title>
  <style>
    * { box-sizing: border-box; }
    html, body { margin: 0; min-height: 100%; }
    body { display: grid; justify-items: center; gap: 24px; padding: 24px; background: #e5e7eb; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
    .slide { position: relative; width: ${canvas.width}px; height: ${canvas.height}px; overflow: hidden; background: ${canvas.background || "#ffffff"}; box-shadow: 0 20px 60px rgba(15,23,42,.16); }
    .element { position: absolute; overflow: hidden; transform-origin: center center; }
    .text-content { width: 100%; height: 100%; white-space: pre-wrap; overflow-wrap: break-word; }
    .shape-content { width: 100%; height: 100%; }
    .image-content { width: 100%; height: 100%; display: block; }
    @media print {
      body { display: block; padding: 0; background: white; }
      .slide { box-shadow: none; margin: 0; }
      .page-break { break-after: page; page-break-after: always; }
    }
  </style>
</head>
<body>
${htmlSlides}
</body>
</html>`;
  }

  function exportDirectHTML() {
    const doc = directFrame?.contentDocument;
    if (!doc) return "";

    const cloneRoot = doc.documentElement.cloneNode(true);
    for (const node of cloneRoot.querySelectorAll("[data-chiselo-style], base[data-chiselo-base]")) {
      node.remove();
    }
    for (const node of [cloneRoot, ...cloneRoot.querySelectorAll("*")]) {
      stripChiseloAttributes(node);
    }
    for (const node of cloneRoot.querySelectorAll("[contenteditable]")) {
      node.removeAttribute("contenteditable");
    }
    for (const node of cloneRoot.querySelectorAll("[spellcheck]")) {
      node.removeAttribute("spellcheck");
    }

    return `${directHadDoctype ? "<!doctype html>\n" : ""}${cloneRoot.outerHTML}`;
  }

  function stripChiseloAttributes(node) {
    for (const attribute of [...node.attributes]) {
      if (attribute.name.startsWith("data-chiselo")) {
        node.removeAttribute(attribute.name);
      }
    }
  }

  function getHTMLSummary() {
    const doc = directFrame?.contentDocument;
    if (!doc) return { mode: editorMode, elementCount: 0, exportedLength: 0 };
    const elements = [...doc.querySelectorAll("[data-chiselo-id]")];
    return {
      mode: editorMode,
      width: directCanvas().width,
      height: directCanvas().height,
      elementCount: elements.length,
      textElementCount: elements.filter((node) => normalizedText(node).length > 0).length,
      exportedLength: exportDirectHTML().length
    };
  }

  function getImportDiagnostics() {
    const doc = directFrame?.contentDocument;
    if (!doc) {
      return {
        mode: editorMode,
        imageCount: 0,
        brokenImages: 0,
        embeddedImages: 0,
        mediaCount: 0,
        brokenMedia: 0,
        svgCount: 0,
        tableCount: 0,
        spanTableCount: 0,
        scriptCount: 0,
        iframeCount: 0,
        canvasCount: 0,
        shadowRootCount: 0,
        runtimeRootCount: 0,
        externalResourceCount: 0,
        overlayBlockerCount: 0,
        runtimeRiskCount: 0,
        pptxEffectRiskCount: 0,
        visualChangeCount: 0,
        pptxTextObjectCount: 0,
        pptxImageObjectCount: 0,
        pptxShapeObjectCount: 0,
        pptxReviewObjectCount: 0,
        pptxFallbackObjectCount: 0,
        pptxTextElementId: null,
        pptxImageElementId: null,
        pptxShapeElementId: null,
        pptxReviewElementId: null,
        pptxFallbackElementId: null,
        pptxTextElementIds: [],
        pptxImageElementIds: [],
        pptxShapeElementIds: [],
        pptxReviewElementIds: [],
        pptxFallbackElementIds: [],
        cleanExport: true,
        textOverflowCount: 0,
        outOfBoundsCount: 0,
        overlapCount: 0,
        resourceElementId: null,
        tableElementId: null,
        svgElementId: null,
        textOverflowElementId: null,
        outOfBoundsElementId: null,
        overlapElementId: null,
        runtimeRiskElementId: null,
        pptxEffectRiskElementId: null,
        visualChangeElementId: null,
        issues: []
      };
    }

    const images = [...doc.querySelectorAll("img")];
    const media = [...doc.querySelectorAll("video, audio")];
    const tables = [...doc.querySelectorAll("table")];
    const svgNodes = [...doc.querySelectorAll("svg")];
    const svgImageNodes = images.filter((image) => (image.getAttribute("src") || "").startsWith("data:image/svg"));
    const svgCount = svgNodes.length + svgImageNodes.length;
    const exported = exportDirectHTML();
    const issues = [];
    const runtimeDiagnostics = collectRuntimeCompatibilityDiagnostics(doc, issues);
    const brokenImageNodes = images.filter((image) => image.dataset.chiseloResourceState === "broken");
    const brokenMediaNodes = media.filter((node) => node.dataset.chiseloResourceState === "broken");
    const spanTables = tables.filter((table) => table.querySelector("[rowspan], [colspan]"));
    const tableTargetElementId = optionalDirectId(spanTables[0] || tables[0] || null);
    const svgTargetElementId = optionalDirectId(svgNodes[0] || svgImageNodes[0] || null);
    const cleanExport = !exported.includes("data-chiselo");

    for (const image of brokenImageNodes) {
      addDiagnosticIssue(issues, {
        kind: "broken-image",
        severity: "error",
        title: "图片断链",
        detail: diagnosticResourceDetail(image, "图片资源无法加载"),
        elementId: ensureDirectId(image)
      });
    }

    for (const node of brokenMediaNodes) {
      addDiagnosticIssue(issues, {
        kind: "broken-media",
        severity: "error",
        title: "媒体断链",
        detail: diagnosticResourceDetail(node, "音视频资源无法加载"),
        elementId: ensureDirectId(node)
      });
    }

    if (spanTables.length > 0) {
      addDiagnosticIssue(issues, {
        kind: "span-table",
        severity: "warning",
        title: "合并单元格",
        detail: `${spanTables.length} 个表格含合并单元格，导出到 PPTX 后需要复核`,
        elementId: ensureDirectId(spanTables[0])
      });
    }

    if (!cleanExport) {
      addDiagnosticIssue(issues, {
        kind: "dirty-export",
        severity: "error",
        title: "导出不干净",
        detail: "HTML 中仍包含编辑器临时标记"
      });
    }

    const pptxEffectDiagnostics = collectPPTXEffectDiagnostics(doc, issues);
    const visualDiffDiagnostics = collectVisualDiffDiagnostics(doc, issues);
    const layoutDiagnostics = collectLayoutDiagnostics(doc, issues);
    const pptxMappingDiagnostics = collectPPTXMappingDiagnostics(doc, {
      tableCount: tables.length,
      svgCount,
      tableElementId: tableTargetElementId,
      svgElementId: svgTargetElementId,
      runtimeDiagnostics,
      pptxEffectDiagnostics,
      layoutDiagnostics
    });
    return {
      mode: editorMode,
      imageCount: images.length,
      brokenImages: brokenImageNodes.length,
      embeddedImages: images.filter((image) => (image.getAttribute("src") || "").startsWith("data:")).length,
      mediaCount: media.length,
      brokenMedia: brokenMediaNodes.length,
      svgCount,
      tableCount: tables.length,
      spanTableCount: spanTables.length,
      scriptCount: runtimeDiagnostics.scriptCount,
      iframeCount: runtimeDiagnostics.iframeCount,
      canvasCount: runtimeDiagnostics.canvasCount,
      shadowRootCount: runtimeDiagnostics.shadowRootCount,
      runtimeRootCount: runtimeDiagnostics.runtimeRootCount,
      externalResourceCount: runtimeDiagnostics.externalResourceCount,
      overlayBlockerCount: runtimeDiagnostics.overlayBlockerCount,
      runtimeRiskCount: runtimeDiagnostics.runtimeRiskCount,
      pptxEffectRiskCount: pptxEffectDiagnostics.pptxEffectRiskCount,
      visualChangeCount: visualDiffDiagnostics.visualChangeCount,
      pptxTextObjectCount: pptxMappingDiagnostics.pptxTextObjectCount,
      pptxImageObjectCount: pptxMappingDiagnostics.pptxImageObjectCount,
      pptxShapeObjectCount: pptxMappingDiagnostics.pptxShapeObjectCount,
      pptxReviewObjectCount: pptxMappingDiagnostics.pptxReviewObjectCount,
      pptxFallbackObjectCount: pptxMappingDiagnostics.pptxFallbackObjectCount,
      pptxTextElementId: pptxMappingDiagnostics.pptxTextElementId,
      pptxImageElementId: pptxMappingDiagnostics.pptxImageElementId,
      pptxShapeElementId: pptxMappingDiagnostics.pptxShapeElementId,
      pptxReviewElementId: pptxMappingDiagnostics.pptxReviewElementId,
      pptxFallbackElementId: pptxMappingDiagnostics.pptxFallbackElementId,
      pptxTextElementIds: pptxMappingDiagnostics.pptxTextElementIds,
      pptxImageElementIds: pptxMappingDiagnostics.pptxImageElementIds,
      pptxShapeElementIds: pptxMappingDiagnostics.pptxShapeElementIds,
      pptxReviewElementIds: pptxMappingDiagnostics.pptxReviewElementIds,
      pptxFallbackElementIds: pptxMappingDiagnostics.pptxFallbackElementIds,
      cleanExport,
      textOverflowCount: layoutDiagnostics.textOverflowCount,
      outOfBoundsCount: layoutDiagnostics.outOfBoundsCount,
      overlapCount: layoutDiagnostics.overlapCount,
      resourceElementId: optionalDirectId(brokenImageNodes[0] || brokenMediaNodes[0] || images[0] || media[0] || null),
      tableElementId: tableTargetElementId,
      svgElementId: svgTargetElementId,
      textOverflowElementId: layoutDiagnostics.textOverflowElementId,
      outOfBoundsElementId: layoutDiagnostics.outOfBoundsElementId,
      overlapElementId: layoutDiagnostics.overlapElementId,
      runtimeRiskElementId: runtimeDiagnostics.runtimeRiskElementId,
      pptxEffectRiskElementId: pptxEffectDiagnostics.pptxEffectRiskElementId,
      visualChangeElementId: visualDiffDiagnostics.visualChangeElementId,
      issues
    };
  }

  function collectRuntimeCompatibilityDiagnostics(doc, issues) {
    const scripts = [...doc.querySelectorAll("script")].filter((node) => !node.hasAttribute("data-chiselo-style"));
    const iframes = [...doc.querySelectorAll("iframe")];
    const canvases = [...doc.querySelectorAll("canvas")];
    const runtimeRoots = [...doc.querySelectorAll(DIRECT_RUNTIME_ROOT_SELECTOR)].filter((node) => node !== doc.body && node !== doc.documentElement);
    const shadowHosts = collectShadowRootHosts(doc);
    const externalResources = collectExternalRuntimeResources(doc);
    const overlayBlockers = collectSelectionBlockingOverlays(doc);
    const staticBodyNodes = visibleBodyObjectCount(doc);
    const scriptHeavyRuntime = scripts.length > 0 && (runtimeRoots.length > 0 || staticBodyNodes <= Math.max(4, scripts.length));
    let runtimeRiskCount = 0;
    let runtimeRiskElementId = null;

    if (scriptHeavyRuntime) {
      runtimeRiskCount += 1;
      const element = runtimeRoots[0] || doc.body;
      runtimeRiskElementId = runtimeRiskElementId || optionalDirectId(element);
      addDiagnosticIssue(issues, {
        kind: "runtime-rendered",
        severity: "warning",
        title: "脚本渲染页面",
        detail: "内容可能由脚本实时渲染，部分模块会在导入后替换或重绘",
        elementId: optionalDirectId(element)
      });
    }

    if (iframes.length > 0) {
      runtimeRiskCount += iframes.length;
      runtimeRiskElementId = runtimeRiskElementId || optionalDirectId(iframes[0]);
      addDiagnosticIssue(issues, {
        kind: "iframe-content",
        severity: "warning",
        title: "嵌入页面",
        detail: `${iframes.length} 个嵌入页面无法像普通模块一样直接精修`,
        elementId: optionalDirectId(iframes[0])
      });
    }

    if (canvases.length > 0) {
      runtimeRiskCount += canvases.length;
      runtimeRiskElementId = runtimeRiskElementId || optionalDirectId(canvases[0]);
      addDiagnosticIssue(issues, {
        kind: "canvas-content",
        severity: "warning",
        title: "画布内容",
        detail: `${canvases.length} 个画布区域通常只能按整体对象处理`,
        elementId: optionalDirectId(canvases[0])
      });
    }

    if (shadowHosts.length > 0) {
      runtimeRiskCount += shadowHosts.length;
      runtimeRiskElementId = runtimeRiskElementId || optionalDirectId(shadowHosts[0]);
      addDiagnosticIssue(issues, {
        kind: "shadow-content",
        severity: "warning",
        title: "封装组件",
        detail: `${shadowHosts.length} 个封装组件可能无法完整展开为可编辑对象`,
        elementId: optionalDirectId(shadowHosts[0])
      });
    }

    if (overlayBlockers.length > 0) {
      runtimeRiskCount += overlayBlockers.length;
      runtimeRiskElementId = runtimeRiskElementId || optionalDirectId(overlayBlockers[0]);
      addDiagnosticIssue(issues, {
        kind: "selection-overlay",
        severity: "warning",
        title: "遮罩挡住选择",
        detail: `${overlayBlockers.length} 个透明遮罩已在编辑中临时穿透，导出前建议复核`,
        elementId: optionalDirectId(overlayBlockers[0])
      });
    }

    if (externalResources.length > 0) {
      runtimeRiskCount += externalResources.length;
      runtimeRiskElementId = runtimeRiskElementId || optionalDirectId(externalResources[0]);
      addDiagnosticIssue(issues, {
        kind: "external-runtime-resource",
        severity: "warning",
        title: "外部运行资源",
        detail: `${externalResources.length} 个外部脚本/样式/框架资源可能影响离线编辑和导出`,
        elementId: optionalDirectId(externalResources[0])
      });
    }

    return {
      scriptCount: scripts.length,
      iframeCount: iframes.length,
      canvasCount: canvases.length,
      shadowRootCount: shadowHosts.length,
      runtimeRootCount: runtimeRoots.length,
      externalResourceCount: externalResources.length,
      overlayBlockerCount: overlayBlockers.length,
      runtimeRiskCount,
      runtimeRiskElementId
    };
  }

  function collectShadowRootHosts(doc) {
    const hosts = [];
    for (const node of doc.querySelectorAll("*")) {
      if (node.shadowRoot) hosts.push(node);
    }
    return hosts;
  }

  function collectExternalRuntimeResources(doc) {
    const resources = [
      ...doc.querySelectorAll("script[src]"),
      ...doc.querySelectorAll("link[rel~='stylesheet'][href]"),
      ...doc.querySelectorAll("iframe[src]")
    ];
    return resources.filter((node) => {
      const value = node.getAttribute("src") || node.getAttribute("href") || "";
      if (!value || value.startsWith("data:") || value.startsWith("blob:")) return false;
      try {
        const url = new URL(value, directBaseHref || doc.baseURI);
        return url.protocol === "http:" || url.protocol === "https:";
      } catch {
        return false;
      }
    });
  }

  function collectSelectionBlockingOverlays(doc) {
    return [...doc.querySelectorAll("[data-chiselo-selection-pass-through='true']")]
      .filter((node) => node.isConnected);
  }

  function visibleBodyObjectCount(doc) {
    return [...doc.body.querySelectorAll("body *")]
      .slice(0, 80)
      .filter((node) => {
        if (node.matches?.("script,style,meta,link,title")) return false;
        if (!isDirectNodeVisible(node)) return false;
        const rect = node.getBoundingClientRect();
        return rect.width >= 4 && rect.height >= 4;
      }).length;
  }

  function collectVisualDiffDiagnostics(doc, issues) {
    if (!directVisualBaseline?.entries) {
      return { visualChangeCount: 0, visualChangeElementId: null };
    }

    const current = captureDirectVisualSnapshot(doc);
    const changedKinds = new Set();
    let count = 0;
    let firstElementId = null;

    for (const [key, currentEntry] of current.entries) {
      const baselineEntry = directVisualBaseline.entries.get(key);
      const changeKind = baselineEntry ? visualEntryChangeKind(baselineEntry, currentEntry) : "新增对象";
      if (!changeKind) continue;

      count += 1;
      changedKinds.add(changeKind);
      if (!firstElementId) firstElementId = currentEntry.elementId;
    }

    for (const key of directVisualBaseline.entries.keys()) {
      if (current.entries.has(key)) continue;
      count += 1;
      changedKinds.add("删除对象");
    }

    if (count > 0) {
      const detail = [...changedKinds].slice(0, 4).join("、");
      addDiagnosticIssue(issues, {
        kind: "visual-change",
        severity: "warning",
        title: "视觉变更",
        detail: `${count} 个对象相对打开时发生变化：${detail}`,
        elementId: firstElementId
      });
    }

    return { visualChangeCount: count, visualChangeElementId: firstElementId };
  }

  function collectPPTXMappingDiagnostics(doc, context) {
    const nodes = diagnosticLayoutNodes(doc).slice(0, MAX_HTML_DIAGNOSTIC_NODES);
    let textCount = 0;
    let imageCount = 0;
    let shapeCount = 0;
    let textElementId = null;
    let imageElementId = null;
    let shapeElementId = null;
    const textElementIds = [];
    const imageElementIds = [];
    const shapeElementIds = [];

    for (const node of nodes) {
      if (node.matches?.("script,style,meta,link,title,defs")) continue;
      if (node.matches?.("table,thead,tbody,tfoot,tr,td,th,caption,svg,canvas,iframe")) continue;

      if (node.matches?.("img")) {
        imageCount += 1;
        const elementId = ensureDirectId(node);
        if (!imageElementId) imageElementId = elementId;
        imageElementIds.push(elementId);
        continue;
      }

      if (isPPTXTextObject(node)) {
        textCount += 1;
        const elementId = ensureDirectId(node);
        if (!textElementId) textElementId = elementId;
        textElementIds.push(elementId);
        continue;
      }

      if (isPPTXShapeObject(node)) {
        shapeCount += 1;
        const elementId = ensureDirectId(node);
        if (!shapeElementId) shapeElementId = elementId;
        shapeElementIds.push(elementId);
      }
    }

    const runtime = context.runtimeDiagnostics || {};
    const reviewCount = Math.max(0,
      Number(context.tableCount || 0)
      + Number(context.svgCount || 0)
      + Number(context.pptxEffectDiagnostics?.pptxEffectRiskCount || 0)
      + Number(context.layoutDiagnostics?.overlapCount || 0)
    );
    const fallbackCount = Math.max(0,
      Number(runtime.iframeCount || 0)
      + Number(runtime.canvasCount || 0)
      + Number(runtime.shadowRootCount || 0)
      + Number(runtime.runtimeRootCount || 0)
    );
    const reviewElementIds = pptxReviewElementIds(doc, context);
    const fallbackElementIds = fallbackCount > 0 ? pptxFallbackElementIds(doc) : [];
    const reviewElementId = reviewElementIds[0] || null;
    const fallbackElementId = fallbackElementIds[0] || null;

    return {
      pptxTextObjectCount: textCount,
      pptxImageObjectCount: imageCount,
      pptxShapeObjectCount: shapeCount,
      pptxReviewObjectCount: reviewCount,
      pptxFallbackObjectCount: fallbackCount,
      pptxTextElementId: textElementId,
      pptxImageElementId: imageElementId,
      pptxShapeElementId: shapeElementId,
      pptxReviewElementId: reviewElementId,
      pptxFallbackElementId: fallbackElementId,
      pptxTextElementIds: uniqueIds(textElementIds),
      pptxImageElementIds: uniqueIds(imageElementIds),
      pptxShapeElementIds: uniqueIds(shapeElementIds),
      pptxReviewElementIds: reviewElementIds,
      pptxFallbackElementIds: fallbackElementIds
    };
  }

  function pptxReviewElementIds(doc, context) {
    const tables = [...doc.querySelectorAll("table")].map(ensureDirectId);
    const svgNodes = [...doc.querySelectorAll("svg")].map(ensureDirectId);
    const svgImages = [...doc.querySelectorAll("img")]
      .filter((image) => (image.getAttribute("src") || "").startsWith("data:image/svg"))
      .map(ensureDirectId);
    return uniqueIds([
      ...tables,
      ...svgNodes,
      ...svgImages,
      ...(context.pptxEffectDiagnostics?.pptxEffectRiskElementIds || []),
      ...(context.layoutDiagnostics?.overlapElementIds || [])
    ]);
  }

  function pptxFallbackElementIds(doc) {
    const runtimeRoots = [...doc.querySelectorAll(DIRECT_RUNTIME_ROOT_SELECTOR)]
      .filter((node) => node !== doc.body && node !== doc.documentElement);
    return uniqueIds([
      ...[...doc.querySelectorAll("iframe")].map(ensureDirectId),
      ...[...doc.querySelectorAll("canvas")].map(ensureDirectId),
      ...collectShadowRootHosts(doc).map(ensureDirectId),
      ...runtimeRoots.map(ensureDirectId)
    ]);
  }

  function uniqueIds(ids) {
    return [...new Set(ids.filter((id) => typeof id === "string" && id.length > 0))];
  }

  function isPPTXTextObject(node) {
    if (!directNodeAllowsTextEdit(node) || !normalizedText(node)) return false;
    const tag = node.tagName.toLowerCase();
    if (DIRECT_TEXT_BLOCK_SELECTOR.split(",").includes(tag)) return true;
    return hasMeaningfulDirectText(node);
  }

  function isPPTXShapeObject(node) {
    if (node.children.length > 0 && normalizedText(node)) return false;
    const style = node.ownerDocument.defaultView.getComputedStyle(node);
    if (pptxEffectRiskReason(style)) return false;
    const fill = cssBackground(style);
    const borderWidth = firstBorderWidth(style);
    const hasFill = fill && fill !== "transparent" && !isTransparent(fill);
    const hasBorder = borderWidth > 0.2 && !isTransparent(firstBorderColor(style));
    const hasRadius = (parseFloat(style.borderTopLeftRadius) || 0) > 0.2;
    const hasShadow = shadowValue(style.boxShadow) !== "none";
    return hasFill || hasBorder || hasRadius || hasShadow;
  }

  function visualEntryChangeKind(before, after) {
    if (rectDiffers(before.rect, after.rect)) return "位置/尺寸";
    if (before.text !== after.text) return "文字";
    if (before.imageSource !== after.imageSource) return "图片";
    if (JSON.stringify(before.style) !== JSON.stringify(after.style)) return "样式";
    return null;
  }

  function rectDiffers(before, after) {
    if (!before || !after) return true;
    return Math.abs(before.x - after.x) > 2
      || Math.abs(before.y - after.y) > 2
      || Math.abs(before.w - after.w) > 2
      || Math.abs(before.h - after.h) > 2;
  }

  function collectPPTXEffectDiagnostics(doc, issues) {
    const nodes = diagnosticLayoutNodes(doc).slice(0, MAX_HTML_DIAGNOSTIC_NODES);
    const reasons = new Set();
    let count = 0;
    let firstElementId = null;
    const elementIds = [];

    for (const node of nodes) {
      const style = node.ownerDocument.defaultView.getComputedStyle(node);
      const reason = pptxEffectRiskReason(style);
      if (!reason) continue;

      count += 1;
      reasons.add(reason);
      const elementId = ensureDirectId(node);
      if (!firstElementId) firstElementId = elementId;
      elementIds.push(elementId);
    }

    if (count > 0) {
      const reasonList = [...reasons].slice(0, 4).join("、");
      addDiagnosticIssue(issues, {
        kind: "pptx-effect-risk",
        severity: "warning",
        title: "PPTX 效果复核",
        detail: `${count} 个对象含${reasonList}，导出 PPTX 后需复核高保真和可编辑程度`,
        elementId: firstElementId
      });
    }

    return { pptxEffectRiskCount: count, pptxEffectRiskElementId: firstElementId, pptxEffectRiskElementIds: uniqueIds(elementIds) };
  }

  function pptxEffectRiskReason(style) {
    if (!style) return null;
    const backgroundImage = String(style.backgroundImage || "").toLowerCase();
    if (backgroundImage && backgroundImage !== "none") {
      if (backgroundImage.includes("url(")) return "背景图片";
      if (/(radial|conic|repeating)-gradient\(/.test(backgroundImage)) return "复杂渐变";
    }

    if (hasNonNoneStyleValue(style.filter)) return "滤镜";
    if (hasNonNoneStyleValue(style.backdropFilter) || hasNonNoneStyleValue(style.webkitBackdropFilter)) return "背景滤镜";
    if (hasNonNoneStyleValue(style.clipPath)) return "裁切路径";
    if (hasNonNoneStyleValue(style.maskImage) || hasNonNoneStyleValue(style.webkitMaskImage)) return "蒙版";
    if (style.mixBlendMode && style.mixBlendMode !== "normal") return "混合模式";
    if (style.transform && style.transform.toLowerCase().startsWith("matrix3d(")) return "3D 变换";
    return null;
  }

  function hasNonNoneStyleValue(value) {
    const normalized = String(value || "").trim().toLowerCase();
    return normalized && normalized !== "none";
  }

  function collectLayoutDiagnostics(doc, issues) {
    return {
      ...collectTextOverflowIssues(doc, issues),
      ...collectOutOfBoundsIssues(doc, issues),
      ...collectOverlapIssues(doc, issues)
    };
  }

  function collectTextOverflowIssues(doc, issues) {
    const selector = `${DIRECT_TEXT_BLOCK_SELECTOR},${DIRECT_SAFE_INLINE_SELECTOR},div,label,a,button`;
    const candidates = [...doc.querySelectorAll(selector)].slice(0, MAX_HTML_DIAGNOSTIC_NODES);
    let count = 0;
    let firstElementId = null;

    for (const node of candidates) {
      if (!isTextOverflowDiagnosticCandidate(node)) continue;
      if (!hasTextOverflow(node)) continue;

      count += 1;
      const elementId = ensureDirectId(node);
      if (!firstElementId) firstElementId = elementId;
      addDiagnosticIssue(issues, {
        kind: "text-overflow",
        severity: "error",
        title: "文字溢出",
        detail: truncateDiagnosticText(normalizedText(node), "文本超出当前框"),
        elementId
      });
    }

    return { textOverflowCount: count, textOverflowElementId: firstElementId };
  }

  function collectOutOfBoundsIssues(doc, issues) {
    const nodes = diagnosticLayoutNodes(doc);
    let count = 0;
    let firstElementId = null;

    for (const node of nodes) {
      const frame = diagnosticFrameForNode(node);
      if (!frame) continue;
      const rect = directNodeRect(node);
      const overflow = rectOverflowAmount(rect, frame);
      if (overflow <= 4) continue;

      count += 1;
      const elementId = ensureDirectId(node);
      if (!firstElementId) firstElementId = elementId;
      addDiagnosticIssue(issues, {
        kind: "out-of-bounds",
        severity: "error",
        title: "元素越界",
        detail: `${diagnosticNodeLabel(node)} 超出可视容器 ${Math.round(overflow)}px`,
        elementId
      });
    }

    return { outOfBoundsCount: count, outOfBoundsElementId: firstElementId };
  }

  function collectOverlapIssues(doc, issues) {
    const nodes = diagnosticLayoutNodes(doc)
      .filter((node) => isOverlapDiagnosticNode(node))
      .slice(0, 90);
    let count = 0;
    let firstElementId = null;
    const elementIds = [];
    const reported = new Set();

    for (let index = 0; index < nodes.length; index += 1) {
      const first = nodes[index];
      const firstRect = directNodeRect(first);
      for (let nextIndex = index + 1; nextIndex < nodes.length; nextIndex += 1) {
        const second = nodes[nextIndex];
        if (first.contains(second) || second.contains(first)) continue;
        if (!shouldCompareOverlap(first, second)) continue;

        const secondRect = directNodeRect(second);
        const overlap = rectIntersection(firstRect, secondRect);
        if (!overlap) continue;

        const smallerArea = Math.min(rectArea(firstRect), rectArea(secondRect));
        const overlapRatio = rectArea(overlap) / Math.max(1, smallerArea);
        if (overlapRatio < 0.48 || rectArea(overlap) < 320) continue;

        count += 1;
        const elementId = first.dataset.chiseloId || ensureDirectId(first);
        if (!firstElementId) firstElementId = elementId;
        elementIds.push(elementId);
        const key = `${ensureDirectId(first)}:${ensureDirectId(second)}`;
        if (reported.has(key)) continue;
        reported.add(key);
        addDiagnosticIssue(issues, {
          kind: "overlap",
          severity: "warning",
          title: "元素重叠",
          detail: `${diagnosticNodeLabel(first)} 与 ${diagnosticNodeLabel(second)} 重叠`,
          elementId
        });
      }
    }

    return { overlapCount: count, overlapElementId: firstElementId, overlapElementIds: uniqueIds(elementIds) };
  }

  function addDiagnosticIssue(issues, issue) {
    if (issues.length >= MAX_HTML_DIAGNOSTIC_ISSUES) return;
    issues.push({
      id: `${issue.kind}-${issues.length + 1}`,
      kind: issue.kind,
      severity: issue.severity || "warning",
      title: issue.title,
      detail: issue.detail,
      elementId: issue.elementId || null
    });
  }

  function diagnosticResourceDetail(node, fallback) {
    const src = node.getAttribute("src") || node.getAttribute("href") || "";
    const label = node.getAttribute("alt") || node.getAttribute("aria-label") || src;
    return truncateDiagnosticText(label, fallback);
  }

  function isTextOverflowDiagnosticCandidate(node) {
    if (!node || node.matches?.("html,body,script,style,svg")) return false;
    if (!isDirectNodeVisible(node) || isDecorativeDirectNode(node)) return false;
    if (!directNodeAllowsTextEdit(node) || !normalizedText(node)) return false;

    const tag = node.tagName.toLowerCase();
    if (["div", "section", "article", "header", "footer", "aside"].includes(tag) && !hasMeaningfulDirectText(node)) {
      return false;
    }

    return node.clientWidth > 0 && node.clientHeight > 0;
  }

  function hasTextOverflow(node) {
    const tolerance = 2;
    return node.scrollWidth > node.clientWidth + tolerance || node.scrollHeight > node.clientHeight + tolerance;
  }

  function diagnosticLayoutNodes(doc) {
    const nodes = [...doc.querySelectorAll("[data-chiselo-id]")]
      .slice(0, MAX_HTML_DIAGNOSTIC_NODES)
      .filter((node) => {
        if (!node || node.matches?.("html,body,script,style,meta,link,title,defs")) return false;
        if (!isDirectNodeVisible(node) || isDecorativeDirectNode(node)) return false;
        const rect = directNodeRect(node);
        if (rect.w < 8 || rect.h < 8) return false;
        const frame = diagnosticFrameNodeFor(node);
        return !frame || frame !== node;
      });

    return uniqueElements(nodes);
  }

  function diagnosticFrameForNode(node) {
    const frameNode = diagnosticFrameNodeFor(node);
    if (frameNode) {
      const rect = directNodeRect(frameNode);
      const width = frameNode.clientWidth || rect.w;
      const height = frameNode.clientHeight || rect.h;
      return { x: rect.x, y: rect.y, w: Math.max(1, width), h: Math.max(1, height) };
    }

    return null;
  }

  function diagnosticFrameNodeFor(node) {
    return fixedPageFrameNodeFor(node) || clippingFrameNodeFor(node);
  }

  function fixedPageFrameNodeFor(node) {
    return directPageFrameNodeFor(node);
  }

  function clippingFrameNodeFor(node) {
    const doc = node.ownerDocument;
    let parent = node.parentElement;
    while (parent && parent !== doc.body && parent !== doc.documentElement) {
      if (isDiagnosticClipFrame(parent)) return parent;
      parent = parent.parentElement;
    }
    return null;
  }

  function isDiagnosticClipFrame(node) {
    if (!node || node.matches?.("html,body")) return false;
    const style = node.ownerDocument.defaultView.getComputedStyle(node);
    const overflow = `${style.overflowX} ${style.overflowY}`.toLowerCase();
    if (!/(hidden|clip)/.test(overflow)) return false;

    const rect = node.getBoundingClientRect();
    return rect.width >= 80 && rect.height >= 40;
  }

  function rectOverflowAmount(rect, frame) {
    return Math.max(
      frame.x - rect.x,
      frame.y - rect.y,
      rect.x + rect.w - (frame.x + frame.w),
      rect.y + rect.h - (frame.y + frame.h),
      0
    );
  }

  function isOverlapDiagnosticNode(node) {
    const tag = node.tagName.toLowerCase();
    if (["td", "th", "tr", "thead", "tbody", "tfoot"].includes(tag)) return false;
    if (!diagnosticFrameNodeFor(node) && !isPositionedDiagnosticNode(node)) return false;
    if (normalizedText(node)) return true;
    if (node.matches?.("img,picture,svg,canvas,video,table,button,a")) return true;
    return false;
  }

  function isPositionedDiagnosticNode(node) {
    const style = node.ownerDocument.defaultView.getComputedStyle(node);
    return style.position === "absolute" || style.position === "fixed" || style.position === "sticky" || style.transform !== "none";
  }

  function shouldCompareOverlap(first, second) {
    const firstFrame = diagnosticFrameNodeFor(first);
    const secondFrame = diagnosticFrameNodeFor(second);
    if (firstFrame || secondFrame) return firstFrame === secondFrame;
    return isPositionedDiagnosticNode(first) && isPositionedDiagnosticNode(second);
  }

  function rectIntersection(first, second) {
    const left = Math.max(first.x, second.x);
    const top = Math.max(first.y, second.y);
    const right = Math.min(first.x + first.w, second.x + second.w);
    const bottom = Math.min(first.y + first.h, second.y + second.h);
    if (right <= left || bottom <= top) return null;
    return { x: left, y: top, w: right - left, h: bottom - top };
  }

  function rectArea(rect) {
    return Math.max(0, rect.w) * Math.max(0, rect.h);
  }

  function diagnosticNodeLabel(node) {
    const tag = node.tagName.toLowerCase();
    const id = node.id ? `#${node.id}` : "";
    const text = normalizedText(node);
    if (text) return `${tag}${id}「${truncateDiagnosticText(text, "")}」`;
    const alt = node.getAttribute("alt") || node.getAttribute("aria-label") || "";
    if (alt) return `${tag}${id}「${truncateDiagnosticText(alt, "")}」`;
    return `${tag}${id || ""}`;
  }

  function truncateDiagnosticText(value, fallback) {
    const text = String(value || "").replace(/\s+/g, " ").trim();
    if (!text) return fallback;
    return text.length > 34 ? `${text.slice(0, 33)}...` : text;
  }

  function selectHTML(selector, options = {}) {
    if (editorMode !== "html") return null;
    const node = directFrame?.contentDocument?.querySelector(selector);
    if (!node) return null;
    if (options?.additive) {
      setDirectSelection([...directSelectionNodes(), node], node);
    } else {
      selectDirectNode(node);
    }
    return selectedElement();
  }

  function addHTMLToSelection(selector) {
    return selectHTML(selector, { additive: true });
  }

  function selectHTMLById(id, additive = false) {
    if (editorMode !== "html") return null;
    const escapedId = cssEscape(id);
    const node = directFrame?.contentDocument?.querySelector(`[data-chiselo-id="${escapedId}"]`);
    if (!node) return null;
    if (additive) {
      setDirectSelection([...directSelectionNodes(), node], node);
    } else {
      selectDirectNode(node);
    }
    node.scrollIntoView?.({ block: "center", inline: "center", behavior: "smooth" });
    return selectedElement();
  }

  function selectHTMLAtPoint(x, y, additive = false) {
    if (editorMode !== "html") return null;
    const doc = directFrame?.contentDocument;
    if (!doc) return null;

    const target = doc.elementFromPoint(x, y) || doc.body;
    const node = directSelectionTargetFromEvent({ target, clientX: x, clientY: y });
    if (!node) return null;

    if (additive) {
      setDirectSelection([...directSelectionNodes(), node], node);
    } else {
      selectDirectNode(node);
    }
    return selectedElement();
  }

  function cssEscape(value) {
    if (window.CSS?.escape) return CSS.escape(value);
    return String(value).replace(/["\\]/g, "\\$&");
  }

  function setSelectedHTMLText(text) {
    if (editorMode !== "html" || !directSelectedNode) return null;
    pushHistory();
    directSelectedNode.textContent = text;
    updateSelectionBox();
    scheduleHTMLTreeChanged();
    postSelectionChanged();
    return selectedElement();
  }

  function staticElementHTML(element) {
    const base = [
      `left:${element.x}px`,
      `top:${element.y}px`,
      `width:${element.w}px`,
      `height:${element.h}px`,
      `z-index:${element.z}`,
      `transform:rotate(${element.rotation || 0}deg)`
    ].join(";");

    if (element.type === "text") {
      const style = element.style || {};
      const textStyle = [
        `font-family:${style.fontFamily || "-apple-system, BlinkMacSystemFont, sans-serif"}`,
        `font-size:${style.fontSize || 28}px`,
        `font-weight:${style.fontWeight || 400}`,
        `line-height:${style.lineHeight || 1.2}`,
        `color:${style.color || "#111827"}`,
        `text-align:${style.textAlign || "left"}`,
        `background:${style.fill || "transparent"}`,
        `border:${style.strokeWidth || 0}px solid ${style.stroke || "transparent"}`,
        `border-radius:${style.radius || 0}px`,
        `box-shadow:${shadowValue(style.shadow)}`
      ].join(";");

      return `    <div class="element" style="${base}"><div class="text-content" style="${textStyle}">${escapeHTML(element.text || "")}</div></div>`;
    }

    if (element.type === "image") {
      const style = element.style || {};
      const imageStyle = [
        "width:100%",
        "height:100%",
        "display:block",
        `object-fit:${objectFitValue(style.objectFit, "cover")}`,
        `border:${style.strokeWidth || 0}px solid ${style.stroke || "transparent"}`,
        `border-radius:${style.radius || 0}px`,
        `box-shadow:${shadowValue(style.shadow)}`
      ].join(";");
      return `    <div class="element" style="${base}"><img class="image-content" src="${escapeHTML(element.imageSource || "")}" alt="${escapeHTML(element.imageAlt || "")}" style="${imageStyle}"></div>`;
    }

    const style = element.style || {};
    const shapeStyle = [
      `background:${style.fill || "#ffffff"}`,
      `border:${style.strokeWidth || 0}px solid ${style.stroke || "transparent"}`,
      `border-radius:${style.radius || 0}px`,
      `box-shadow:${shadowValue(style.shadow)}`
    ].join(";");

    return `    <div class="element" style="${base}"><div class="shape-content" style="${shapeStyle}"></div></div>`;
  }

  function escapeHTML(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  stage.addEventListener("pointerdown", (event) => {
    if (event.target === stage || event.target === surface || event.target === layer) {
      clearSelection();
    }
  });

  window.addEventListener("resize", () => {
    fitStage({ preserveScale: editorMode === "html" });
    updatePageBoundaryOverlay();
    scheduleSelectionBoxUpdate();
  });
  viewport.addEventListener("wheel", handleViewportWheel, { passive: false });

  function handleEditorKeydown(event) {
    if (isEditingText()) return;

    if (editorMode === "html" && event.key === "Enter" && !event.metaKey && !event.ctrlKey && !event.altKey) {
      const node = directTextEditTarget(directSelectedNode);
      if (node) {
        event.preventDefault();
        beginDirectTextEdit(node);
      }
      return;
    }

    const step = event.shiftKey ? 10 : 1;
    const nudgeMap = {
      ArrowLeft: [-step, 0],
      ArrowRight: [step, 0],
      ArrowUp: [0, -step],
      ArrowDown: [0, step]
    };

    if (event.key in nudgeMap) {
      event.preventDefault();
      const [dx, dy] = nudgeMap[event.key];
      nudgeSelected(dx, dy);
      return;
    }

    if (event.key === "Delete" || event.key === "Backspace") {
      event.preventDefault();
      deleteSelected();
      return;
    }

    if (!(event.metaKey || event.ctrlKey)) return;
    if (event.key.toLowerCase() === "z" && event.shiftKey) {
      event.preventDefault();
      redo();
    } else if (event.key.toLowerCase() === "z") {
      event.preventDefault();
      undo();
    }
  }

  window.addEventListener("keydown", handleEditorKeydown);

  function setBackdropStyle(style) {
    const allowed = new Set(["clean", "grid", "dots"]);
    document.documentElement.dataset.backdrop = allowed.has(style) ? style : "clean";
  }

  function isEditingText() {
    const active = document.activeElement;
    if (active?.isContentEditable || active?.matches?.("input, textarea")) return true;

    const directActive = directFrame?.contentDocument?.activeElement;
    return Boolean(directActive?.isContentEditable || directActive?.matches?.("input, textarea"));
  }

  window.ChiseloEditor = {
    addHTMLToSelection,
    command,
    exportHTML,
    getDeck: () => clone(deck),
    clearDirty,
    getHTMLTree: buildHTMLTree,
    getHTMLSummary,
    getImportDiagnostics,
    getPageFrames: () => pageFramesForCurrentMode().map((frame) => ({
      index: frame.index,
      label: frame.label,
      x: frame.rect.x,
      y: frame.rect.y,
      w: frame.rect.w,
      h: frame.rect.h
    })),
    getViewportState: () => ({
      scale,
      fitScale,
      userZoom,
      viewportScrollLeft: viewport.scrollLeft,
      viewportScrollTop: viewport.scrollTop,
      stageWidth: stage.offsetWidth,
      stageHeight: stage.offsetHeight,
      stageOuterWidth: stageOuter.offsetWidth,
      stageOuterHeight: stageOuter.offsetHeight
    }),
    getSelection: () => selectedElement(),
    importHTMLFromBase64,
    loadDeck,
    loadDeckFromBase64,
    newDeck,
    openHTMLFromBase64,
    selectElementById,
    selectGroupById,
    selectSlide,
    selectHTML,
    selectHTMLById,
    selectHTMLAtPoint,
    replaceSelectedImageFromBase64,
    replaceSelectedImageSrc,
    settleSelectedImage,
    setBackdropStyle,
    setSelectedHTMLText,
    updateElement
  };

  setBackdropStyle("clean");
  render();
  postSelectionChanged({ immediate: true });
  postMessage("bridgeReady");
})();
