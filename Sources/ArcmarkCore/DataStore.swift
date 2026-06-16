import Foundation
import os

final class DataStore {
    private let fileManager: FileManager
    private let baseDirectory: URL
    private let dataURL: URL
    private let usesICloudDirectory: Bool
    private let syncRoleProvider: () -> SyncRole
    private let logger = Logger(subsystem: "com.arcmark.app", category: "store")
    private var hasBackedUpThisSession = false
    private let backupKeepCount = 10
    private let backupTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss-SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    init(baseDirectory: URL? = nil,
         fileManager: FileManager = .default,
         syncRoleProvider: @escaping () -> SyncRole = { SyncRole.current },
         iCloudDirectoryOverride: Bool? = nil) {
        self.fileManager = fileManager
        self.syncRoleProvider = syncRoleProvider
        let resolvedBaseDirectory = baseDirectory ?? Self.defaultBaseDirectory(fileManager: fileManager)
        self.baseDirectory = resolvedBaseDirectory
        self.dataURL = self.baseDirectory.appendingPathComponent("data.json")
        self.usesICloudDirectory = iCloudDirectoryOverride ?? Self.isICloudDirectory(resolvedBaseDirectory, fileManager: fileManager)
        if baseDirectory == nil, canWriteSharedData {
            migrateLocalDataToICloudIfNeeded()
        }
    }

    func load() -> AppState {
        if canWriteSharedData {
            ensureDirectories()
        }
        prepareDataFileForReadIfNeeded()

        guard fileManager.fileExists(atPath: dataURL.path) else {
            let defaultState = Self.defaultState()
            if canWriteSharedData {
                save(defaultState)
            }
            return defaultState
        }

        backupDataFileIfNeeded()

        do {
            let data = try readDataFile()
            let decoder = JSONDecoder()
            let state = try decoder.decode(AppState.self, from: data)
            return state
        } catch {
            // Leave data.json untouched so a newer-schema or corrupt file can be
            // recovered (e.g. by re-upgrading); it is only overwritten on the
            // first actual mutation, and the pre-decode backup exists by then.
            logger.error("Failed to decode data.json; leaving file untouched: \(error.localizedDescription, privacy: .public)")
            return Self.defaultState()
        }
    }

