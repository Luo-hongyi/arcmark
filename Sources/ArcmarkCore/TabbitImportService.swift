import Foundation

struct TabbitImportResult: Sendable {
    let workspace: ImportWorkspace
    let groupsImported: Int
    let linksImported: Int
}

enum TabbitImportError: Error {
    case profileNotFound
    case sessionsNotFound
    case noPagesFound
    case parsingFailed(String)
}

extension TabbitImportError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "Tabbit profile not found. Please make sure Tabbit is installed and has open pages."
        case .sessionsNotFound:
            return "Tabbit session data not found. Please open Tabbit and try again."
        case .noPagesFound:
            return "No open Tabbit pages were found."
        case .parsingFailed(let detail):
            return "Failed to parse Tabbit pages: \(detail)"
        }
    }
}

final class TabbitImportService: Sendable {
    static let shared = TabbitImportService()

    private struct SessionCommand {
        let id: UInt8
        let payload: Data
    }

    private struct GroupMetadata {
        let token: String
        let name: String
    }

    private struct TabNavigation {
        let tabId: UInt32
        let index: Int
        let url: String
        let title: String
    }

    private struct TabbitTab {
        let url: String
        let title: String
        let order: Int
    }

    private struct TabbitGroup {
        let name: String
        let tabs: [TabbitTab]
    }

    private init() {}

    func importFromDefaultProfile() async -> Result<TabbitImportResult, TabbitImportError> {
        let profileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Tabbit/Default")
        return await importFromTabbit(profileURL: profileURL)
    }

    func importFromTabbit(profileURL: URL) async -> Result<TabbitImportResult, TabbitImportError> {
        await Task.yield()

        return await Task.detached {
            do {
                let fileManager = FileManager.default
                guard fileManager.fileExists(atPath: profileURL.path) else {
                    return .failure(.profileNotFound)
                }

                let sessionData = try self.loadLatestSession(profileURL: profileURL)
                let groups = try self.extractGroups(from: sessionData)

                guard !groups.isEmpty else {
                    return .failure(.noPagesFound)
                }

                let nodes = groups.map { group -> Node in
                    let links = group.tabs.map { tab in
                        Node.link(Link(
                            id: UUID(),
                            title: tab.title,
                            url: tab.url,
                            faviconPath: nil
                        ))
                    }
                    return .folder(Folder(
                        id: UUID(),
                        name: group.name,
                        children: links,
                        isExpanded: false
                    ))
                }

                let workspace = ImportWorkspace(
                    name: "Tabbit",
                    colorId: .ocean,
                    customIcon: nil,
                    nodes: nodes
                )

                return .success(TabbitImportResult(
                    workspace: workspace,
                    groupsImported: groups.count,
                    linksImported: groups.reduce(0) { $0 + $1.tabs.count }
                ))
            } catch let error as TabbitImportError {
                return .failure(error)
            } catch {
                return .failure(.parsingFailed(error.localizedDescription))
            }
        }.value
    }

    private func loadLatestSession(profileURL: URL) throws -> Data {
        let sessionsURL = profileURL.appendingPathComponent("Sessions")
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sessionsURL.path) else {
            throw TabbitImportError.sessionsNotFound
        }

        let sessionFiles = try fileManager.contentsOfDirectory(
            at: sessionsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
            .filter { $0.lastPathComponent.hasPrefix("Session_") }
            .sorted { lhs, rhs in
                modificationDate(for: lhs) > modificationDate(for: rhs)
            }

        guard let latestSession = sessionFiles.first else {
            throw TabbitImportError.sessionsNotFound
        }

        return try Data(contentsOf: latestSession)
    }

    private func modificationDate(for url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? .distantPast
    }

    private func extractGroups(from sessionData: Data) throws -> [TabbitGroup] {
        let commands = try parseSessionCommands(from: sessionData)
        let groupMetadata = commands.compactMap { command -> GroupMetadata? in
            guard command.id == 27 else { return nil }
            return parseGroupMetadata(command.payload)
        }

        var groupsByToken: [String: GroupMetadata] = [:]
        for group in groupMetadata {
            groupsByToken[group.token] = group
        }

        var navigationsByTab: [UInt32: [Int: TabNavigation]] = [:]
        var selectedNavigationIndexByTab: [UInt32: Int] = [:]
        var tabOrderByTab: [UInt32: Int] = [:]
        var groupTokenByTab: [UInt32: String] = [:]

        for command in commands {
            switch command.id {
            case 6:
                guard let navigation = parseNavigation(command.payload) else { continue }
                navigationsByTab[navigation.tabId, default: [:]][navigation.index] = navigation
            case 7:
                guard command.payload.count >= 8 else { continue }
                selectedNavigationIndexByTab[command.payload.readUInt32LE(at: 0)] =
                    Int(command.payload.readInt32LE(at: 4))
            case 2:
                guard command.payload.count >= 8 else { continue }
                tabOrderByTab[command.payload.readUInt32LE(at: 0)] =
                    Int(command.payload.readInt32LE(at: 4))
            case 25:
                guard command.payload.count >= 24 else { continue }
                let groupToken = command.payload.hexString(in: 8..<24)
                if groupsByToken[groupToken] != nil {
                    groupTokenByTab[command.payload.readUInt32LE(at: 0)] = groupToken
                }
            default:
                continue
            }
        }

        return groupMetadata.compactMap { group in
            let tabs = groupTokenByTab.compactMap { tabId, groupToken -> TabbitTab? in
                guard groupToken == group.token,
                      let navigations = navigationsByTab[tabId],
                      let navigation = selectedNavigation(in: navigations, selectedIndex: selectedNavigationIndexByTab[tabId]),
                      isImportableURL(navigation.url) else {
                    return nil
                }

                return TabbitTab(
                    url: navigation.url,
                    title: cleanPageTitle(navigation.title) ?? fallbackTitle(for: navigation.url),
                    order: tabOrderByTab[tabId] ?? Int.max
                )
            }
                .sorted { lhs, rhs in
                    lhs.order < rhs.order
                }

            guard !tabs.isEmpty else { return nil }
            return TabbitGroup(name: group.name, tabs: tabs)
        }
    }

