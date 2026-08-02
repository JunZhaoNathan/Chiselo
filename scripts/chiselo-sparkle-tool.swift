#!/usr/bin/env swift
import CryptoKit
import Foundation
import Security

private let defaultAccount = "chiselo-ed25519"
private let sparkleKeychainService = "https://sparkle-project.org"

struct ToolError: Error, CustomStringConvertible {
    let description: String
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

func keychainQuery(account: String) -> [String: Any] {
    [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: sparkleKeychainService,
        kSecAttrAccount as String: account,
        kSecAttrProtocol as String: kSecAttrProtocolSSH
    ]
}

func readSeed(account: String) throws -> Data? {
    var query = keychainQuery(account: account)
    query[kSecReturnData as String] = kCFBooleanTrue

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
        return nil
    }
    guard status == errSecSuccess else {
        throw ToolError(description: "cannot read Sparkle signing key from Keychain: \(status)")
    }
    guard let encoded = item as? Data, let seed = Data(base64Encoded: encoded) else {
        throw ToolError(description: "stored Sparkle signing key is not valid base64")
    }
    guard seed.count == 32 else {
        throw ToolError(description: "stored Sparkle signing key must be a 32-byte Ed25519 seed")
    }
    return seed
}

func storeSeed(_ seed: Data, publicKey: Data, account: String) throws {
    var query = keychainQuery(account: account)
    query[kSecAttrIsSensitive as String] = kCFBooleanTrue
    query[kSecAttrIsPermanent as String] = kCFBooleanTrue
    query[kSecAttrLabel as String] = "Private key for signing Chiselo Sparkle updates"
    query[kSecAttrDescription as String] = "private key"
    query[kSecAttrComment as String] = "Public key (SUPublicEDKey value) for this key is:\n\n\(publicKey.base64EncodedString())"
    query[kSecValueData as String] = seed.base64EncodedData() as CFData

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw ToolError(description: "cannot store Sparkle signing key in Keychain: \(status)")
    }
}

func signingKey(account: String, createIfMissing: Bool) throws -> Curve25519.Signing.PrivateKey {
    if let seed = try readSeed(account: account) {
        return try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
    }
    guard createIfMissing else {
        throw ToolError(description: "Sparkle signing key not found; run `swift scripts/chiselo-sparkle-tool.swift ensure-key` first")
    }
    let key = Curve25519.Signing.PrivateKey()
    try storeSeed(key.rawRepresentation, publicKey: key.publicKey.rawRepresentation, account: account)
    return key
}

