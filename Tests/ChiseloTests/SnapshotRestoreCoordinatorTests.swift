import Foundation
import XCTest
@testable import Chiselo

final class SnapshotRestoreCoordinatorTests: XCTestCase {
    func testRestoreAtomicallyReplacesDestination() throws {
        try withFixture { fixture in
            try restoreSnapshotFile(from: fixture.snapshotURL, to: fixture.destinationURL)

            XCTAssertEqual(
                try String(contentsOf: fixture.destinationURL, encoding: .utf8),
                "snapshot"
            )
            XCTAssertEqual(
                try String(contentsOf: fixture.snapshotURL, encoding: .utf8),
                "snapshot"
            )
        }
    }

    func testFailedCommitRestoresOriginalDestination() throws {
        try withFixture { fixture in
            XCTAssertThrowsError(
                try restoreSnapshotFile(
                    from: fixture.snapshotURL,
                    to: fixture.destinationURL,
                    commitHandler: { _, destinationURL, _ in
                        try FileManager.default.removeItem(at: destinationURL)
                        throw InjectedFailure.commit
                    }
                )
            ) { error in
                guard case SnapshotRestoreError.transactionFailed(_, let rollbackFailure) = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
                XCTAssertNil(rollbackFailure)
            }

            XCTAssertEqual(
                try String(contentsOf: fixture.destinationURL, encoding: .utf8),
                "original"
            )
            XCTAssertEqual(
                try String(contentsOf: fixture.snapshotURL, encoding: .utf8),
                "snapshot"
            )
        }
    }

    private enum InjectedFailure: Error {
        case commit
    }

    private struct Fixture {
        let destinationURL: URL
        let snapshotURL: URL
    }

    private func withFixture(_ body: (Fixture) throws -> Void) throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("chiselo-restore-xctest-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let destinationURL = directory.appendingPathComponent("document.html")
        let snapshotURL = directory.appendingPathComponent("snapshot.html")
        try "original".write(to: destinationURL, atomically: true, encoding: .utf8)
        try "snapshot".write(to: snapshotURL, atomically: true, encoding: .utf8)

        try body(Fixture(
            destinationURL: destinationURL,
            snapshotURL: snapshotURL
        ))
    }
}
