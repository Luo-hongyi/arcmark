import XCTest
@testable import ArcmarkCore

final class NoteStorageTests: XCTestCase {
    private func makeStore() -> DataStore {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return DataStore(baseDirectory: temp)
    }

    private func makeReadOnlyICloudStore() -> DataStore {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return DataStore(
            baseDirectory: temp,
            syncRoleProvider: { .secondary },
            iCloudDirectoryOverride: true
        )
    }

    func testReadMissingReturnsEmptyString() {
        let storage = NoteStorage(store: makeStore())
        XCTAssertEqual(storage.read(id: UUID()), "")
    }

    func testWriteThenRead() throws {
        let storage = NoteStorage(store: makeStore())
        let id = UUID()
        try storage.write(id: id, content: "# Hello\n\nWorld")
        XCTAssertEqual(storage.read(id: id), "# Hello\n\nWorld")
    }

    func testOverwriteReplacesContent() throws {
        let storage = NoteStorage(store: makeStore())
        let id = UUID()
        try storage.write(id: id, content: "first")
        try storage.write(id: id, content: "second")
        XCTAssertEqual(storage.read(id: id), "second")
    }

    func testDeleteRemovesFile() throws {
        let store = makeStore()
        let storage = NoteStorage(store: store)
        let id = UUID()
        try storage.write(id: id, content: "anything")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.noteFileURL(for: id).path))

        storage.delete(id: id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.noteFileURL(for: id).path))
    }

    func testDeleteMissingIsSilent() {
        let storage = NoteStorage(store: makeStore())
        // Should not throw
        storage.delete(id: UUID())
    }

    func testFileLocationIsUnderNotesDirectory() throws {
        let store = makeStore()
        let storage = NoteStorage(store: store)
        let id = UUID()
        try storage.write(id: id, content: "x")
        let url = store.noteFileURL(for: id)
        XCTAssertTrue(url.path.contains("/Notes/"))
        XCTAssertEqual(url.pathExtension, "md")
    }

    func testReadOnlyICloudStoreRejectsWrites() {
        let store = makeReadOnlyICloudStore()
        let storage = NoteStorage(store: store)
        let id = UUID()

        XCTAssertThrowsError(try storage.write(id: id, content: "blocked"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.noteFileURL(for: id).path))
    }
}
