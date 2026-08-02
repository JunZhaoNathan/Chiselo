import Foundation

struct HTMLDocumentSavePayload: Codable, Equatable, Sendable {
    var html: String
    var localStylesheets: [HTMLLocalStylesheetSavePayload]
}

struct HTMLLocalStylesheetSavePayload: Codable, Equatable, Sendable {
    var fileURL: String
    var href: String?
    var cssText: String
}

struct HTMLSavePersistenceResult {
    struct StylesheetWriteback: Equatable {
        var url: URL
        var snapshotURL: URL?
        var created: Bool
    }

    var htmlSnapshotURL: URL?
    var stylesheetWritebacks: [StylesheetWriteback]
}

typealias HTMLSaveCommitHandler = (_ temporaryURL: URL, _ destinationURL: URL, _ destinationExists: Bool) throws -> Void

func htmlDocumentSavePayloadHasChanges(
    _ payload: HTMLDocumentSavePayload,
    originalHTML: String,
    fileManager: FileManager = .default
) -> Bool {
    if payload.html != originalHTML {
        return true
    }

    for stylesheet in payload.localStylesheets {
        guard let url = URL(string: stylesheet.fileURL), url.isFileURL else { return true }
        let normalizedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        guard fileManager.fileExists(atPath: normalizedURL.path),
              let currentCSS = try? readLocalStylesheetText(at: normalizedURL),
              currentCSS == stylesheet.cssText else {
            return true
        }
    }
    return false
}

enum HTMLSavePersistenceError: LocalizedError {
    case invalidStylesheetFileURL(String)
    case stylesheetTargetMismatch(href: String, fileURL: String)
    case missingStylesheetDirectory(String)
    case transactionFailed(String, rollbackFailure: String?)

    var errorDescription: String? {
        switch self {
        case .invalidStylesheetFileURL(let value):
            return "无效的本地 CSS 文件路径：\(value)"
        case .stylesheetTargetMismatch(let href, let fileURL):
            return "CSS 写回目标与 HTML 链接不一致：\(href) → \(fileURL)"
        case .missingStylesheetDirectory(let path):
            return "CSS 所在目录不存在，已取消写回：\(path)"
        case .transactionFailed(let message, let rollbackFailure):
            if let rollbackFailure {
                return "保存失败：\(message)；自动回滚也失败：\(rollbackFailure)"
            }
            return "保存失败，已自动恢复原文件：\(message)"
        }
    }
}

private struct PreparedDocumentWrite {
    enum Kind {
        case html
        case stylesheet
    }

    var kind: Kind
    var url: URL
    var data: Data
    var originalData: Data?
    var temporaryURL: URL
    var snapshotURL: URL?
}

func persistHTMLDocumentSavePayload(
    _ payload: HTMLDocumentSavePayload,
    to htmlURL: URL,
    safeFileHistory: SafeFileHistory,
    fileManager: FileManager = .default,
    commitHandler: HTMLSaveCommitHandler? = nil
) throws -> HTMLSavePersistenceResult {
    let normalizedHTMLURL = htmlURL.standardizedFileURL.resolvingSymlinksInPath()
    let stylesheetPayloads = try normalizedLocalStylesheetPayloads(
        payload.localStylesheets,
        relativeTo: normalizedHTMLURL
    )
    let changedStylesheets = try changedLocalStylesheetPayloads(stylesheetPayloads, fileManager: fileManager)

    var writes = try changedStylesheets.map { stylesheet in
        let directory = stylesheet.url.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: directory.path) else {
            throw HTMLSavePersistenceError.missingStylesheetDirectory(directory.path)
        }
        return try preparedDocumentWrite(
            kind: .stylesheet,
            url: stylesheet.url,
            data: Data(stylesheet.cssText.utf8),
            fileManager: fileManager
        )
    }
    writes.append(try preparedDocumentWrite(
        kind: .html,
        url: normalizedHTMLURL,
        data: Data(payload.html.utf8),
        fileManager: fileManager
    ))

    do {
        for index in writes.indices {
            let write = writes[index]
            writes[index].snapshotURL = try safeFileHistory.protectFileBeforeOverwrite(
                at: write.url,
                fallbackExtension: write.kind == .html ? "html" : (write.url.pathExtension.isEmpty ? "css" : write.url.pathExtension)
            )
        }
    } catch {
        removePreparedTemporaryFiles(writes, fileManager: fileManager)
        throw error
    }

    var committedIndices: [Int] = []
    do {
        for index in writes.indices {
            if let commitHandler {
                try commitHandler(
                    writes[index].temporaryURL,
                    writes[index].url,
                    writes[index].originalData != nil
                )
            } else {
                try commitPreparedDocumentWrite(writes[index], fileManager: fileManager)
            }
            committedIndices.append(index)
        }
    } catch {
        let rollbackFailure = rollbackPreparedDocumentWrites(
            committedIndices.reversed().map { writes[$0] },
            fileManager: fileManager
        )
        removePreparedTemporaryFiles(writes, fileManager: fileManager)
        throw HTMLSavePersistenceError.transactionFailed(
            error.localizedDescription,
            rollbackFailure: rollbackFailure?.localizedDescription
        )
    }

    removePreparedTemporaryFiles(writes, fileManager: fileManager)
    let htmlWrite = writes.first(where: { $0.kind == .html })
    let stylesheetWritebacks = writes.filter { $0.kind == .stylesheet }.map { write in
        HTMLSavePersistenceResult.StylesheetWriteback(
            url: write.url,
            snapshotURL: write.snapshotURL,
            created: write.originalData == nil
        )
    }
    return HTMLSavePersistenceResult(
        htmlSnapshotURL: htmlWrite?.snapshotURL,
        stylesheetWritebacks: stylesheetWritebacks
    )
}

