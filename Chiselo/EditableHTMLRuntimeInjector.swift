import Foundation

private let selfEditableRuntimePatterns = [
    #"\s*<style\b(?=[^>]*\bdata-chiselo-lite-runtime\b)[^>]*>[\s\S]*?</style>\s*"#,
    #"\s*<script\b(?=[^>]*\bdata-chiselo-lite-runtime\b)[^>]*>[\s\S]*?</script>\s*"#
]

func replacingSelfEditableHTMLRuntime(in html: String, with runtime: String) -> String {
    var cleaned = html
    for pattern in selfEditableRuntimePatterns {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else { continue }
        let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
        cleaned = expression.stringByReplacingMatches(
            in: cleaned,
            options: [],
            range: range,
            withTemplate: ""
        )
    }

    if let range = cleaned.range(of: "</body>", options: [.caseInsensitive, .backwards]) {
        return cleaned.replacingCharacters(in: range, with: "\n\(runtime)\n</body>")
    }

    if let range = cleaned.range(of: "</html>", options: [.caseInsensitive, .backwards]) {
        return cleaned.replacingCharacters(in: range, with: "\n\(runtime)\n</html>")
    }

    return "\(cleaned)\n\(runtime)\n"
}
