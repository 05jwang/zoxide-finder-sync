import Combine
import Foundation

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isZoxideAddEnabled = "isZoxideAddEnabled"
        static let blacklist = "blacklist"
        static let debounceInterval = "debounceInterval"
        static let zoxidePath = "zoxidePath"
        static let topFolderPath = "topFolderPath"  // New Key
        static let topFolderCount = "topFolderCount"  // New Key
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

    private init() {
        let defaultTopPath = NSString(string: "~/Zoxide Top")
            .expandingTildeInPath
        defaults.register(defaults: [
            Keys.isZoxideAddEnabled: true,
            Keys.blacklist: [],
            Keys.debounceInterval: 0.75,
            Keys.zoxidePath: "",  // Default to empty string for auto-discovery
            Keys.topFolderPath: defaultTopPath,
            Keys.topFolderCount: 10,
        ])

        self.isZoxideAddEnabled = defaults.bool(forKey: Keys.isZoxideAddEnabled)
        self.blacklist = defaults.stringArray(forKey: Keys.blacklist) ?? []
        self.debounceInterval = defaults.double(forKey: Keys.debounceInterval)
        self.zoxidePath = defaults.string(forKey: Keys.zoxidePath) ?? ""
        self.topFolderPath =
            defaults.string(forKey: Keys.topFolderPath) ?? defaultTopPath
        self.topFolderCount = defaults.integer(forKey: Keys.topFolderCount)
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
}
