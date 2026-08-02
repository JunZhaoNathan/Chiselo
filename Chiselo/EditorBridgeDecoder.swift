import CoreGraphics
import Foundation

enum EditorBridgeDecoder {
    static func selectionMessage(from body: [String: Any]) -> BridgeSelectionMessage {
        BridgeSelectionMessage(
            type: "selectionChanged",
            slideIndex: int(body["slideIndex"]),
            path: string(body["path"]),
            element: element(body["element"])
        )
    }

    static func element(_ value: Any?) -> EditorElement? {
        guard let object = value as? [String: Any],
              let id = string(object["id"]),
              let type = string(object["type"]),
              let x = double(object["x"]),
              let y = double(object["y"]),
              let w = double(object["w"]),
              let h = double(object["h"]),
              let rotation = double(object["rotation"]),
              let z = double(object["z"]) else {
            return nil
        }

        return EditorElement(
            id: id,
            type: type,
            tagName: string(object["tagName"]),
            htmlPath: string(object["htmlPath"]),
            className: string(object["className"]),
            inlineStyle: string(object["inlineStyle"]),
            linkHref: string(object["linkHref"]),
            linkTarget: string(object["linkTarget"]),
            semanticRole: string(object["semanticRole"]),
            semanticLabel: string(object["semanticLabel"]),
            groupId: string(object["groupId"]),
            groupRole: string(object["groupRole"]),
            groupLabel: string(object["groupLabel"]),
            sourceKind: string(object["sourceKind"]),
            sourceSnippet: string(object["sourceSnippet"]),
            sourceSnippetLineCount: int(object["sourceSnippetLineCount"]),
            sourceAncestorItems: sourceNodeItems(object["sourceAncestorItems"]),
            sourceSiblingItems: sourceNodeItems(object["sourceSiblingItems"]),
            sourceChildItems: sourceNodeItems(object["sourceChildItems"]),
            editSafetyLevel: string(object["editSafetyLevel"]),
            editSafetyTitle: string(object["editSafetyTitle"]),
            editSafetyDetail: string(object["editSafetyDetail"]),
            editSafetyOperations: stringArray(object["editSafetyOperations"]),
            editSafetyTargetId: string(object["editSafetyTargetId"]),
            editSafetyContainerId: string(object["editSafetyContainerId"]),
            editability: string(object["editability"]),
            fidelity: string(object["fidelity"]),
            captureNote: string(object["captureNote"]),
            layoutMode: string(object["layoutMode"]),
            imageSource: string(object["imageSource"]),
            imageAlt: string(object["imageAlt"]),
            frame: elementFrame(object["frame"]),
            x: x,
            y: y,
            w: w,
            h: h,
            rotation: rotation,
            z: z,
            locked: bool(object["locked"]),
            text: string(object["text"]),
            style: style(object["style"])
        )
    }

    static func sourceNodeItems(_ value: Any?) -> [EditorSourceNodeItem]? {
        guard let values = value as? [[String: Any]] else { return nil }
        let items = values.compactMap { object -> EditorSourceNodeItem? in
            guard let id = string(object["id"]),
                  let tagName = string(object["tagName"]),
                  let label = string(object["label"]),
                  let path = string(object["path"]) else {
                return nil
            }

            return EditorSourceNodeItem(
                id: id,
                tagName: tagName,
                label: label,
                path: path,
                canEditText: bool(object["canEditText"]),
                textPreview: string(object["textPreview"]),
                depth: int(object["depth"])
            )
        }

        return items.isEmpty ? nil : items
    }

    static func sourceDraftMappingSummary(_ value: Any?) -> SourceDraftMappingSummary? {
        guard let object = value as? [String: Any],
              let preservedCount = int(object["preservedCount"]),
              let addedCount = int(object["addedCount"]),
              let unmatchedCount = int(object["unmatchedCount"]),
              let values = object["items"] as? [[String: Any]] else {
            return nil
        }

        let items = values.compactMap { object -> SourceDraftMappingItem? in
            guard let slot = string(object["slot"]),
                  let kind = string(object["kind"]),
                  let nextTagName = string(object["nextTagName"]),
                  let nextLabel = string(object["nextLabel"]) else {
                return nil
            }

            return SourceDraftMappingItem(
                slot: slot,
                kind: kind,
                previousID: string(object["previousID"]),
                previousTagName: string(object["previousTagName"]),
                previousLabel: string(object["previousLabel"]),
                nextTagName: nextTagName,
                nextLabel: nextLabel,
                score: int(object["score"])
            )
        }

        return SourceDraftMappingSummary(
            preservedCount: preservedCount,
            addedCount: addedCount,
            unmatchedCount: unmatchedCount,
            structureRisk: bool(object["structureRisk"]),
            items: items
        )
    }

