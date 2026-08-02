import Foundation
import XCTest
@testable import Chiselo

final class HTMLSaveCoordinatorTests: XCTestCase {
    func testUnchangedHTMLAndStylesheetPayloadIsNotMarkedModified() throws {
        try withFixture { fixture in
            let payload = HTMLDocumentSavePayload(
                html: fixture.originalHTML,
                localStylesheets: [
                    HTMLLocalStylesheetSavePayload(
                        fileURL: fixture.cssURL.absoluteString,
                        href: "styles/site.css",
                        cssText: fixture.originalCSS
                    )
                ]
            )

            XCTAssertFalse(
                htmlDocumentSavePayloadHasChanges(payload, originalHTML: fixture.originalHTML)
            )
        }
    }

    func testFailedHTMLCommitRollsBackPreviouslyWrittenStylesheet() throws {
        try withFixture { fixture in
            let payload = HTMLDocumentSavePayload(
                html: fixture.originalHTML.replacingOccurrences(of: "Before", with: "After"),
                localStylesheets: [
                    HTMLLocalStylesheetSavePayload(
                        fileURL: fixture.cssURL.absoluteString,
                        href: "styles/site.css",
                        cssText: ".title { color: #abcdef; }\n"
                    )
                ]
            )

            XCTAssertThrowsError(
                try persistHTMLDocumentSavePayload(
                    payload,
                    to: fixture.htmlURL,
                    safeFileHistory: SafeFileHistory(),
                    commitHandler: { temporaryURL, destinationURL, destinationExists in
                        if destinationURL.standardizedFileURL == fixture.htmlURL.standardizedFileURL {
                            throw InjectedFailure.htmlCommit
                        }
                        try Self.commit(
                            temporaryURL,
                            to: destinationURL,
                            destinationExists: destinationExists
                        )
                    }
                )
            ) { error in
                guard case HTMLSavePersistenceError.transactionFailed(_, let rollbackFailure) = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
                XCTAssertNil(rollbackFailure)
            }

            XCTAssertEqual(try String(contentsOf: fixture.htmlURL, encoding: .utf8), fixture.originalHTML)
            XCTAssertEqual(try String(contentsOf: fixture.cssURL, encoding: .utf8), fixture.originalCSS)
        }
    }

    func testStylesheetOutsideHTMLReferenceIsRejectedBeforeWrite() throws {
        try withFixture { fixture in
            let otherCSSURL = fixture.directory.appendingPathComponent("other.css")
            try ".other {}\n".write(to: otherCSSURL, atomically: true, encoding: .utf8)
            let payload = HTMLDocumentSavePayload(
                html: fixture.originalHTML,
                localStylesheets: [
                    HTMLLocalStylesheetSavePayload(
                        fileURL: otherCSSURL.absoluteString,
                        href: "styles/site.css",
                        cssText: ".other { color: red; }\n"
                    )
                ]
            )

            XCTAssertThrowsError(
                try persistHTMLDocumentSavePayload(
                    payload,
                    to: fixture.htmlURL,
                    safeFileHistory: SafeFileHistory()
                )
            )
            XCTAssertEqual(try String(contentsOf: fixture.htmlURL, encoding: .utf8), fixture.originalHTML)
            XCTAssertEqual(try String(contentsOf: otherCSSURL, encoding: .utf8), ".other {}\n")
        }
    }

    private enum InjectedFailure: Error {
        case htmlCommit
    }

    private struct Fixture {
        let directory: URL
        let htmlURL: URL
        let cssURL: URL
        let originalHTML: String
        let originalCSS: String
    }

    private func withFixture(_ body: (Fixture) throws -> Void) throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("chiselo-xctest-\(UUID().uuidString)", isDirectory: true)
        let stylesDirectory = directory.appendingPathComponent("styles", isDirectory: true)
        try fileManager.createDirectory(at: stylesDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let htmlURL = directory.appendingPathComponent("index.html")
        let cssURL = stylesDirectory.appendingPathComponent("site.css")
        let originalHTML = "<!doctype html>\n<link rel=\"stylesheet\" href=\"styles/site.css\">\n<h1>Before</h1>\n"
        let originalCSS = ".title { color: #123456; }\n"
        try originalHTML.write(to: htmlURL, atomically: true, encoding: .utf8)
        try originalCSS.write(to: cssURL, atomically: true, encoding: .utf8)

        try body(Fixture(
            directory: directory,
            htmlURL: htmlURL,
            cssURL: cssURL,
            originalHTML: originalHTML,
            originalCSS: originalCSS
        ))
    }

    private static func commit(
        _ temporaryURL: URL,
        to destinationURL: URL,
        destinationExists: Bool
    ) throws {
        if destinationExists {
            _ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        }
    }
}
