import AppKit
import Foundation

extension Notification.Name {
    static let defaultBrowserChanged = Notification.Name("defaultBrowserChanged")
    static let syncRoleChanged = Notification.Name("syncRoleChanged")
    static let appearancePreferenceChanged = Notification.Name("appearancePreferenceChanged")
}

enum UserDefaultsKeys {
    static let defaultBrowserBundleId = "defaultBrowserBundleId"
    static let alwaysOnTopEnabled = "alwaysOnTopEnabled"
    static let lastSelectedWorkspaceId = "lastSelectedWorkspaceId"
    static let mainWindowSize = "mainWindowSize"
    static let sidebarAttachmentEnabled = "sidebarAttachmentEnabled"
    static let sidebarPosition = "sidebarPosition"
    static let lastArcImportDate = "lastArcImportDate"
    static let arcImportCount = "arcImportCount"
    static let toggleSidebarShortcut = "toggleSidebarShortcut"
    static let tooltipsEnabled = "tooltipsEnabled"
    static let swipeToSwitchEnabled = "swipeToSwitchEnabled"
    static let syncRole = "syncRole"
    static let appearancePreference = "appearancePreference"
}

/// User-selected app appearance. There is no "follow system" option by design — the
/// user explicitly picks light or dark (default: light).
enum AppearancePreference: String {
    case light
    case dark

    static var current: AppearancePreference {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: UserDefaultsKeys.appearancePreference),
                  let pref = AppearancePreference(rawValue: rawValue) else {
                return .light
            }
            return pref
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKeys.appearancePreference)
            NotificationCenter.default.post(name: .appearancePreferenceChanged, object: nil, userInfo: ["preference": newValue])
        }
    }

    /// The `NSAppearance` to force on the window for this preference.
    var nsAppearance: NSAppearance {
        switch self {
        case .light: return NSAppearance(named: .aqua)!
        case .dark: return NSAppearance(named: .darkAqua)!
        }
    }
}

enum SyncRole: String {
    case secondary
    case primary

    static var current: SyncRole {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: UserDefaultsKeys.syncRole),
                  let role = SyncRole(rawValue: rawValue) else {
                return .secondary
            }
            return role
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKeys.syncRole)
            NotificationCenter.default.post(name: .syncRoleChanged, object: nil)
        }
    }

    var canWriteICloud: Bool {
        self == .primary
    }
}

let nodePasteboardType = NSPasteboard.PasteboardType("com.arcmark.node")
let workspacePasteboardType = NSPasteboard.PasteboardType("com.arcmark.workspace")

struct TooltipConstants {
    static let showDelay: TimeInterval = 1.2
}

struct LayoutConstants {
    static let windowPadding: CGFloat = 8
}

struct ListMetrics {
    let rowHeight: CGFloat = 40
    let verticalGap: CGFloat = 4
    let overscrollBottom: CGFloat = 150
    let leftPadding: CGFloat = 8
    let iconSize: CGFloat = 20
    let indentWidth: CGFloat = 16
    let rowCornerRadius: CGFloat = 12
    let iconCornerRadius: CGFloat = 4
    let linkTitleFont: NSFont = NSFont.systemFont(ofSize: 14, weight: .regular)
    let folderTitleFont: NSFont = NSFont.systemFont(ofSize: 14, weight: .semibold)
    // Foreground (title/icon) and state (hover/selected/delete) colors are dynamic:
    // they resolve to black-derived values under the light appearance and white-derived
    // values under the dark appearance. Because `ListMetrics` is reconstructed on each
    // reload (and reload is triggered on `viewDidChangeEffectiveAppearance` from the
    // containing view), these values stay in sync with the effective appearance.
    let titleColor: NSColor = ThemeConstants.Appearance.dynamicColor(
        light: NSColor.black.withAlphaComponent(0.8),
        dark: NSColor.white.withAlphaComponent(0.85)
    )
    let hoverBackgroundColor: NSColor = ThemeConstants.Appearance.dynamicColor(
        light: NSColor.black.withAlphaComponent(0.06),
        dark: NSColor.white.withAlphaComponent(0.08)
    )
    let selectedBackgroundColor: NSColor = ThemeConstants.Appearance.dynamicColor(
        light: NSColor.black.withAlphaComponent(0.12),
        dark: NSColor.white.withAlphaComponent(0.15)
    )
    let deleteTintColor: NSColor = ThemeConstants.Appearance.dynamicColor(
        light: NSColor.black.withAlphaComponent(0.5),
        dark: NSColor.white.withAlphaComponent(0.6)
    )
    let iconTintColor: NSColor = ThemeConstants.Appearance.dynamicColor(
        light: NSColor.black.withAlphaComponent(0.7),
        dark: NSColor.white.withAlphaComponent(0.8)
    )
}