private func preparedDocumentWrite(
    kind: PreparedDocumentWrite.Kind,
    url: URL,
    data: Data,
    fileManager: FileManager
) throws -> PreparedDocumentWrite {
    let originalData = fileManager.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
    let temporaryURL = url.deletingLastPathComponent()
        .appendingPathComponent(".chiselo-write-\(UUID().uuidString)")
    try data.write(to: temporaryURL, options: [.atomic])
    return PreparedDocumentWrite(
        kind: kind,
        url: url,
        data: data,
        originalData: originalData,
        temporaryURL: temporaryURL,
        snapshotURL: nil
    )
}

private func commitPreparedDocumentWrite(_ write: PreparedDocumentWrite, fileManager: FileManager) throws {
    if fileManager.fileExists(atPath: write.url.path) {
        _ = try fileManager.replaceItemAt(write.url, withItemAt: write.temporaryURL)
    } else {
        try fileManager.moveItem(at: write.temporaryURL, to: write.url)
    }
}

private func rollbackPreparedDocumentWrites(
    _ writes: [PreparedDocumentWrite],
    fileManager: FileManager
) -> Error? {
    var firstError: Error?
    for write in writes {
        do {
            if let originalData = write.originalData {
                try originalData.write(to: write.url, options: [.atomic])
            } else if fileManager.fileExists(atPath: write.url.path) {
                try fileManager.removeItem(at: write.url)
            }
        } catch {
            firstError = firstError ?? error
        }
    }
    return firstError
}

private func removePreparedTemporaryFiles(_ writes: [PreparedDocumentWrite], fileManager: FileManager) {
    for write in writes where fileManager.fileExists(atPath: write.temporaryURL.path) {
        try? fileManager.removeItem(at: write.temporaryURL)
    }
}

