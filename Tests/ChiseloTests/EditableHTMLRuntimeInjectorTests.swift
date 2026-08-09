import XCTest
@testable import Chiselo

final class EditableHTMLRuntimeInjectorTests: XCTestCase {
    func testReplacingRuntimeRemovesOlderInjectedBlocks() {
        let html = """
        <!doctype html>
        <html><body><main>Keep me</main>
        <style data-chiselo-lite-runtime>.old { color: red; }</style>
        <script defer data-chiselo-lite-runtime>window.oldRuntime = true;</script>
        </body></html>
        """

        let output = replacingSelfEditableHTMLRuntime(in: html, with: Self.runtime)

        XCTAssertTrue(output.contains("<main>Keep me</main>"))
        XCTAssertFalse(output.contains(".old { color: red; }"))
        XCTAssertFalse(output.contains("window.oldRuntime"))
        XCTAssertEqual(output.components(separatedBy: "data-chiselo-lite-runtime").count - 1, 2)
    }

    func testReplacingRuntimeIsIdempotent() {
        let first = replacingSelfEditableHTMLRuntime(
            in: "<!doctype html><html><body><p>Text</p></body></html>",
            with: Self.runtime
        )
        let second = replacingSelfEditableHTMLRuntime(in: first, with: Self.runtime)

        XCTAssertEqual(second, first)
    }

    private static let runtime = """
    <style data-chiselo-lite-runtime>.new { color: blue; }</style>
    <script data-chiselo-lite-runtime>window.newRuntime = true;</script>
    """
}
