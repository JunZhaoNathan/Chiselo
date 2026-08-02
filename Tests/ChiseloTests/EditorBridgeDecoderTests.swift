import CoreGraphics
import Foundation
import XCTest
@testable import Chiselo

final class EditorBridgeDecoderTests: XCTestCase {
    func testCompleteSelectionPayloadPreservesGeometryMetadataAndInspectorStyle() throws {
        let sourceItem: [String: Any] = [
            "id": "source-1",
            "tagName": "span",
            "label": "Price",
            "path": "main > span",
            "canEditText": "true",
            "textPreview": "$42",
            "depth": "2"
        ]
        let style: [String: Any] = [
            "fontFamily": "Inter",
            "fontSize": "18.5",
            "fontWeight": 650,
            "lineHeight": 1.4,
            "color": "rgb(17, 24, 39)",
            "fill": "rgb(255, 255, 255)",
            "stroke": "rgb(203, 213, 225)",
            "strokeWidth": 1,
            "radius": 8,
            "shadow": "none",
            "textAlign": "left",
            "objectFit": "cover",
            "paddingTop": 10,
            "paddingRight": 12,
            "paddingBottom": 14,
            "paddingLeft": 16,
            "marginTop": 1,
            "marginRight": 2,
            "marginBottom": 3,
            "marginLeft": 4,
            "display": "flex",
            "flexDirection": "column",
            "justifyContent": "space-between",
            "alignItems": "center",
            "gap": 6,
            "flexWrap": "wrap",
            "position": "relative",
            "overflow": "hidden",
            "opacity": 0.75,
            "letterSpacing": 0.25,
            "textDecoration": "underline",
            "textTransform": "uppercase",
            "whiteSpace": "nowrap",
            "cursor": "pointer",
            "writebackKind": "stylesheet-rule",
            "writebackLabel": ".price",
            "writebackTarget": ".price",
            "writebackDetail": "styles/site.css",
            "writebackSourceKind": "local-stylesheet",
            "writebackSourceLabel": "site.css",
            "writebackSourceURL": "file:///tmp/site.css",
            "writebackRuleSnippet": ".price { color: red; }",
            "writebackRuleLine": "17",
            "writebackMatchSummary": [
                "selector": "  .price  ",
                "items": [sourceItem]
            ]
        ]
        let element: [String: Any] = [
            "id": "node-42",
            "type": "html",
            "tagName": "section",
            "htmlPath": "main > section:nth-child(2)",
            "className": "price-card",
            "inlineStyle": "color: red",
            "linkHref": "/details",
            "linkTarget": "_blank",
            "semanticRole": "region",
            "semanticLabel": "Pricing",
            "groupId": "group-1",
            "groupRole": "card",
            "groupLabel": "Plan",
            "sourceKind": "html-source",
            "sourceSnippet": "<section>...</section>",
            "sourceSnippetLineCount": "3",
            "sourceAncestorItems": [sourceItem],
            "sourceSiblingItems": [sourceItem],
            "sourceChildItems": [sourceItem],
            "editSafetyLevel": "safe",
            "editSafetyTitle": "Local edit",
            "editSafetyDetail": "One source node",
            "editSafetyOperations": [" text ", "", 42],
            "editSafetyTargetId": "node-42",
            "editSafetyContainerId": "group-1",
            "editability": "native",
            "fidelity": "exact",
            "captureNote": "source preserved",
            "layoutMode": "flow",
            "imageSource": "/hero.png",
            "imageAlt": "Hero",
            "frame": ["label": "Card", "x": "11.5", "y": 22, "w": 320, "h": 180],
            "x": "12.5",
            "y": 24,
            "w": 320,
            "h": 180,
            "rotation": "0",
            "z": 4,
            "locked": "false",
            "text": "Starter",
            "style": style
        ]

        let message = EditorBridgeDecoder.selectionMessage(from: [
            "type": "selectionChanged",
            "slideIndex": "2",
            "path": "main > section:nth-child(2)",
            "element": element
        ])
        let decoded = try XCTUnwrap(message.element)
        let decodedStyle = try XCTUnwrap(decoded.style)

        XCTAssertEqual(message.type, "selectionChanged")
        XCTAssertEqual(message.slideIndex, 2)
        XCTAssertEqual(decoded.id, "node-42")
        XCTAssertEqual(decoded.frame, EditorElementFrame(label: "Card", x: 11.5, y: 22, w: 320, h: 180))
        XCTAssertEqual(decoded.editSafetyOperations, ["text", "42"])
        XCTAssertEqual(decoded.sourceChildItems?.first?.depth, 2)
        XCTAssertEqual(decoded.locked, false)
        XCTAssertEqual(decoded.x, 12.5)
        XCTAssertEqual(decodedStyle.paddingTop, 10)
        XCTAssertEqual(decodedStyle.marginLeft, 4)
        XCTAssertEqual(decodedStyle.display, "flex")
        XCTAssertEqual(decodedStyle.flexDirection, "column")
        XCTAssertEqual(decodedStyle.gap, 6)
        XCTAssertEqual(decodedStyle.position, "relative")
        XCTAssertEqual(decodedStyle.opacity, 0.75)
        XCTAssertEqual(decodedStyle.letterSpacing, 0.25)
        XCTAssertEqual(decodedStyle.cursor, "pointer")
        XCTAssertEqual(decodedStyle.writebackRuleLine, 17)
        XCTAssertEqual(decodedStyle.writebackMatchSummary?.selector, ".price")
        XCTAssertEqual(decodedStyle.writebackMatchSummary?.count, 1)
    }

