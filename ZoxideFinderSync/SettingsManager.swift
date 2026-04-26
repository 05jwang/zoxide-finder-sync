import Combine
import Foundation
import ServiceManagement
import os

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isZoxideAddEnabled = "isZoxideAddEnabled"
        static let blacklist = "blacklist"
        static let debounceInterval = "debounceInterval"
        static let zoxidePath = "zoxidePath"
        static let topFolderPath = "topFolderPath"
        static let topFolderCount = "topFolderCount"
        static let launchAtLogin = "launchAtLogin"
    }

    @Published var isZoxideAddEnabled: Bool {
        didSet {
            defaults.set(isZoxideAddEnabled, forKey: Keys.isZoxideAddEnabled)
            Task {
                await FileLogger.shared.log(
                    "Setting changed: Zoxide Additions Enabled = \(isZoxideAddEnabled)"
                )
            }
        }
    }

    @Published var blacklist: [String] {
        didSet {
            let sanitized = blacklist.map {
                $0.hasSuffix("/") && $0.count > 1 ? String($0.dropLast()) : $0
            }
            defaults.set(sanitized, forKey: Keys.blacklist)
            Task {
                await FileLogger.shared.log(
                    "Setting changed: Blacklist updated (Total items: \(blacklist.count))"
                )
            }
        }
    }

    @Published var debounceInterval: TimeInterval {
        didSet {
            defaults.set(debounceInterval, forKey: Keys.debounceInterval)
            Task {
                await FileLogger.shared.log(
                    "Setting changed: Debounce Interval = \(debounceInterval)s"
                )
            }
        }
    }

    @Published var zoxidePath: String {
        didSet {
            defaults.set(zoxidePath, forKey: Keys.zoxidePath)
            Task {
                await FileLogger.shared.log(
                    "Setting changed: Zoxide Path = \(zoxidePath.isEmpty ? "Auto-discovery" : zoxidePath)"
                )
            }
        }
    }

    @Published var topFolderPath: String {
        didSet {
            defaults.set(topFolderPath, forKey: Keys.topFolderPath)
            Task {
                await FileLogger.shared.log(
                    "Setting changed: Top Folder Target Directory = \(topFolderPath)"
                )
            }
        }
    }

    @Published var topFolderCount: Int {
        didSet {
            defaults.set(topFolderCount, forKey: Keys.topFolderCount)
            Task {
                await FileLogger.shared.log(
                    "Setting changed: Top Folder Count = \(topFolderCount)"
                )
            }
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            Task {
                await FileLogger.shared.log(
                    "Setting changed: Toggle Launch at Login = \(launchAtLogin)"
                )
            }

            toggleLaunchAtLogin(enabled: launchAtLogin)
        }
    }

    private init() {
        let defaultTopPath = NSString(string: "~/Zoxide Top")
            .expandingTildeInPath
        defaults.register(defaults: [
            Keys.isZoxideAddEnabled: true,
            Keys.blacklist: [],
            Keys.debounceInterval: 0.75,
            Keys.zoxidePath: "",  // Default to empty string for auto-discovery
            Keys.topFolderPath: defaultTopPath,
            Keys.topFolderCount: 20,
            Keys.launchAtLogin: false,
        ])

        self.isZoxideAddEnabled = defaults.bool(forKey: Keys.isZoxideAddEnabled)
        self.blacklist = defaults.stringArray(forKey: Keys.blacklist) ?? []
        self.debounceInterval = defaults.double(forKey: Keys.debounceInterval)
        self.zoxidePath = defaults.string(forKey: Keys.zoxidePath) ?? ""
        self.topFolderPath =
            defaults.string(forKey: Keys.topFolderPath) ?? defaultTopPath
        self.topFolderCount = defaults.integer(forKey: Keys.topFolderCount)

        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func addBlacklistEntry(_ path: String) {
        var current = blacklist
        let sanitized =
            path.hasSuffix("/") && path.count > 1
            ? String(path.dropLast()) : path
        if !current.contains(sanitized) {
            current.append(sanitized)
            blacklist = current
        }
    }

    // MARK: - App Service Registration
    private func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                    Task {
                        await FileLogger.shared.log(
                            "Successfully registered Launch at Login."
                        )
                    }
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    Task {
                        await FileLogger.shared.log(
                            "Successfully unregistered Launch at Login."
                        )
                    }
                }
            }
        } catch {
            Task {
                await FileLogger.shared.log(
                    "Failed to update SMAppService: \(error.localizedDescription)",
                    type: .error
                )
            }
            // Revert UI toggle if system registration fails
            DispatchQueue.main.async {
                self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
            }
        }
    }
}
