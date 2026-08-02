import Foundation
import WebKit
import XCTest
@testable import Chiselo

final class HTMLRuntimeSecurityPolicyTests: XCTestCase {
    func testRemoteResourceRulesAreValidAndCoverAllPageResourceTypes() throws {
        let data = Data(HTMLRuntimeSecurityPolicy.remoteResourceBlockingRules.utf8)
        let rules = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let trigger = try XCTUnwrap(rules.first?["trigger"] as? [String: Any])
        let types = Set(try XCTUnwrap(trigger["resource-type"] as? [String]))

        XCTAssertEqual(trigger["url-filter"] as? String, "^https?://")
        XCTAssertTrue(Set(["document", "image", "style-sheet", "script", "font", "media", "svg-document", "raw"]).isSubset(of: types))
        XCTAssertEqual((rules.first?["action"] as? [String: String])?["type"], "block")
    }

    func testRemoteResourceRulesCompileInWebKit() {
        let compiled = expectation(description: "WebKit content rules compile")
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "ChiseloTests.IsolatedHTML.\(UUID().uuidString)",
            encodedContentRuleList: HTMLRuntimeSecurityPolicy.remoteResourceBlockingRules
        ) { ruleList, error in
            XCTAssertNil(error)
            XCTAssertNotNil(ruleList)
            compiled.fulfill()
        }
        wait(for: [compiled], timeout: 5)
    }

    func testIsolatedModeBlocksRemoteSubframeNavigation() {
        let editorURL = URL(fileURLWithPath: "/Applications/Chiselo.app/editor/index.html")

        XCTAssertFalse(HTMLRuntimeSecurityPolicy.allowsNavigation(
            to: URL(string: "https://example.com/embed"),
            isMainFrame: false,
            mode: .isolated,
            editorURL: editorURL
        ))
        XCTAssertTrue(HTMLRuntimeSecurityPolicy.allowsNavigation(
            to: URL(string: "https://example.com/embed"),
            isMainFrame: false,
            mode: .trusted,
            editorURL: editorURL
        ))
        XCTAssertTrue(HTMLRuntimeSecurityPolicy.allowsNavigation(
            to: URL(string: "data:text/html,preview"),
            isMainFrame: false,
            mode: .isolated,
            editorURL: editorURL
        ))
    }

    func testEditorShellCannotBeReplacedByPageNavigation() {
        let editorURL = URL(fileURLWithPath: "/Applications/Chiselo.app/editor/index.html")

        XCTAssertTrue(HTMLRuntimeSecurityPolicy.allowsNavigation(
            to: editorURL,
            isMainFrame: true,
            mode: .trusted,
            editorURL: editorURL
        ))
        XCTAssertFalse(HTMLRuntimeSecurityPolicy.allowsNavigation(
            to: URL(string: "https://example.com"),
            isMainFrame: true,
            mode: .trusted,
            editorURL: editorURL
        ))
        XCTAssertFalse(HTMLRuntimeSecurityPolicy.allowsNavigation(
            to: URL(fileURLWithPath: "/tmp/other.html"),
            isMainFrame: true,
            mode: .isolated,
            editorURL: editorURL
        ))
    }
}