    func testMalformedElementAndNonFiniteGeometryAreRejected() {
        let validGeometry: [String: Any] = [
            "id": "node-1", "type": "html", "x": 0, "y": 0,
            "w": 100, "h": 40, "rotation": 0, "z": 1
        ]
        var missingRequiredField = validGeometry
        missingRequiredField.removeValue(forKey: "rotation")
        var nonFiniteGeometry = validGeometry
        nonFiniteGeometry["x"] = Double.infinity
        var invalidNumericString = validGeometry
        invalidNumericString["w"] = "wide"

        XCTAssertNil(EditorBridgeDecoder.element(missingRequiredField))
        XCTAssertNil(EditorBridgeDecoder.element(nonFiniteGeometry))
        XCTAssertNil(EditorBridgeDecoder.element(invalidNumericString))
        XCTAssertNil(EditorBridgeDecoder.double(Double.nan))
        XCTAssertNil(EditorBridgeDecoder.cgFloat("infinity"))
    }

    func testMalformedNestedItemsAreDroppedWithoutRejectingValidSiblings() throws {
        let items = EditorBridgeDecoder.sourceNodeItems([
            ["id": "bad", "tagName": "div", "label": "Missing path"],
            ["id": "good", "tagName": "p", "label": "Body", "path": "main > p", "canEditText": 1]
        ])

        XCTAssertEqual(items?.map(\.id), ["good"])
        XCTAssertEqual(items?.first?.canEditText, true)
        XCTAssertNil(EditorBridgeDecoder.sourceNodeItems([
            ["id": "bad", "tagName": "div", "label": "Missing path"]
        ]))
        XCTAssertNil(EditorBridgeDecoder.stylesheetRuleMatchSummary(["selector": "  "]))

        let mapping = try XCTUnwrap(EditorBridgeDecoder.sourceDraftMappingSummary([
            "preservedCount": "1",
            "addedCount": 0,
            "unmatchedCount": 0,
            "structureRisk": "false",
            "items": [
                ["slot": "0", "kind": "preserved", "nextTagName": "p", "nextLabel": "Body", "score": "98"],
                ["slot": "1", "kind": "invalid"]
            ]
        ]))
        XCTAssertEqual(mapping.items.count, 1)
        XCTAssertEqual(mapping.items.first?.score, 98)
        XCTAssertFalse(mapping.hasStructureRisk)
        XCTAssertNil(EditorBridgeDecoder.sourceDraftMappingSummary([
            "preservedCount": 1, "addedCount": 0, "unmatchedCount": 0
        ]))
    }
}
