import Foundation

struct OpenTabPayload: Sendable {
    let title: String
    let url: URL
    let mode: String
    let content: String
}

enum OpenTabReadResult: Sendable {
    case success(OpenTabPayload)
    case failure(filename: String, message: String)
}

func readOpenTabPayload(_ url: URL) -> OpenTabReadResult {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer {
        if didAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }

    do {
        let content = try readTextFile(at: url)
        let ext = url.pathExtension.lowercased()
        let mode = ["html", "htm", "xhtml"].contains(ext) ? "html" : "deck"

        if mode == "deck" {
            guard let data = content.data(using: .utf8) else {
                return .failure(filename: url.lastPathComponent, message: "Could not read \(url.lastPathComponent)")
            }
            _ = try JSONDecoder().decode(EditorDeck.self, from: data)
        }

        let title = url.lastPathComponent.isEmpty ? "未命名" : url.lastPathComponent
        return .success(OpenTabPayload(title: title, url: url, mode: mode, content: content))
    } catch {
        return .failure(filename: url.lastPathComponent, message: "Open failed for \(url.lastPathComponent): \(error.localizedDescription)")
    }
}

func readTextFile(at url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    for encoding in textFileEncodingCandidates {
        if let string = String(data: data, encoding: encoding) {
            return string
        }
    }

    throw CocoaError(.fileReadCorruptFile)
}

private let textFileEncodingCandidates: [String.Encoding] = [
    .utf8,
    .utf16,
    .utf16LittleEndian,
    .utf16BigEndian,
    .utf32,
    .utf32LittleEndian,
    .utf32BigEndian,
    .isoLatin1,
    .windowsCP1252,
    .ascii,
    String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
]