func xmlEscaped(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

func rfc822Date(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    return formatter.string(from: date)
}

func signature(for data: Data, key: Curve25519.Signing.PrivateKey) throws -> String {
    try key.signature(for: data).base64EncodedString()
}

func parseOptions(_ args: [String]) -> [String: String] {
    var result: [String: String] = [:]
    var index = 0
    while index < args.count {
        let option = args[index]
        guard option.hasPrefix("--") else {
            fail("unexpected argument: \(option)")
        }
        let name = String(option.dropFirst(2))
        guard index + 1 < args.count else {
            fail("missing value for \(option)")
        }
        result[name] = args[index + 1]
        index += 2
    }
    return result
}

func require(_ options: [String: String], _ name: String) -> String {
    guard let value = options[name], !value.isEmpty else {
        fail("missing --\(name)")
    }
    return value
}

func writeAppcast(options: [String: String], account: String) throws {
    let outputPath = require(options, "output")
    let archivePath = require(options, "archive")
    let downloadURL = require(options, "download-url")
    let shortVersion = require(options, "short-version")
    let bundleVersion = require(options, "bundle-version")
    let minimumSystemVersion = require(options, "minimum-system-version")
    let arch = require(options, "arch")
    let appName = options["app-name"] ?? "Chiselo"
    let productLink = options["link"] ?? "https://downloads.vellumloop.com/chiselo"

    let key = try signingKey(account: account, createIfMissing: false)
    let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
    if let expectedPublicKey = options["expected-public-key"], expectedPublicKey != publicKey {
        throw ToolError(description: "Info.plist SUPublicEDKey does not match Keychain signing key")
    }

    let archiveURL = URL(fileURLWithPath: archivePath)
    let archiveData = try Data(contentsOf: archiveURL, options: .mappedIfSafe)
    let archiveLength = try FileManager.default.attributesOfItem(atPath: archivePath)[.size] as? NSNumber
    guard let archiveLength else {
        throw ToolError(description: "cannot determine archive size: \(archivePath)")
    }
    let archiveSignature = try signature(for: archiveData, key: key)
    let pubDate = rfc822Date(Date())

    let hardwareRequirementElement = arch == "arm64"
        ? "      <sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>\n"
        : ""

    let appcast = """
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
      <channel>
        <title>\(xmlEscaped(appName)) Updates</title>
        <link>\(xmlEscaped(productLink))</link>
        <description>\(xmlEscaped(appName)) macOS release feed</description>
        <language>zh-CN</language>
        <item>
          <title>\(xmlEscaped(appName)) \(xmlEscaped(shortVersion))</title>
          <sparkle:version>\(xmlEscaped(bundleVersion))</sparkle:version>
          <sparkle:shortVersionString>\(xmlEscaped(shortVersion))</sparkle:shortVersionString>
    \(hardwareRequirementElement)\
          <sparkle:minimumSystemVersion>\(xmlEscaped(minimumSystemVersion))</sparkle:minimumSystemVersion>
          <pubDate>\(pubDate)</pubDate>
          <enclosure url="\(xmlEscaped(downloadURL))" length="\(archiveLength.stringValue)" type="application/x-apple-diskimage" sparkle:version="\(xmlEscaped(bundleVersion))" sparkle:shortVersionString="\(xmlEscaped(shortVersion))" sparkle:edSignature="\(archiveSignature)" />
        </item>
      </channel>
    </rss>

    """

    let appcastData = Data(appcast.utf8)
    let feedSignature = try signature(for: appcastData, key: key)
    let signedAppcast = appcastData + Data("<!-- sparkle-signatures:\nedSignature: \(feedSignature)\nlength: \(appcastData.count)\n-->\n".utf8)
    try signedAppcast.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
}

func attributeValue(_ name: String, in element: XMLElement) -> String? {
    element.attributes?.first { attribute in
        attribute.name == name || attribute.localName == name || attribute.name?.hasSuffix(":\(name)") == true
    }?.stringValue
}

func verifyAppcast(options: [String: String]) throws {
    let appcastPath = require(options, "appcast")
    let archivePath = require(options, "archive")
    let publicKeyValue = require(options, "public-key")
    let expectedShortVersion = require(options, "short-version")
    let expectedBundleVersion = require(options, "bundle-version")
    let expectedDownloadURL = require(options, "download-url")

    let document = try XMLDocument(
        contentsOf: URL(fileURLWithPath: appcastPath),
        options: [.nodePreserveAll]
    )
    guard let enclosure = try document.nodes(forXPath: "//enclosure").first as? XMLElement else {
        throw ToolError(description: "appcast has no enclosure element")
    }

    guard let signatureValue = attributeValue("edSignature", in: enclosure),
          let signature = Data(base64Encoded: signatureValue) else {
        throw ToolError(description: "appcast enclosure has no valid Sparkle Ed25519 signature")
    }
    guard let declaredLengthValue = attributeValue("length", in: enclosure),
          let declaredLength = Int(declaredLengthValue) else {
        throw ToolError(description: "appcast enclosure has no valid archive length")
    }
    guard attributeValue("shortVersionString", in: enclosure) == expectedShortVersion else {
        throw ToolError(description: "appcast short version does not match \(expectedShortVersion)")
    }
    guard attributeValue("version", in: enclosure) == expectedBundleVersion else {
        throw ToolError(description: "appcast bundle version does not match \(expectedBundleVersion)")
    }
    guard attributeValue("url", in: enclosure) == expectedDownloadURL else {
        throw ToolError(description: "appcast download URL does not match \(expectedDownloadURL)")
    }

    guard let publicKeyData = Data(base64Encoded: publicKeyValue), publicKeyData.count == 32 else {
        throw ToolError(description: "SUPublicEDKey must be a base64-encoded 32-byte Ed25519 public key")
    }
    let archiveData = try Data(contentsOf: URL(fileURLWithPath: archivePath), options: .mappedIfSafe)
    guard archiveData.count == declaredLength else {
        throw ToolError(description: "appcast archive length \(declaredLength) does not match file size \(archiveData.count)")
    }
    let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
    guard publicKey.isValidSignature(signature, for: archiveData) else {
        throw ToolError(description: "Sparkle archive signature verification failed")
    }

    print("Sparkle appcast signature OK: \(expectedShortVersion) (\(expectedBundleVersion))")
}

func printUsage() {
    print("""
    Usage:
      swift scripts/chiselo-sparkle-tool.swift ensure-key [--account name]
      swift scripts/chiselo-sparkle-tool.swift public-key [--account name]
      swift scripts/chiselo-sparkle-tool.swift archive-signature --archive path [--account name]
      swift scripts/chiselo-sparkle-tool.swift write-appcast --output path --archive path --download-url url --short-version version --bundle-version build --minimum-system-version version --arch arch [--expected-public-key key]
      swift scripts/chiselo-sparkle-tool.swift verify-appcast --appcast path --archive path --public-key key --short-version version --bundle-version build --download-url url
    """)
}

do {
    var args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first else {
        printUsage()
        exit(2)
    }
    args.removeFirst()
    let options = parseOptions(args)
    let account = options["account"] ?? defaultAccount

    switch command {
    case "ensure-key":
        let key = try signingKey(account: account, createIfMissing: true)
        print(key.publicKey.rawRepresentation.base64EncodedString())
    case "public-key":
        let key = try signingKey(account: account, createIfMissing: false)
        print(key.publicKey.rawRepresentation.base64EncodedString())
    case "archive-signature":
        let key = try signingKey(account: account, createIfMissing: false)
        let archivePath = require(options, "archive")
        let data = try Data(contentsOf: URL(fileURLWithPath: archivePath), options: .mappedIfSafe)
        let length = try FileManager.default.attributesOfItem(atPath: archivePath)[.size] as? NSNumber
        guard let length else {
            throw ToolError(description: "cannot determine archive size: \(archivePath)")
        }
        print("sparkle:edSignature=\"\(try signature(for: data, key: key))\" length=\"\(length.stringValue)\"")
    case "write-appcast":
        try writeAppcast(options: options, account: account)
    case "verify-appcast":
        try verifyAppcast(options: options)
    case "help", "--help", "-h":
        printUsage()
    default:
        fail("unknown command: \(command)")
    }
} catch {
    fail(String(describing: error))
}
