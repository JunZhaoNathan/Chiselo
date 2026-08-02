(() => {
  "use strict";

  const MISSING_ATTRIBUTE = "__chiselo_safe_missing__";
  const BLOCKED_SCRIPT_TYPE = "application/x-chiselo-blocked";
  const URL_ATTRIBUTES = [
    { name: "href", marker: "data-chiselo-safe-url-href" },
    { name: "src", marker: "data-chiselo-safe-url-src" },
    { name: "xlink:href", marker: "data-chiselo-safe-url-xlink-href" },
    { name: "action", marker: "data-chiselo-safe-url-action" },
    { name: "formaction", marker: "data-chiselo-safe-url-formaction" },
    { name: "data", marker: "data-chiselo-safe-url-data" }
  ];

  function prepareHTML(html) {
    const parsed = new DOMParser().parseFromString(html, "text/html");
    const nodes = [parsed.documentElement, ...parsed.querySelectorAll("*")];

    for (const node of nodes) {
      if (node.matches?.("script")) {
        node.setAttribute(
          "data-chiselo-safe-script-type",
          node.hasAttribute("type") ? (node.getAttribute("type") || "") : MISSING_ATTRIBUTE
        );
        node.setAttribute("type", BLOCKED_SCRIPT_TYPE);
      }

      for (const attribute of [...(node.attributes || [])]) {
        if (!/^on[a-z0-9_-]+$/i.test(attribute.name)) continue;
        node.setAttribute(`data-chiselo-safe-event-${attribute.name.toLowerCase()}`, attribute.value);
        node.removeAttribute(attribute.name);
      }

      for (const item of URL_ATTRIBUTES) {
        if (!node.hasAttribute?.(item.name)) continue;
        const value = node.getAttribute(item.name) || "";
        if (!/^\s*javascript:/i.test(value)) continue;
        node.setAttribute(item.marker, value);
        node.removeAttribute(item.name);
      }

      if (node.matches?.("meta[http-equiv]") && /^refresh$/i.test(node.getAttribute("http-equiv") || "")) {
        node.setAttribute("data-chiselo-safe-meta-http-equiv", node.getAttribute("http-equiv") || "");
        node.removeAttribute("http-equiv");
      }

      if (node.matches?.("iframe")) {
        node.setAttribute(
          "data-chiselo-safe-frame-sandbox",
          node.hasAttribute("sandbox") ? (node.getAttribute("sandbox") || "") : MISSING_ATTRIBUTE
        );
        node.setAttribute("sandbox", "");
      }
    }

    return `${/^\s*<!doctype\b/i.test(html) ? "<!doctype html>\n" : ""}${parsed.documentElement.outerHTML}`;
  }

  function restoreNode(node) {
    if (!node?.attributes) return;

    if (node.hasAttribute("data-chiselo-safe-script-type")) {
      const type = node.getAttribute("data-chiselo-safe-script-type");
      if (type === MISSING_ATTRIBUTE) node.removeAttribute("type");
      else node.setAttribute("type", type || "");
    }

    for (const attribute of [...node.attributes]) {
      const prefix = "data-chiselo-safe-event-";
      if (!attribute.name.startsWith(prefix)) continue;
      node.setAttribute(attribute.name.slice(prefix.length), attribute.value);
    }

    for (const item of URL_ATTRIBUTES) {
      if (node.hasAttribute(item.marker)) {
        node.setAttribute(item.name, node.getAttribute(item.marker) || "");
      }
    }

    if (node.hasAttribute("data-chiselo-safe-meta-http-equiv")) {
      node.setAttribute("http-equiv", node.getAttribute("data-chiselo-safe-meta-http-equiv") || "refresh");
    }

    if (node.hasAttribute("data-chiselo-safe-frame-sandbox")) {
      const sandbox = node.getAttribute("data-chiselo-safe-frame-sandbox");
      if (sandbox === MISSING_ATTRIBUTE) node.removeAttribute("sandbox");
      else node.setAttribute("sandbox", sandbox || "");
    }
  }

  window.ChiseloRuntimeSafety = Object.freeze({ prepareHTML, restoreNode });
})();