func injectLocalStylesheetMirrors(
    into html: String,
    relativeTo htmlURL: URL?,
    stylesheetOverrides: [HTMLLocalStylesheetSavePayload] = []
) -> String {
    guard let htmlURL, htmlURL.isFileURL else { return html }
    let baseDirectory = htmlURL.deletingLastPathComponent()
    let overridesByPath = stylesheetOverrides.reduce(into: [String: String]()) { result, payload in
        guard let url = URL(string: payload.fileURL), url.isFileURL else { return }
        result[url.standardizedFileURL.resolvingSymlinksInPath().path] = payload.cssText
    }
    let matches = linkedStylesheetTagMatches(in: html)
    guard !matches.isEmpty else { return html }

    var output = html
    for match in matches.reversed() {
        let tag = String(output[match])
        guard let href = htmlAttributeValue(named: "href", in: tag),
              let rel = htmlAttributeValue(named: "rel", in: tag),
              relContainsStylesheet(rel),
              let stylesheetURL = URL(string: href, relativeTo: baseDirectory)?.absoluteURL,
              stylesheetURL.isFileURL else {
            continue
        }
        let normalizedPath = stylesheetURL.standardizedFileURL.resolvingSymlinksInPath().path
        guard let css = overridesByPath[normalizedPath] ?? (try? readLocalStylesheetText(at: stylesheetURL)) else { continue }

        let escapedHref = htmlAttributeEscaped(href)
        let escapedFileURL = htmlAttributeEscaped(stylesheetURL.absoluteString)
        let safeCSS = css.replacingOccurrences(
            of: "</style",
            with: "<\\/style",
            options: String.CompareOptions.caseInsensitive
        )
        let mirror = """

        <style data-chiselo-linked-stylesheet="\(escapedHref)" data-chiselo-linked-stylesheet-file="\(escapedFileURL)">
        \(safeCSS)
        </style>
        """
        output.replaceSubrange(match, with: "\(tag)\(mirror)")
    }
    return output
}

private struct NormalizedLocalStylesheetPayload: Equatable {
    var url: URL
    var cssText: String
}

private func normalizedLocalStylesheetPayloads(
    _ payloads: [HTMLLocalStylesheetSavePayload],
    relativeTo htmlURL: URL
) throws -> [NormalizedLocalStylesheetPayload] {
    var deduplicated: [String: NormalizedLocalStylesheetPayload] = [:]
    let baseDirectory = htmlURL.deletingLastPathComponent()
    for payload in payloads {
        guard let url = URL(string: payload.fileURL), url.isFileURL else {
            throw HTMLSavePersistenceError.invalidStylesheetFileURL(payload.fileURL)
        }
        let normalizedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        guard let href = payload.href?.trimmingCharacters(in: .whitespacesAndNewlines),
              !href.isEmpty,
              let linkedURL = URL(string: href, relativeTo: baseDirectory)?.absoluteURL,
              linkedURL.isFileURL,
              linkedURL.standardizedFileURL.resolvingSymlinksInPath().path == normalizedURL.path else {
            throw HTMLSavePersistenceError.stylesheetTargetMismatch(
                href: payload.href ?? "",
                fileURL: payload.fileURL
            )
        }
        deduplicated[normalizedURL.path] = NormalizedLocalStylesheetPayload(
            url: normalizedURL,
            cssText: payload.cssText
        )
    }
    return deduplicated.values.sorted { $0.url.path < $1.url.path }
}

private func changedLocalStylesheetPayloads(
    _ payloads: [NormalizedLocalStylesheetPayload],
    fileManager: FileManager
) throws -> [NormalizedLocalStylesheetPayload] {
    try payloads.filter { payload in
        if !fileManager.fileExists(atPath: payload.url.path) {
            return !payload.cssText.isEmpty
        }
        let current = try readLocalStylesheetText(at: payload.url)
        return current != payload.cssText
    }
}

private func linkedStylesheetTagMatches(in html: String) -> [Range<String.Index>] {
    let pattern = #"<link\b[^>]*>"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
        return []
    }
    let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
    return regex.matches(in: html, options: [], range: nsRange).compactMap { Range($0.range, in: html) }
}

private func htmlAttributeValue(named name: String, in tag: String) -> String? {
    let pattern = #"\b\#(name)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
        return nil
    }
    let nsRange = NSRange(tag.startIndex..<tag.endIndex, in: tag)
    guard let match = regex.firstMatch(in: tag, options: [], range: nsRange) else {
        return nil
    }
    for group in 1..<match.numberOfRanges {
        let range = match.range(at: group)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: tag) else { continue }
        return String(tag[swiftRange])
    }
    return nil
}

private func relContainsStylesheet(_ rel: String) -> Bool {
    rel
        .split(whereSeparator: \.isWhitespace)
        .map { $0.lowercased() }
        .contains("stylesheet")
}

private func htmlAttributeEscaped(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

private func readLocalStylesheetText(at url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    let encodings: [String.Encoding] = [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .isoLatin1, .ascii]
    for encoding in encodings {
        if let string = String(data: data, encoding: encoding) {
            return string
        }
    }
    throw CocoaError(.fileReadCorruptFile)
}
