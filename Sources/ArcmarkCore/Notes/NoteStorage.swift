import Foundation

enum NoteStorageError: Error {
    case readOnly
}

final class NoteStorage {
    private let store: DataStore
    private let fileManager = FileManager.default

    init(store: DataStore) {
        self.store = store
    }

    func read(id: UUID) -> String {
        let url = store.noteFileURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return "" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    func write(id: UUID, content: String) throws {
        guard store.canWriteSharedData else {
            throw NoteStorageError.readOnly
        }
        let url = store.noteFileURL(for: id)
        try content.data(using: .utf8)?.write(to: url, options: [.atomic])
    }

    func delete(id: UUID) {
        guard store.canWriteSharedData else { return }
        let url = store.noteFileURL(for: id)
        try? fileManager.removeItem(at: url)
    }
}
