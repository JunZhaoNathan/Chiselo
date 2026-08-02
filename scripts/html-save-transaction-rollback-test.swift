import Foundation

private enum TestFailure: Error, LocalizedError {
    case expectedTransactionFailure
    case injectedCommitFailure
    case assertion(String)

    var errorDescription: String? {
        switch self {
        case .expectedTransactionFailure:
            return "The save unexpectedly succeeded."
        case .injectedCommitFailure:
            return "Injected HTML commit failure."
        case .assertion(let message):
            return message
        }
    }
}

private func commit(_ temporaryURL: URL, to destinationURL: URL, destinationExists: Bool) throws {
    if destinationExists {
        _ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: temporaryURL)
    } else {
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
    }
}

@main
private enum HTMLSaveTransactionRollbackTest {
static func main() {
do {
    let fileManager = FileManager.default
    let directory = fileManager.temporaryDirectory
        .appendingPathComponent("chiselo-save-rollback-\(UUID().uuidString)", isDirectory: true)
    let stylesDirectory = directory.appendingPathComponent("styles", isDirectory: true)
    try fileManager.createDirectory(at: stylesDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: directory) }

    let htmlURL = directory.appendingPathComponent("index.html")
    let cssURL = stylesDirectory.appendingPathComponent("site.css")
    let originalHTML = Data("<!doctype html>\n<link rel=\"stylesheet\" href=\"styles/site.css\">\n<h1>Before</h1>\n".utf8)
    let originalCSS = Data(".title { color: #123456; }\n".utf8)
    try originalHTML.write(to: htmlURL)
    try originalCSS.write(to: cssURL)

    let unchangedPayload = HTMLDocumentSavePayload(
        html: String(decoding: originalHTML, as: UTF8.self),
        localStylesheets: [
            HTMLLocalStylesheetSavePayload(
                fileURL: cssURL.absoluteString,
                href: "styles/site.css",
                cssText: String(decoding: originalCSS, as: UTF8.self)
            )
        ]
    )
    guard !htmlDocumentSavePayloadHasChanges(
        unchangedPayload,
        originalHTML: String(decoding: originalHTML, as: UTF8.self)
    ) else {
        throw TestFailure.assertion("An unchanged HTML/CSS payload was marked as modified.")
    }

    let payload = HTMLDocumentSavePayload(
        html: "<!doctype html>\n<link rel=\"stylesheet\" href=\"styles/site.css\">\n<h1>After</h1>\n",
        localStylesheets: [
            HTMLLocalStylesheetSavePayload(
                fileURL: cssURL.absoluteString,
                href: "styles/site.css",
                cssText: ".title { color: #abcdef; }\n"
            )
        ]
    )
    guard htmlDocumentSavePayloadHasChanges(payload, originalHTML: String(decoding: originalHTML, as: UTF8.self)) else {
        throw TestFailure.assertion("Changed HTML/CSS payload was not marked as modified.")
    }

    var committedDestinations: [URL] = []
    do {
        _ = try persistHTMLDocumentSavePayload(
            payload,
            to: htmlURL,
            safeFileHistory: SafeFileHistory(),
            commitHandler: { temporaryURL, destinationURL, destinationExists in
                if destinationURL.standardizedFileURL == htmlURL.standardizedFileURL {
                    throw TestFailure.injectedCommitFailure
                }
                try commit(temporaryURL, to: destinationURL, destinationExists: destinationExists)
                committedDestinations.append(destinationURL)
            }
        )
        throw TestFailure.expectedTransactionFailure
    } catch let error as HTMLSavePersistenceError {
        guard case .transactionFailed(_, let rollbackFailure) = error, rollbackFailure == nil else {
            throw TestFailure.assertion("Expected a successful rollback, got: \(error.localizedDescription)")
        }
    }

    guard committedDestinations.map(\.standardizedFileURL).contains(cssURL.standardizedFileURL) else {
        throw TestFailure.assertion("The injected failure did not occur after the CSS commit.")
    }
    guard try Data(contentsOf: htmlURL) == originalHTML else {
        throw TestFailure.assertion("HTML bytes changed despite transaction rollback.")
    }
    guard try Data(contentsOf: cssURL) == originalCSS else {
        throw TestFailure.assertion("CSS bytes were not restored after transaction rollback.")
    }

    let temporaryWrites = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        + fileManager.contentsOfDirectory(at: stylesDirectory, includingPropertiesForKeys: nil)
    guard !temporaryWrites.contains(where: { $0.lastPathComponent.hasPrefix(".chiselo-write-") }) else {
        throw TestFailure.assertion("A staged .chiselo-write-* file was left behind.")
    }

    let htmlHistoryDirectory = directory.appendingPathComponent(".chiselo-history", isDirectory: true)
    let cssHistoryDirectory = stylesDirectory.appendingPathComponent(".chiselo-history", isDirectory: true)
    let htmlSnapshots = try fileManager.contentsOfDirectory(at: htmlHistoryDirectory, includingPropertiesForKeys: nil)
    let cssSnapshots = try fileManager.contentsOfDirectory(at: cssHistoryDirectory, includingPropertiesForKeys: nil)
    guard htmlSnapshots.contains(where: { $0.lastPathComponent.hasPrefix("index-") }),
          cssSnapshots.contains(where: { $0.lastPathComponent.hasPrefix("site-") }) else {
        throw TestFailure.assertion("Expected HTML and CSS history snapshots before commit.")
    }

    print("HTML save transaction rollback test passed")
} catch {
    fputs("HTML save transaction rollback test failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
}
}
