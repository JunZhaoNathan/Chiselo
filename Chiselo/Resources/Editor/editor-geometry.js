(() => {
  "use strict";

  function create(options = {}) {
    const minSize = Number(options.minSize);
    const snapDistance = Number(options.snapDistance);
    if (!Number.isFinite(minSize) || minSize <= 0) {
      throw new TypeError("ChiseloEditorGeometry requires a positive minSize.");
    }
    if (!Number.isFinite(snapDistance) || snapDistance < 0) {
      throw new TypeError("ChiseloEditorGeometry requires a non-negative snapDistance.");
    }

    function clampNumber(value, min, max) {
      return Math.max(min, Math.min(max, value));
    }

    function resizeRect(rect, handle, dx, dy, ratio) {
      const next = { ...rect };

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
          next.h = Math.max(minSize, next.w / ratio);
          if (sign < 0) next.y = rect.y + rect.h - next.h;
        } else {
          const sign = handle.includes("w") ? -1 : 1;
          next.w = Math.max(minSize, next.h * ratio);
          if (sign < 0) next.x = rect.x + rect.w - next.w;
        }
      }

      if (next.w < minSize) {
        if (handle.includes("w")) next.x = rect.x + rect.w - minSize;
        next.w = minSize;
      }
      if (next.h < minSize) {
        if (handle.includes("n")) next.y = rect.y + rect.h - minSize;
        next.h = minSize;
      }
      return next;
    }

    function bestSnap(edges, candidates) {
      let best = null;
      for (const edge of edges) {
        for (const candidate of candidates) {
          const distance = Math.abs(edge.value() - candidate.value);
          if (distance <= snapDistance && (!best || distance < best.distance)) {
            best = { edge, candidate, distance };
          }
        }
      }
      return best;
    }

    function snapNumber(value, grid) {
      return Math.round(value / grid) * grid;
    }

    function distanceToRect(x, y, rect) {
      const dx = x < rect.left ? rect.left - x : x > rect.right ? x - rect.right : 0;
      const dy = y < rect.top ? rect.top - y : y > rect.bottom ? y - rect.bottom : 0;
      return Math.hypot(dx, dy);
    }

    function formatTransformNumber(value) {
      return String(Math.round(clampNumber(value, 0.05, 20) * 1000) / 1000);
    }

    function rectChanged(left, right) {
      return Math.abs((left?.x || 0) - (right?.x || 0)) > 0.5
        || Math.abs((left?.y || 0) - (right?.y || 0)) > 0.5
        || Math.abs((left?.w || 0) - (right?.w || 0)) > 0.5
        || Math.abs((left?.h || 0) - (right?.h || 0)) > 0.5;
    }

    function elementArea(element) {
      return Math.max(1, Number(element.w || 0) * Number(element.h || 0));
    }

    function roundedRect(rect, parentRect) {
      return {
        x: Math.round(rect.left - parentRect.left),
        y: Math.round(rect.top - parentRect.top),
        w: Math.round(rect.width),
        h: Math.round(rect.height)
      };
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

    return Object.freeze({
      clampNumber,
      resizeRect,
      bestSnap,
      snapNumber,
      distanceToRect,
      formatTransformNumber,
      rectChanged,
      elementArea,
      roundedRect,
      rectOverflowAmount,
      rectIntersection,
      rectArea
    });
  }

  window.ChiseloEditorGeometry = Object.freeze({ create });
})();
