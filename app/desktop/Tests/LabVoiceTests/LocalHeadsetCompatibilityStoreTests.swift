import XCTest
import Darwin
@testable import LabVoice

final class LocalHeadsetCompatibilityStoreTests: XCTestCase {
    private func withStore(_ body: (LocalHeadsetCompatibilityStore, URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(.init(directory: root.appendingPathComponent("saved")), root)
    }
    private let valid = Data(#"{"allow_list":[{"name":"Own headset"}],"block_list":[{"manufacturer":"Own","model_uid":"Blocked"}]}"#.utf8)
    private var previous: LocalHeadsetLists {
        .init(allowed: [.init(name: .string("Prior"))], manual: [.init(name: .string("Manual"))])
    }

    func testImportCopiesValidatedBytesAndReloadPreservesManual() throws {
        try withStore { store, root in
            let selected = root.appendingPathComponent("selected.json")
            try valid.write(to: selected)
            let result = store.importFile(at: selected, preserving: previous)
            XCTAssertTrue(result.loaded, result.failure ?? "")
            XCTAssertEqual(result.lists.manual, previous.manual)
            XCTAssertEqual(try Data(contentsOf: store.cacheURL), valid)
            try FileManager.default.removeItem(at: selected)
            let loaded = store.load(preserving: previous)
            XCTAssertTrue(loaded.loaded, loaded.failure ?? "")
            XCTAssertEqual(loaded.lists, result.lists)
        }
    }

    func testInvalidImportPreservesListsAndSavedBytes() throws {
        try withStore { store, root in
            let selected = root.appendingPathComponent("selected.json")
            try valid.write(to: selected)
            XCTAssertTrue(store.importFile(at: selected, preserving: previous).loaded)
            for data in [Data(), Data("{}".utf8), Data([0xff]), Data(repeating: 32, count: 1_048_577)] {
                try data.write(to: selected)
                let result = store.importFile(at: selected, preserving: previous)
                XCTAssertFalse(result.loaded)
                XCTAssertNotNil(result.failure)
                XCTAssertEqual(result.lists, previous)
                XCTAssertEqual(try Data(contentsOf: store.cacheURL), valid)
            }
        }
    }

    func testMissingAndCorruptSavedCachePreserveLists() throws {
        try withStore { store, _ in
            XCTAssertEqual(store.load(preserving: previous).lists, previous)
            XCTAssertFalse(store.load(preserving: previous).loaded)
            try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
            try Data("{}".utf8).write(to: store.cacheURL)
            let loaded = store.load(preserving: previous)
            XCTAssertFalse(loaded.loaded)
            XCTAssertEqual(loaded.lists, previous)
        }
    }

    func testLinksAndSpecialFilesAreRejected() throws {
        try withStore { store, root in
            let selected = root.appendingPathComponent("selected.json")
            try valid.write(to: selected)
            let link = root.appendingPathComponent("link.json")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: selected)
            XCTAssertFalse(store.importFile(at: link, preserving: previous).loaded)
            XCTAssertFalse(store.importFile(at: root, preserving: previous).loaded)
            let fifo = root.appendingPathComponent("pipe")
            XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
            XCTAssertFalse(store.importFile(at: fifo, preserving: previous).loaded)
            try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: store.cacheURL, withDestinationURL: selected)
            XCTAssertFalse(store.load(preserving: previous).loaded)
            XCTAssertFalse(store.importFile(at: selected, preserving: previous).loaded)
            XCTAssertFalse(store.clear(preserving: previous).loaded)
            XCTAssertEqual(try Data(contentsOf: selected), valid)
        }
    }

    func testPersistenceFailureDoesNotPublishLists() throws {
        try withStore { store, root in
            try Data("occupied".utf8).write(to: store.directory)
            let selected = root.appendingPathComponent("selected.json")
            try valid.write(to: selected)
            let result = store.importFile(at: selected, preserving: previous)
            XCTAssertFalse(result.loaded)
            XCTAssertEqual(result.lists, previous)
        }
    }

    func testExactByteLimitAndUnsafeSavedDirectory() throws {
        try withStore { store, root in
            let selected = root.appendingPathComponent("selected.json")
            var bounded = valid
            bounded.append(Data(repeating: 32, count: LocalHeadsetCompatibilityStore.byteLimit - valid.count))
            try bounded.write(to: selected)
            XCTAssertTrue(store.importFile(at: selected, preserving: previous).loaded)
            XCTAssertTrue(store.load(preserving: previous).loaded)
            try FileManager.default.removeItem(at: store.directory)
            let linked = root.appendingPathComponent("elsewhere")
            try FileManager.default.createDirectory(at: linked, withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: store.directory, withDestinationURL: linked)
            XCTAssertFalse(store.importFile(at: selected, preserving: previous).loaded)
            XCTAssertFalse(store.load(preserving: previous).loaded)
            XCTAssertFalse(store.clear(preserving: previous).loaded)
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: linked.path).isEmpty)
        }
    }

    func testClearRemovesOnlySavedListsAndPreservesManual() throws {
        try withStore { store, root in
            let selected = root.appendingPathComponent("selected.json")
            try valid.write(to: selected)
            XCTAssertTrue(store.importFile(at: selected, preserving: previous).loaded)
            let result = store.clear(preserving: previous)
            XCTAssertTrue(result.loaded)
            XCTAssertEqual(result.lists, .init(manual: previous.manual))
            XCTAssertFalse(FileManager.default.fileExists(atPath: store.cacheURL.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: selected.path))
            XCTAssertTrue(store.clear(preserving: previous).loaded)
        }
    }
}
