import Foundation
import Combine

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let isZoxideAddEnabled = "isZoxideAddEnabled"
        static let blacklist = "blacklist"
        static let debounceInterval = "debounceInterval"
    }
    
    @Published var isZoxideAddEnabled: Bool {
        didSet {
            defaults.set(isZoxideAddEnabled, forKey: Keys.isZoxideAddEnabled)
        }
    }
    
    @Published var blacklist: [String] {
        didSet {
            // Sanitize upon setting
            let sanitized = blacklist.map { $0.hasSuffix("/") && $0.count > 1 ? String($0.dropLast()) : $0 }
            defaults.set(sanitized, forKey: Keys.blacklist)
        }
    }
    
    @Published var debounceInterval: TimeInterval {
        didSet {
            defaults.set(debounceInterval, forKey: Keys.debounceInterval)
        }
    }
    
    private init() {
        // Register default values so they exist on first launch
        defaults.register(defaults: [
            Keys.isZoxideAddEnabled: true,
            Keys.blacklist: [],
            Keys.debounceInterval: 0.75
        ])
        
        self.isZoxideAddEnabled = defaults.bool(forKey: Keys.isZoxideAddEnabled)
        self.blacklist = defaults.stringArray(forKey: Keys.blacklist) ?? []
        self.debounceInterval = defaults.double(forKey: Keys.debounceInterval)
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
