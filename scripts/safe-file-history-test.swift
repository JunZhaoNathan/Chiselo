import Foundation

private struct TestFailure: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

@main
struct SafeFileHistoryTest {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chiselo-safe-file-history-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)
        let history = SafeFileHistory(now: { fixedDate })
        let htmlURL = root.appendingPathComponent("landing.html")
        try "original html".write(to: htmlURL, atomically: true, encoding: .utf8)

        try history.backupOriginalIfNeeded(at: htmlURL, fallbackExtension: "html")
        let backupURL = root.appendingPathComponent("landing.chiselo-backup.html")
        try expect(FileManager.default.fileExists(atPath: backupURL.path), "Expected sibling backup to be created.")

        try "edited html".write(to: htmlURL, atomically: true, encoding: .utf8)
        try history.backupOriginalIfNeeded(at: htmlURL, fallbackExtension: "html")
        let backupContent = try String(contentsOf: backupURL, encoding: .utf8)
        try expect(backupContent == "original html", "Existing sibling backup should not be overwritten.")

        let firstSnapshot = try history.protectFileBeforeOverwrite(at: htmlURL, fallbackExtension: "html")
        try expect(firstSnapshot != nil, "Expected first save snapshot.")

        try "newer html".write(to: htmlURL, atomically: true, encoding: .utf8)
        let secondSnapshot = try history.protectFileBeforeOverwrite(at: htmlURL, fallbackExtension: "html")
        try expect(secondSnapshot != nil, "Expected second save snapshot.")
        try expect(
            secondSnapshot?.lastPathComponent.contains("-2.html") == true,
            "Expected same-second snapshot to receive a numeric suffix."
        )

        let latestSnapshot = try history.latestVersionSnapshot(for: htmlURL)
        try expect(
            canonicalPath(latestSnapshot) == canonicalPath(secondSnapshot),
            "Expected latest snapshot lookup to prefer the highest same-second suffix."
        )
        let latestContent = try latestSnapshot.map { try String(contentsOf: $0, encoding: .utf8) }
        try expect(latestContent == "newer html", "Expected latest snapshot to contain the newest pre-save content.")

        print("Safe file history test OK")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw TestFailure(message: message)
        }
    }

    private static func canonicalPath(_ url: URL?) -> String? {
        url?.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
