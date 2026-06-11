import Foundation

final class SafeFileHistory {
    private struct SnapshotRank {
        let timestamp: String
        let suffix: Int
    }

    private var backedUpOriginalPaths: Set<String> = []
    private let fileManager: FileManager
    private let now: () -> Date

    init(fileManager: FileManager = .default, now: @escaping () -> Date = Date.init) {
        self.fileManager = fileManager
        self.now = now
    }

    func protectFileBeforeOverwrite(at url: URL, fallbackExtension: String) throws -> URL? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        try backupOriginalIfNeeded(at: url, fallbackExtension: fallbackExtension)
        return try createVersionSnapshot(at: url, fallbackExtension: fallbackExtension)
    }

    func backupOriginalIfNeeded(at url: URL, fallbackExtension: String) throws {
        let key = normalizedFilePath(for: url) ?? url.path
        guard fileManager.fileExists(atPath: url.path), !backedUpOriginalPaths.contains(key) else { return }

        let backupURL = backupURL(for: url, fallbackExtension: fallbackExtension)
        if !fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.copyItem(at: url, to: backupURL)
        }

        backedUpOriginalPaths.insert(key)
    }

    func createVersionSnapshot(at url: URL, fallbackExtension: String) throws -> URL {
        let directory = historyDirectory(for: url)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let extensionName = fileExtension(for: url, fallbackExtension: fallbackExtension)
        let baseName = baseName(for: url)
        let timestamp = Self.snapshotTimestampFormatter.string(from: now())
        var snapshotURL = directory.appendingPathComponent("\(baseName)-\(timestamp)").appendingPathExtension(extensionName)
        var suffix = 2

        while fileManager.fileExists(atPath: snapshotURL.path) {
            snapshotURL = directory.appendingPathComponent("\(baseName)-\(timestamp)-\(suffix)").appendingPathExtension(extensionName)
            suffix += 1
        }

        try fileManager.copyItem(at: url, to: snapshotURL)
        try? fileManager.setAttributes([.modificationDate: now()], ofItemAtPath: snapshotURL.path)
        return snapshotURL
    }

    func saveStatus(for url: URL, snapshotURL: URL?) -> String {
        guard let snapshotURL else {
            return "Saved \(url.lastPathComponent)"
        }

        return "Saved \(url.lastPathComponent) · snapshot \(snapshotURL.lastPathComponent)"
    }

    func historyDirectory(for url: URL) -> URL {
        url.deletingLastPathComponent().appendingPathComponent(".chiselo-history", isDirectory: true)
    }

    func latestVersionSnapshot(for url: URL) throws -> URL? {
        let directory = historyDirectory(for: url)
        guard fileManager.fileExists(atPath: directory.path) else { return nil }

        let extensionName = url.pathExtension
        let prefix = "\(baseName(for: url))-"
        let candidates = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        )
        .filter { candidate in
            candidate.lastPathComponent.hasPrefix(prefix)
                && (extensionName.isEmpty || candidate.pathExtension.lowercased() == extensionName.lowercased())
        }

        let rankedCandidates = candidates.compactMap { candidate -> (url: URL, rank: SnapshotRank)? in
            guard let rank = snapshotRank(for: candidate, prefix: prefix) else { return nil }
            return (candidate, rank)
        }

        return rankedCandidates.sorted { left, right in
            let leftRank = left.rank
            let rightRank = right.rank
            if leftRank.timestamp != rightRank.timestamp {
                return leftRank.timestamp > rightRank.timestamp
            }
            if leftRank.suffix != rightRank.suffix {
                return leftRank.suffix > rightRank.suffix
            }
            return left.url.lastPathComponent > right.url.lastPathComponent
        }.first?.url
    }

    private func backupURL(for url: URL, fallbackExtension: String) -> URL {
        url
            .deletingPathExtension()
            .appendingPathExtension("chiselo-backup")
            .appendingPathExtension(fileExtension(for: url, fallbackExtension: fallbackExtension))
    }

    private func fileExtension(for url: URL, fallbackExtension: String) -> String {
        url.pathExtension.isEmpty ? fallbackExtension : url.pathExtension
    }

    private func baseName(for url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        return name.isEmpty ? "document" : name
    }

    private func normalizedFilePath(for url: URL?) -> String? {
        guard let url, url.isFileURL else { return nil }
        return url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func snapshotRank(for url: URL, prefix: String) -> SnapshotRank? {
        let stem = url.deletingPathExtension().lastPathComponent
        guard stem.hasPrefix(prefix) else { return nil }

        let remainder = String(stem.dropFirst(prefix.count))
        guard remainder.count >= 15 else { return nil }

        let timestamp = String(remainder.prefix(15))
        let suffixPart = remainder.dropFirst(15)
        let suffix: Int
        if suffixPart.isEmpty {
            suffix = 1
        } else if suffixPart.first == "-", let value = Int(suffixPart.dropFirst()) {
            suffix = value
        } else {
            return nil
        }

        return SnapshotRank(timestamp: timestamp, suffix: suffix)
    }

    private static let snapshotTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