    @discardableResult
    func save(_ state: AppState) -> Bool {
        guard canWriteSharedData else {
            logger.debug("Skipping shared data save while sync role is secondary")
            return false
        }

        backupDataFileIfNeeded()
        ensureDirectories()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: dataURL, options: [.atomic])
            return true
        } catch {
            // Failing silently to avoid crashing; this can be surfaced later in a UI.
            return false
        }
    }

    func iconsDirectory() -> URL {
        let iconsURL = auxiliaryBaseDirectoryForWrites().appendingPathComponent("Icons", isDirectory: true)
        if !fileManager.fileExists(atPath: iconsURL.path) {
            try? fileManager.createDirectory(at: iconsURL, withIntermediateDirectories: true)
        }
        return iconsURL
    }

    func notesDirectory() -> URL {
        let notesURL = baseDirectory.appendingPathComponent("Notes", isDirectory: true)
        guard canWriteSharedData else { return notesURL }
        if !fileManager.fileExists(atPath: notesURL.path) {
            try? fileManager.createDirectory(at: notesURL, withIntermediateDirectories: true)
        }
        return notesURL
    }

    func noteFileURL(for id: UUID) -> URL {
        notesDirectory().appendingPathComponent("\(id.uuidString).md")
    }

    func agentEndpointFileURL() -> URL {
        let localDirectory = Self.localBaseDirectory(fileManager: fileManager)
        if !fileManager.fileExists(atPath: localDirectory.path) {
            try? fileManager.createDirectory(at: localDirectory, withIntermediateDirectories: true)
        }
        return localDirectory.appendingPathComponent("agent-endpoint.json")
    }

    var canWriteSharedData: Bool {
        !usesICloudDirectory || syncRoleProvider().canWriteICloud
    }

    /// Copies data.json into `Backups/` once per session, before this process
    /// first writes to it. Skips the copy when the file is byte-identical to the
    /// newest existing backup so repeated relaunches don't rotate away the last
    /// good backup. Keeps the `backupKeepCount` most recent backups.
    private func backupDataFileIfNeeded() {
        guard canWriteSharedData else { return }
        guard !hasBackedUpThisSession else { return }
        hasBackedUpThisSession = true

        guard fileManager.fileExists(atPath: dataURL.path) else { return }

        do {
            let data = try Data(contentsOf: dataURL)
            let backupsURL = backupsDirectory()
            if let newest = sortedBackupURLs(in: backupsURL).last,
               let newestData = try? Data(contentsOf: newest),
               newestData == data {
                return
            }
            let timestamp = backupTimestampFormatter.string(from: Date())
            let backupURL = backupsURL.appendingPathComponent("data-\(timestamp).json")
            try data.write(to: backupURL, options: [.atomic])
            pruneBackups(in: backupsURL)
        } catch {
            logger.error("Failed to back up data.json: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func backupsDirectory() -> URL {
        let backupsURL = baseDirectory.appendingPathComponent("Backups", isDirectory: true)
        if !fileManager.fileExists(atPath: backupsURL.path) {
            try? fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true)
        }
        return backupsURL
    }

    /// Backup filenames are fixed-width UTC timestamps, so lexicographic order
    /// equals chronological order.
    private func sortedBackupURLs(in backupsURL: URL) -> [URL] {
        let contents = (try? fileManager.contentsOfDirectory(at: backupsURL, includingPropertiesForKeys: nil)) ?? []
        return contents
            .filter { $0.lastPathComponent.hasPrefix("data-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func pruneBackups(in backupsURL: URL) {
        let backups = sortedBackupURLs(in: backupsURL)
        guard backups.count > backupKeepCount else { return }
        for url in backups.dropLast(backupKeepCount) {
            try? fileManager.removeItem(at: url)
        }
    }

    private func ensureDirectories() {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
    }

    private func auxiliaryBaseDirectoryForWrites() -> URL {
        if canWriteSharedData {
            return baseDirectory
        }
        return Self.localBaseDirectory(fileManager: fileManager)
    }

    static func defaultBaseDirectory(fileManager: FileManager = .default) -> URL {
        if let iCloudDirectory = iCloudBaseDirectory(fileManager: fileManager) {
            return iCloudDirectory
        }
        return localBaseDirectory(fileManager: fileManager)
    }

    private static func isICloudDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        guard let iCloudDirectory = iCloudBaseDirectory(fileManager: fileManager) else { return false }
        return url.standardizedFileURL == iCloudDirectory.standardizedFileURL
    }

    private static func iCloudBaseDirectory(fileManager: FileManager = .default) -> URL? {
        let cloudDocs = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Mobile Documents", isDirectory: true)
            .appendingPathComponent("com~apple~CloudDocs", isDirectory: true)
        guard fileManager.fileExists(atPath: cloudDocs.path) else { return nil }
        return cloudDocs.appendingPathComponent("Arcmark", isDirectory: true)
    }

    private static func localBaseDirectory(fileManager: FileManager = .default) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Arcmark", isDirectory: true)
    }

    private func prepareDataFileForReadIfNeeded() {
        guard usesICloudDirectory, fileManager.fileExists(atPath: dataURL.path) else { return }

        do {
            try fileManager.startDownloadingUbiquitousItem(at: dataURL)
        } catch {
            logger.debug("Could not request iCloud download for data.json: \(error.localizedDescription, privacy: .public)")
        }

        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            guard let values = try? dataURL.resourceValues(forKeys: [
                .ubiquitousItemDownloadingStatusKey,
                .ubiquitousItemIsDownloadingKey
            ]),
                  let status = values.ubiquitousItemDownloadingStatus else {
                return
            }

            if status == .current || (status == .downloaded && values.ubiquitousItemIsDownloading != true) {
                return
            }

            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private func readDataFile() throws -> Data {
        guard usesICloudDirectory else {
            return try Data(contentsOf: dataURL)
        }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var readResult: Result<Data, Error>?

        coordinator.coordinate(readingItemAt: dataURL, options: [], error: &coordinationError) { coordinatedURL in
            readResult = Result {
                try Data(contentsOf: coordinatedURL)
            }
        }

        if let readResult {
            return try readResult.get()
        }
        if let coordinationError {
            throw coordinationError
        }
        return try Data(contentsOf: dataURL)
    }

    private func migrateLocalDataToICloudIfNeeded() {
        guard let iCloudDirectory = Self.iCloudBaseDirectory(fileManager: fileManager),
              baseDirectory.standardizedFileURL == iCloudDirectory.standardizedFileURL else { return }

        let localDirectory = Self.localBaseDirectory(fileManager: fileManager)
        guard fileManager.fileExists(atPath: localDirectory.path),
              !fileManager.fileExists(atPath: dataURL.path) else { return }

        ensureDirectories()
        for name in ["data.json", "Icons", "Notes"] {
            let source = localDirectory.appendingPathComponent(name)
            let destination = baseDirectory.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: source.path),
                  !fileManager.fileExists(atPath: destination.path) else { continue }
            do {
                try fileManager.copyItem(at: source, to: destination)
            } catch {
                logger.error("Failed to migrate \(name, privacy: .public) to iCloud Drive: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func defaultState() -> AppState {
        let workspace = Workspace(
            id: UUID(),
            name: "Inbox",
            colorId: .defaultColor(),
            items: []
        )
        return AppState(schemaVersion: 1, workspaces: [workspace], selectedWorkspaceId: workspace.id, isSettingsSelected: false)
    }
}