    static func elementFrame(_ value: Any?) -> EditorElementFrame? {
        guard let object = value as? [String: Any],
              let x = double(object["x"]),
              let y = double(object["y"]),
              let w = double(object["w"]),
              let h = double(object["h"]) else {
            return nil
        }

        return EditorElementFrame(
            label: string(object["label"]),
            x: x,
            y: y,
            w: w,
            h: h
        )
    }

    static func style(_ value: Any?) -> EditorElementStyle? {
        guard let object = value as? [String: Any] else { return nil }

        return EditorElementStyle(
            fontFamily: string(object["fontFamily"]),
            fontSize: double(object["fontSize"]),
            fontWeight: double(object["fontWeight"]),
            lineHeight: double(object["lineHeight"]),
            color: string(object["color"]),
            fill: string(object["fill"]),
            stroke: string(object["stroke"]),
            strokeWidth: double(object["strokeWidth"]),
            radius: double(object["radius"]),
            shadow: string(object["shadow"]),
            textAlign: string(object["textAlign"]),
            objectFit: string(object["objectFit"]),
            paddingTop: double(object["paddingTop"]),
            paddingRight: double(object["paddingRight"]),
            paddingBottom: double(object["paddingBottom"]),
            paddingLeft: double(object["paddingLeft"]),
            marginTop: double(object["marginTop"]),
            marginRight: double(object["marginRight"]),
            marginBottom: double(object["marginBottom"]),
            marginLeft: double(object["marginLeft"]),
            display: string(object["display"]),
            flexDirection: string(object["flexDirection"]),
            justifyContent: string(object["justifyContent"]),
            alignItems: string(object["alignItems"]),
            gap: double(object["gap"]),
            flexWrap: string(object["flexWrap"]),
            position: string(object["position"]),
            overflow: string(object["overflow"]),
            opacity: double(object["opacity"]),
            letterSpacing: double(object["letterSpacing"]),
            textDecoration: string(object["textDecoration"]),
            textTransform: string(object["textTransform"]),
            whiteSpace: string(object["whiteSpace"]),
            cursor: string(object["cursor"]),
            writebackKind: string(object["writebackKind"]),
            writebackLabel: string(object["writebackLabel"]),
            writebackTarget: string(object["writebackTarget"]),
            writebackDetail: string(object["writebackDetail"]),
            writebackSourceKind: string(object["writebackSourceKind"]),
            writebackSourceLabel: string(object["writebackSourceLabel"]),
            writebackSourceURL: string(object["writebackSourceURL"]),
            writebackRuleSnippet: string(object["writebackRuleSnippet"]),
            writebackRuleLine: int(object["writebackRuleLine"]),
            writebackMatchSummary: stylesheetRuleMatchSummary(object["writebackMatchSummary"])
        )
    }

    static func stylesheetRuleMatchSummary(_ value: Any?) -> StylesheetRuleMatchSummary? {
        guard let object = value as? [String: Any],
              let selector = string(object["selector"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              !selector.isEmpty else {
            return nil
        }
        let items = sourceNodeItems(object["items"]) ?? []
        return StylesheetRuleMatchSummary(
            selector: selector,
            count: int(object["count"]) ?? items.count,
            items: items
        )
    }

    static func string(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    static func stringArray(_ value: Any?) -> [String]? {
        guard let values = value as? [Any] else { return nil }
        let strings = values.compactMap { string($0)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return strings.isEmpty ? nil : strings
    }

    static func double(_ value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double.isFinite ? double : nil
        case let number as NSNumber:
            let double = number.doubleValue
            return double.isFinite ? double : nil
        case let string as String:
            let double = Double(string)
            return double?.isFinite == true ? double : nil
        default:
            return nil
        }
    }

    static func cgFloat(_ value: Any?) -> CGFloat? {
        guard let value = double(value) else { return nil }
        return CGFloat(value)
    }

    static func int(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    static func bool(_ value: Any?) -> Bool? {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            switch string.lowercased() {
            case "true", "1": return true
            case "false", "0": return false
            default: return nil
            }
        default:
            return nil
        }
    }
}
