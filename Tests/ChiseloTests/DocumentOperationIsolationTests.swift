import WebKit
import XCTest
@testable import Chiselo

@MainActor
final class DocumentOperationIsolationTests: XCTestCase {
    func testTabSwitchIsBlockedUntilHTMLExportCaptureFinishes() async {
        let model = EditorModel()
        let webView = SuspendedJavaScriptWebView()
        model.attachWebView(webView)

        let first = EditorModel.EditorTab(
            id: UUID(),
            title: "first.html",
            url: URL(fileURLWithPath: "/tmp/first.html"),
            mode: "html",
            content: "<h1>First</h1>",
            needsSnapshot: false
        )
        let second = EditorModel.EditorTab(
            id: UUID(),
            title: "second.html",
            url: URL(fileURLWithPath: "/tmp/second.html"),
            mode: "html",
            content: "<h1>Second</h1>",
            needsSnapshot: false
        )
        model.tabs = [first, second]
        model.activeTabID = first.id

        model.exportHTML()
        XCTAssertTrue(model.isDocumentOperationInProgress)

        model.activateTab(second.id)
        XCTAssertEqual(model.activeTabID, first.id)

        webView.completeJavaScript(error: InjectedFailure.capture)
        await Task.yield()
        await Task.yield()

        XCTAssertFalse(model.isDocumentOperationInProgress)
        model.activateTab(second.id)
        XCTAssertEqual(model.activeTabID, second.id)
    }

    func testEditableConversionFailurePreservesSourceTabState() async {
        let model = EditorModel()
        let webView = SuspendedJavaScriptWebView()
        model.attachWebView(webView)

        let source = EditorModel.EditorTab(
            id: UUID(),
            title: "edited.html",
            url: URL(fileURLWithPath: "/tmp/edited.html"),
            mode: "html",
            content: "<h1>Unsaved source</h1>",
            originalContent: "<h1>Original source</h1>",
            needsSnapshot: false,
            hasUnsavedChanges: true
        )
        model.tabs = [source]
        model.activeTabID = source.id
        model.documentMode = "html"

        model.freezeCurrentHTMLLayout()
        XCTAssertTrue(model.isDocumentOperationInProgress)

        webView.completeJavaScript(result: "<h1>Exported snapshot</h1>")
        await Task.yield()
        await Task.yield()
        webView.completeJavaScript(error: InjectedFailure.conversion)
        await Task.yield()
        await Task.yield()

        XCTAssertFalse(model.isDocumentOperationInProgress)
        XCTAssertEqual(model.tabs.count, 1)
        XCTAssertEqual(model.tabs[0].content, source.content)
        XCTAssertEqual(model.tabs[0].originalContent, source.originalContent)
        XCTAssertTrue(model.tabs[0].hasUnsavedChanges)
    }

    private enum InjectedFailure: Error {
        case capture
        case conversion
    }
}

@MainActor
private final class SuspendedJavaScriptWebView: WKWebView {
    private var pendingCompletion: ((Any?, Error?) -> Void)?

    override func evaluateJavaScript(
        _ javaScriptString: String,
        completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)? = nil
    ) {
        pendingCompletion = completionHandler
    }

    func completeJavaScript(result: Any? = nil, error: Error? = nil) {
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(result, error)
    }
}
