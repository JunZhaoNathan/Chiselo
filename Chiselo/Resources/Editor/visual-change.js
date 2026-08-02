(() => {
  "use strict";

  function create(dependencies = {}) {
    const {
      visualStylesheetRuleDiffers,
      truncateDiagnosticText,
      maxRevertTextLength = 10000
    } = dependencies;

    if (typeof visualStylesheetRuleDiffers !== "function") {
      throw new TypeError("ChiseloVisualChange requires visualStylesheetRuleDiffers().");
    }
    if (typeof truncateDiagnosticText !== "function") {
      throw new TypeError("ChiseloVisualChange requires truncateDiagnosticText().");
    }

    function filterVisualChangeRecords(records) {
      return records.filter((record) => !isDuplicateAncestorVisualChange(record, records));
    }

    function isDuplicateAncestorVisualChange(record, records) {
      if (!record?.key || record.kind !== "文字") return false;
      const childPrefix = `${record.key} > `;
      return records.some((other) => (
        other !== record
        && other.kind === "文字"
        && typeof other.key === "string"
        && other.key.startsWith(childPrefix)
      ));
    }

    function visualChangePreviewItem({ key, kind, before, after, revertInfo }) {
      const entry = after || before || {};
      const rect = entry?.rect || {};
      const detail = visualChangeDetail(kind, before, after);
      const writebackKind = visualChangeWritebackKind(before, after);
      const writebackTarget = visualChangeWritebackTarget(writebackKind, before, after);
      return {
        changeKey: key || null,
        elementId: entry?.elementId || null,
        label: truncateDiagnosticText(entry?.label || "", "对象"),
        kind,
        detail: detail.detail,
        beforeValue: detail.beforeValue,
        afterValue: detail.afterValue,
        writebackKind,
        writebackLabel: visualChangeWritebackLabel(writebackKind),
        writebackTarget,
        canRevert: Boolean(revertInfo?.canRevert),
        revertReason: revertInfo?.reason || null,
        x: Math.round(Number(rect.x || 0)),
        y: Math.round(Number(rect.y || 0)),
        w: Math.round(Number(rect.w || 0)),
        h: Math.round(Number(rect.h || 0))
      };
    }

    function visualChangeWritebackKind(before, after) {
      if (!before || !after) return null;
      if (visualChangeIsLocalFrameStabilityOnly(before, after)) return "layout-stability";
      if (String(before.styleAttr || "") !== String(after.styleAttr || "")) return "inline-style";
      if (visualStylesheetRuleDiffers(before, after)) return "stylesheet-rule";
      return null;
    }

    function visualChangeIsLocalFrameStabilityOnly(before, after) {
      if (!before || !after || before.localFrameLocked || !after.localFrameLocked) return false;
      const hasWriteback = String(before.styleAttr || "") !== String(after.styleAttr || "")
        || visualStylesheetRuleDiffers(before, after);
      return hasWriteback
        && visualStyleDiffKeys(before.style, after.style).length === 0
        && !rectDiffers(before.rect, after.rect);
    }

    function visualChangeWritebackTarget(kind, before, after) {
      if (kind === "inline-style") return "style";
      if (kind === "stylesheet-rule") return after?.stylesheetRule?.selector || before?.stylesheetRule?.selector || null;
      if (kind === "layout-stability") {
        return visualStylesheetRuleDiffers(before, after)
          ? after?.stylesheetRule?.selector || before?.stylesheetRule?.selector || null
          : "style";
      }
      return null;
    }

    function visualChangeWritebackLabel(kind) {
      if (kind === "inline-style") return "inline style";
      if (kind === "stylesheet-rule") return "CSS 规则";
      if (kind === "layout-stability") return "局部尺寸保护";
      return null;
    }

    function visualChangeRevertInfo(kind, before, after) {
      if (!before && after) {
        return { canRevert: true, reason: null };
      }
      if (before && !after) {
        return before.outerHTML && before.parentKey
          ? { canRevert: true, reason: null }
          : { canRevert: false, reason: "已删除对象缺少可恢复源码快照，请从版本历史恢复或手动重建。" };
      }
      if (!before || !after) {
        return { canRevert: false, reason: "缺少打开时或当前对象快照。" };
      }

      if (kind === "文字") {
        if (before.childElementCount > 0 || after.childElementCount > 0) {
          return { canRevert: false, reason: "对象含内联结构，自动回退可能破坏源码层级。" };
        }
        if (String(before.text || "").length > maxRevertTextLength) {
          return { canRevert: false, reason: "文字过长，建议定位后手动复核。" };
        }
        return { canRevert: true, reason: null };
      }

      if (kind === "图片") {
        return after.imageSource !== undefined
          ? { canRevert: true, reason: null }
          : { canRevert: false, reason: "当前对象不是可替换图片。" };
      }

      if (kind === "位置/尺寸" || kind === "样式") {
        return before.styleAttr !== after.styleAttr || visualStylesheetRuleDiffers(before, after)
          ? { canRevert: true, reason: null }
          : { canRevert: false, reason: "变化来自样式表、响应式规则或父级布局，先定位后手动复核更安全。" };
      }

      return { canRevert: false, reason: "此类变化暂不支持一键回退。" };
    }

    function visualChangeDetail(kind, before, after) {
      if (!before && after) {
        return {
          detail: "新增对象，回退会从当前 HTML 中移除此对象。",
          beforeValue: "无",
          afterValue: visualRectText(after.rect)
        };
      }
      if (before && !after) {
        return {
          detail: "对象已删除，可尝试一键恢复到打开时的位置。",
          beforeValue: visualRectText(before.rect),
          afterValue: "已删除"
        };
      }
      if (!before || !after) {
        return { detail: "缺少可比对快照。", beforeValue: null, afterValue: null };
      }

      if (kind === "位置/尺寸") {
        return {
          detail: "位置或尺寸发生变化。",
          beforeValue: visualRectText(before.rect),
          afterValue: visualRectText(after.rect)
        };
      }
      if (kind === "文字") {
        return {
          detail: "文字内容发生变化。",
          beforeValue: truncateDiagnosticText(before.text, "空文字"),
          afterValue: truncateDiagnosticText(after.text, "空文字")
        };
      }
      if (kind === "图片") {
        return {
          detail: "图片来源发生变化。",
          beforeValue: visualSourceLabel(before.imageSource),
          afterValue: visualSourceLabel(after.imageSource)
        };
      }

      const changedStyles = visualStyleDiffKeys(before.style, after.style);
      const detailSuffix = visualStylesheetRuleDiffers(before, after) ? "（写回样式表规则）" : "";
      return {
        detail: changedStyles.length ? `关键样式变化：${changedStyles.join("、")}${detailSuffix}` : `关键样式发生变化${detailSuffix}。`,
        beforeValue: visualStyleSummary(before.style, changedStyles),
        afterValue: visualStyleSummary(after.style, changedStyles)
      };
    }

    function visualRectText(rect) {
      if (!rect) return "";
      return `x ${Math.round(rect.x || 0)}, y ${Math.round(rect.y || 0)}, ${Math.round(rect.w || 0)} x ${Math.round(rect.h || 0)}`;
    }

    function visualSourceLabel(value) {
      const source = String(value || "").trim();
      if (!source) return "空";
      if (source.startsWith("data:")) return "嵌入图片";
      return truncateDiagnosticText(source.split(/[/?#]/).filter(Boolean).pop() || source, source);
    }

    function visualStyleDiffKeys(before = {}, after = {}) {
      const labels = {
        color: "文字色",
        background: "背景",
        borderColor: "边框色",
        borderWidth: "边框",
        radius: "圆角",
        fontSize: "字号",
        fontWeight: "字重",
        textAlign: "对齐",
        objectFit: "图片适配",
        opacity: "透明度",
        shadow: "阴影"
      };
      return Object.keys(labels).filter((key) => JSON.stringify(before?.[key]) !== JSON.stringify(after?.[key])).map((key) => labels[key]);
    }

    function visualStyleSummary(style = {}, changedKeys = []) {
      if (!changedKeys.length) return "";
      const reverseLabels = {
        "文字色": "color",
        "背景": "background",
        "边框色": "borderColor",
        "边框": "borderWidth",
        "圆角": "radius",
        "字号": "fontSize",
        "字重": "fontWeight",
        "对齐": "textAlign",
        "图片适配": "objectFit",
        "透明度": "opacity",
        "阴影": "shadow"
      };
      return changedKeys
        .slice(0, 3)
        .map((label) => `${label} ${truncateDiagnosticText(style?.[reverseLabels[label]], "空")}`)
        .join("；");
    }

    function visualEntryChangeKind(before, after) {
      if (before.imageSource !== after.imageSource) return "图片";
      if (before.text !== after.text && !(before.childElementCount > 0 || after.childElementCount > 0)) return "文字";
      if (JSON.stringify(before.style) !== JSON.stringify(after.style)) return "样式";
      if (rectDiffers(before.rect, after.rect)) return "位置/尺寸";
      return null;
    }

    function rectDiffers(before, after) {
      if (!before || !after) return true;
      return Math.abs(before.x - after.x) > 2
        || Math.abs(before.y - after.y) > 2
        || Math.abs(before.w - after.w) > 2
        || Math.abs(before.h - after.h) > 2;
    }

    return Object.freeze({
      filterRecords: filterVisualChangeRecords,
      previewItem: visualChangePreviewItem,
      writebackKind: visualChangeWritebackKind,
      isLocalFrameStabilityOnly: visualChangeIsLocalFrameStabilityOnly,
      revertInfo: visualChangeRevertInfo,
      entryChangeKind: visualEntryChangeKind
    });
  }

  window.ChiseloVisualChange = Object.freeze({ create });
})();