    private func parseSessionCommands(from data: Data) throws -> [SessionCommand] {
        guard data.count >= 8,
              String(data: data[0..<4], encoding: .ascii) == "SNSS" else {
            throw TabbitImportError.parsingFailed("Invalid session file header.")
        }

        var commands: [SessionCommand] = []
        var offset = 8

        while offset + 3 <= data.count {
            let length = Int(data.readUInt16LE(at: offset))
            let commandId = data[offset + 2]
            let payloadStart = offset + 3
            let payloadEnd = offset + 2 + length

            guard length > 0, payloadEnd <= data.count else {
                throw TabbitImportError.parsingFailed("Invalid session command at offset \(offset).")
            }

            commands.append(SessionCommand(
                id: commandId,
                payload: Data(data[payloadStart..<payloadEnd])
            ))
            offset = payloadEnd
        }

        return commands
    }

    private func parseGroupMetadata(_ payload: Data) -> GroupMetadata? {
        guard payload.count >= 48 else { return nil }

        let token = payload.hexString(in: 4..<20)
        let nameLength = Int(payload.readUInt32LE(at: 20))
        let nameStart = 24
        let nameEnd = nameStart + nameLength * 2
        let afterName = align4(nameEnd)

        guard nameEnd <= payload.count,
              afterName + 16 <= payload.count else {
            return nil
        }

        let nameData = payload[nameStart..<nameEnd]
        let idLengthOffset = afterName + 12
        let idLength = Int(payload.readUInt32LE(at: idLengthOffset))
        let idStart = idLengthOffset + 4
        let idEnd = idStart + idLength

        guard idEnd <= payload.count,
              String(data: payload[idStart..<idEnd], encoding: .utf8) != nil,
              let name = String(data: nameData, encoding: .utf16LittleEndian),
              !name.isEmpty else {
            return nil
        }

        return GroupMetadata(token: token, name: name)
    }

    private func parseNavigation(_ payload: Data) -> TabNavigation? {
        guard payload.count >= 20 else { return nil }

        let tabId = payload.readUInt32LE(at: 4)
        let index = Int(payload.readInt32LE(at: 8))
        let urlLength = Int(payload.readUInt32LE(at: 12))
        let urlStart = 16
        let urlEnd = urlStart + urlLength

        guard urlLength > 0,
              urlLength <= 4096,
              urlEnd <= payload.count,
              let url = String(data: payload[urlStart..<urlEnd], encoding: .utf8) else {
            return nil
        }

        let titleLengthOffset = align4(urlEnd)
        guard titleLengthOffset + 4 <= payload.count else { return nil }

        let titleLength = Int(payload.readUInt32LE(at: titleLengthOffset))
        let titleStart = titleLengthOffset + 4
        let titleEnd = titleStart + titleLength * 2

        guard titleLength <= 1000,
              titleEnd <= payload.count,
              let title = String(data: payload[titleStart..<titleEnd], encoding: .utf16LittleEndian) else {
            return nil
        }

        return TabNavigation(
            tabId: tabId,
            index: index,
            url: url.replacingOccurrences(of: "\u{0}", with: ""),
            title: title.replacingOccurrences(of: "\u{0}", with: "")
        )
    }

    private func selectedNavigation(in navigations: [Int: TabNavigation], selectedIndex: Int?) -> TabNavigation? {
        if let selectedIndex, let navigation = navigations[selectedIndex] {
            return navigation
        }

        guard let maxIndex = navigations.keys.max() else {
            return nil
        }
        return navigations[maxIndex]
    }

    private func isImportableURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              url.scheme == "http" || url.scheme == "https" else {
            return false
        }

        let groupHomeHosts: Set<String> = ["web.tabbitbrowser.com", "web.tabbit.ai"]
        if let host = url.host?.lowercased(),
           groupHomeHosts.contains(host),
           url.path == "/newtab" || url.path == "/session/new" || url.path.hasPrefix("/group-home/") {
            return false
        }

        return true
    }

    private func cleanPageTitle(_ candidate: String) -> String? {
        let title = candidate
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ". \t\r\n\""))

        guard title.count >= 2 else { return nil }
        return String(title.prefix(160))
    }

    private func fallbackTitle(for urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return "Untitled"
        }

        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty {
            return host
        }

        let decodedPath = path.removingPercentEncoding ?? path
        return "\(host)/\(decodedPath)"
    }

    private func align4(_ value: Int) -> Int {
        (value + 3) & ~3
    }
}

private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        UInt16(self[offset]) |
            UInt16(self[offset + 1]) << 8
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        UInt32(self[offset]) |
            UInt32(self[offset + 1]) << 8 |
            UInt32(self[offset + 2]) << 16 |
            UInt32(self[offset + 3]) << 24
    }

    func readInt32LE(at offset: Int) -> Int32 {
        Int32(bitPattern: readUInt32LE(at: offset))
    }

    func hexString(in range: Range<Int>) -> String {
        self[range].map { String(format: "%02x", $0) }.joined()
    }
}
