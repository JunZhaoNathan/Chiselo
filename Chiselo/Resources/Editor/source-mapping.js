(() => {
  "use strict";

  function create(dependencies = {}) {
    const {
      directSourceNodeIsVisible,
      normalizedClassList,
      normalizedText,
      directNodeToken
    } = dependencies;

    for (const [name, dependency] of Object.entries({
      directSourceNodeIsVisible,
      normalizedClassList,
      normalizedText,
      directNodeToken
    })) {
      if (typeof dependency !== "function") {
        throw new TypeError(`ChiseloSourceMapping requires ${name}().`);
      }
    }

    function preserveDirectSourceChildIds(previousRoot, replacementRoot) {
      if (!previousRoot || !replacementRoot) return;

      if (!replacementRoot.dataset?.chiseloId && previousRoot.dataset?.chiseloId) {
        replacementRoot.dataset.chiseloId = previousRoot.dataset.chiseloId;
      }

      preserveDirectSourceSubtreeIds(previousRoot, replacementRoot);
    }

    function preserveDirectSourceSubtreeIds(previousNode, replacementNode) {
      const previousChildren = [...previousNode.querySelectorAll?.("*") || []]
        .filter((node) => directSourceNodeIsVisible(node));
      const replacementChildren = [...replacementNode.querySelectorAll?.("*") || []]
        .filter((node) => directSourceNodeIsVisible(node));
      if (!previousChildren.length || !replacementChildren.length) return;

      for (const { previous, replacement } of directSourceMatchedChildPairs(previousChildren, replacementChildren)) {
        if (previous.dataset?.chiseloId && !replacement.dataset?.chiseloId) {
          replacement.dataset.chiseloId = previous.dataset.chiseloId;
        }
      }
    }

    function sourceDraftMappingSummary(previousRoot, replacementRoot) {
      if (!previousRoot || !replacementRoot) return null;

      const previousNodes = [previousRoot, ...([...previousRoot.querySelectorAll?.("*") || []].filter((node) => directSourceNodeIsVisible(node)))];
      const replacementNodes = [replacementRoot, ...([...replacementRoot.querySelectorAll?.("*") || []].filter((node) => directSourceNodeIsVisible(node)))];
      const pairs = directSourceMatchedChildPairs(previousNodes, replacementNodes);
      const matchedPrevious = new Set(pairs.map((pair) => pair.previous));
      const matchedReplacement = new Set(pairs.map((pair) => pair.replacement));

      const items = [];
      for (const pair of pairs.slice(0, 8)) {
        items.push({
          slot: "preserved",
          kind: "保留原对象",
          previousID: pair.previous.dataset?.chiseloId || "",
          previousTagName: pair.previous.tagName?.toLowerCase?.() || "",
          previousLabel: directSourcePreviewLabel(pair.previous),
          nextTagName: pair.replacement.tagName?.toLowerCase?.() || "",
          nextLabel: directSourcePreviewLabel(pair.replacement),
          score: Math.round(pair.score || 0)
        });
      }

      const addedAll = replacementNodes.filter((node) => !matchedReplacement.has(node));
      const unmatchedAll = previousNodes.filter((node) => !matchedPrevious.has(node));
      const addedNodes = addedAll.slice(0, 4);
      for (const node of addedNodes) {
        items.push({
          slot: "added",
          kind: "新增对象",
          previousID: null,
          previousTagName: null,
          previousLabel: null,
          nextTagName: node.tagName?.toLowerCase?.() || "",
          nextLabel: directSourcePreviewLabel(node),
          score: null
        });
      }

      const unmatchedNodes = unmatchedAll.slice(0, 4);
      for (const node of unmatchedNodes) {
        items.push({
          slot: "unmatched",
          kind: "原对象将替换",
          previousID: node.dataset?.chiseloId || "",
          previousTagName: node.tagName?.toLowerCase?.() || "",
          previousLabel: directSourcePreviewLabel(node),
          nextTagName: "",
          nextLabel: "",
          score: null
        });
      }

      return {
        preservedCount: pairs.length,
        addedCount: addedAll.length,
        unmatchedCount: unmatchedAll.length,
        structureRisk: addedAll.length > 0 || unmatchedAll.length > 0,
        items
      };
    }

    function directSourceMatchedChildPairs(previousChildren, replacementChildren) {
      const candidates = [];

      for (let previousIndex = 0; previousIndex < previousChildren.length; previousIndex += 1) {
        for (let replacementIndex = 0; replacementIndex < replacementChildren.length; replacementIndex += 1) {
          const previous = previousChildren[previousIndex];
          const replacement = replacementChildren[replacementIndex];
          const score = directSourceMatchScore(previous, replacement, previousIndex, replacementIndex);
          if (score > 0) {
            candidates.push({ previous, replacement, score, previousIndex, replacementIndex });
          }
        }
      }

      candidates.sort((left, right) =>
        right.score - left.score ||
        left.previousIndex - right.previousIndex ||
        left.replacementIndex - right.replacementIndex
      );

      const matchedPrevious = new Set();
      const matchedReplacement = new Set();
      const assignments = [];

      for (const candidate of candidates) {
        if (candidate.score < 18) continue;
        if (matchedPrevious.has(candidate.previous) || matchedReplacement.has(candidate.replacement)) continue;
        matchedPrevious.add(candidate.previous);
        matchedReplacement.add(candidate.replacement);
        assignments.push(candidate);
      }

      return assignments;
    }

    function directSourceMatchScore(previous, replacement, previousIndex = 0, replacementIndex = 0) {
      if (!previous || !replacement) return Number.NEGATIVE_INFINITY;

      let score = 0;
      const previousTag = previous.tagName?.toLowerCase?.() || "";
      const replacementTag = replacement.tagName?.toLowerCase?.() || "";
      if (previousTag && replacementTag && previousTag === replacementTag) score += 24;

      const previousId = previous.getAttribute?.("id") || "";
      const replacementId = replacement.getAttribute?.("id") || "";
      if (previousId && replacementId) {
        if (previousId === replacementId) {
          score += 120;
        } else if (directStringSimilarity(previousId, replacementId) >= 0.75) {
          score += 30;
        }
      } else if (previousId || replacementId) {
        score += 4;
      }

      score += directSourceClassScore(previous, replacement);
      score += directSourceTokenScore(previous, replacement);
      score += directSourceTextScore(previous, replacement);

      const previousCount = directSourceMatchableChildren(previous).length;
      const replacementCount = directSourceMatchableChildren(replacement).length;
      score += Math.max(0, 10 - Math.abs(previousCount - replacementCount));

      const previousKey = previous.parentElement ? directRelativeElementKey(previous.parentElement, previous) : "";
      const replacementKey = replacement.parentElement ? directRelativeElementKey(replacement.parentElement, replacement) : "";
      if (previousKey && previousKey === replacementKey) score += 24;

      score += Math.max(0, 12 - Math.abs(previousIndex - replacementIndex) * 3);
      return score;
    }

    function directSourceClassScore(previous, replacement) {
      const previousClasses = normalizedClassList(previous).split(/\s+/).filter(Boolean);
      const replacementClasses = normalizedClassList(replacement).split(/\s+/).filter(Boolean);
      if (!previousClasses.length && !replacementClasses.length) return 0;

      const previousSet = new Set(previousClasses);
      const replacementSet = new Set(replacementClasses);
      let shared = 0;
      for (const name of previousSet) {
        if (replacementSet.has(name)) shared += 1;
      }

      const union = new Set([...previousSet, ...replacementSet]).size || 1;
      let score = Math.round((shared / union) * 18);
      if (previousClasses.length && replacementClasses.length && previousClasses.join("|") === replacementClasses.join("|")) {
        score += 12;
      }
      return score;
    }

    function directSourceTokenScore(previous, replacement) {
      const previousTokens = directSourceIdentityTokens(previous);
      const replacementTokens = directSourceIdentityTokens(replacement);
      if (!previousTokens.length && !replacementTokens.length) return 0;

      const previousSet = new Set(previousTokens);
      const replacementSet = new Set(replacementTokens);
      let shared = 0;
      for (const token of previousSet) {
        if (replacementSet.has(token)) shared += 1;
      }

      return Math.min(24, shared * 8);
    }

    function directSourceTextScore(previous, replacement) {
      const previousText = directSourceMatchText(previous);
      const replacementText = directSourceMatchText(replacement);
      if (!previousText && !replacementText) return 0;
      if (previousText && previousText === replacementText) return 18;

      const previousTrimmed = previousText.replace(/\s+/g, " ");
      const replacementTrimmed = replacementText.replace(/\s+/g, " ");
      if (!previousTrimmed || !replacementTrimmed) return 0;

      if (previousTrimmed === replacementTrimmed) return 18;
      if (previousTrimmed.includes(replacementTrimmed) || replacementTrimmed.includes(previousTrimmed)) {
        return Math.min(16, Math.max(previousTrimmed.length, replacementTrimmed.length) / 2);
      }

      const prefixLength = directCommonPrefixLength(previousTrimmed, replacementTrimmed);
      if (prefixLength >= 4) return Math.min(10, prefixLength);
      return 0;
    }

    function directSourceMatchText(node) {
      if (!node) return "";
      return normalizedText(node).slice(0, 64);
    }

    function directSourcePreviewLabel(node) {
      if (!node) return "";
      const tag = node.tagName?.toLowerCase?.() || "";
      const text = normalizedText(node).slice(0, 28);
      return text ? `${tag}「${text}」` : directNodeToken(node);
    }

    function directSourceIdentityTokens(node) {
      if (!node || node.nodeType !== Node.ELEMENT_NODE) return [];

      const attributes = ["role", "aria-label", "aria-labelledby", "title", "alt", "name", "placeholder", "type", "data-testid", "data-name"];
      const tokens = [];
      for (const attribute of attributes) {
        const value = node.getAttribute?.(attribute);
        if (value) tokens.push(value.trim().toLowerCase());
      }
      return [...new Set(tokens)];
    }

    function directSourceMatchableChildren(node) {
      if (!node || node.nodeType !== Node.ELEMENT_NODE) return [];
      return [...node.children].filter((child) => directSourceNodeIsVisible(child));
    }

    function directCommonPrefixLength(left, right) {
      const length = Math.min(left.length, right.length);
      let index = 0;
      while (index < length && left[index] === right[index]) index += 1;
      return index;
    }

    function directStringSimilarity(left, right) {
      const a = String(left || "").trim().toLowerCase();
      const b = String(right || "").trim().toLowerCase();
      if (!a || !b) return 0;
      if (a === b) return 1;

      const longest = Math.max(a.length, b.length);
      const prefix = directCommonPrefixLength(a, b);
      const suffix = directCommonSuffixLength(a, b);
      return Math.max(prefix, suffix) / longest;
    }

    function directCommonSuffixLength(left, right) {
      const max = Math.min(left.length, right.length);
      let index = 0;
      while (index < max && left[left.length - 1 - index] === right[right.length - 1 - index]) index += 1;
      return index;
    }

    function directRelativeElementKey(root, node) {
      if (!root || !node || node === root) return "";

      const parts = [];
      let current = node;
      while (current && current !== root && current.parentElement) {
        const siblings = [...current.parentElement.children]
          .filter((child) => child.tagName === current.tagName);
        const index = siblings.indexOf(current);
        if (index < 0) return "";
        parts.unshift(`${current.tagName.toLowerCase()}:${index}`);
        current = current.parentElement;
      }

      return current === root ? parts.join(">") : "";
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

    return Object.freeze({
      preserveDirectSourceChildIds,
      sourceDraftMappingSummary,
      normalizeDirectHTMLSource
    });
  }

  window.ChiseloSourceMapping = Object.freeze({ create });
})();
