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
    static let zoxidePath = "zoxidePath"  // New Key
  }

  @Published var isZoxideAddEnabled: Bool {
    didSet { defaults.set(isZoxideAddEnabled, forKey: Keys.isZoxideAddEnabled) }
  }

  @Published var blacklist: [String] {
    didSet {
      let sanitized = blacklist.map {
        $0.hasSuffix("/") && $0.count > 1 ? String($0.dropLast()) : $0
      }
      defaults.set(sanitized, forKey: Keys.blacklist)
    }
  }

  @Published var debounceInterval: TimeInterval {
    didSet { defaults.set(debounceInterval, forKey: Keys.debounceInterval) }
  }

  // New Published Property
  @Published var zoxidePath: String {
    didSet { defaults.set(zoxidePath, forKey: Keys.zoxidePath) }
  }

  private init() {
    defaults.register(defaults: [
      Keys.isZoxideAddEnabled: true,
      Keys.blacklist: [],
      Keys.debounceInterval: 0.75,
      Keys.zoxidePath: "",  // Default to empty string for auto-discovery
    ])

    self.isZoxideAddEnabled = defaults.bool(forKey: Keys.isZoxideAddEnabled)
    self.blacklist = defaults.stringArray(forKey: Keys.blacklist) ?? []
    self.debounceInterval = defaults.double(forKey: Keys.debounceInterval)
    self.zoxidePath = defaults.string(forKey: Keys.zoxidePath) ?? ""
  }

  func addBlacklistEntry(_ path: String) {
    var current = blacklist
    let sanitized = path.hasSuffix("/") && path.count > 1 ? String(path.dropLast()) : path
    if !current.contains(sanitized) {
      current.append(sanitized)
      blacklist = current
    }
  }
}
