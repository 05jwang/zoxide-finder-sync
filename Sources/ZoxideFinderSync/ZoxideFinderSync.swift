import Cocoa
@preconcurrency import ApplicationServices

@MainActor
@main
struct ZoxideFinderSyncApp {
    static func main() {
        let observer = FinderObserver()
        observer.start()

        Task {
            await FileLogger.shared.log("Starting Zoxide Finder Tracker...")
        }
        
        RunLoop.main.run()
    }
}

@MainActor
class FinderObserver: NSObject {
    var lastPath: String = ""
    var observer: AXObserver?
    var finderElement: AXUIElement?
    var runLoopSource: CFRunLoopSource?
    
    private var debounceWorkItem: DispatchWorkItem?

    func start() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            Task {
                await FileLogger.shared.log("ERROR: Accessibility permissions required.", type: .error)
            }
            exit(1)
        }
        
        if !SettingsManager.shared.isZoxideAddEnabled {
            Task {
                await FileLogger.shared.log("WARNING: Zoxide additions are currently disabled in settings.")
            }
        }

        setupWorkspaceObservers()

        if let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
            attachObserver(to: finderApp.processIdentifier)
            triggerDebouncedEvaluation()
        } else {
            Task { await FileLogger.shared.log("Finder is not running. Waiting for launch...") }
        }
    }

    private func setupWorkspaceObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(appDidLaunch(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appDidTerminate(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    }

    @objc private func appDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "com.apple.finder" else { return }

        Task { await FileLogger.shared.log("Finder launch detected. Attaching observer...") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.attachObserver(to: app.processIdentifier)
            self.triggerDebouncedEvaluation()
        }
    }

    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "com.apple.finder" else { return }

        Task { await FileLogger.shared.log("Finder termination detected. Cleaning up observer...") }
        cleanupObserver()
    }

    private func attachObserver(to pid: pid_t) {
        cleanupObserver()

        let observerCallback: AXObserverCallback = { (observer, element, notification, refcon) in
            guard let refcon = refcon else { return }
            let tracker = Unmanaged<FinderObserver>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in
                tracker.triggerDebouncedEvaluation()
            }
        }

        var newObserver: AXObserver?
        let result = AXObserverCreate(pid, observerCallback, &newObserver)
        guard result == .success, let observer = newObserver else {
            Task { await FileLogger.shared.log("Failed to create AXObserver. Code: \(result.rawValue)", type: .error) }
            return
        }
        self.observer = observer

        let finderElement = AXUIElementCreateApplication(pid)
        self.finderElement = finderElement
        
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        
        AXObserverAddNotification(observer, finderElement, kAXFocusedWindowChangedNotification as CFString, refcon)
        AXObserverAddNotification(observer, finderElement, kAXMainWindowChangedNotification as CFString, refcon)
        AXObserverAddNotification(observer, finderElement, kAXTitleChangedNotification as CFString, refcon)

        let source = AXObserverGetRunLoopSource(observer)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)

        Task { await FileLogger.shared.log("Successfully attached to Finder (PID: \(pid)).") }
    }

    private func cleanupObserver() {
        debounceWorkItem?.cancel()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            self.runLoopSource = nil
        }
        self.observer = nil
        self.finderElement = nil
    }
    
    func triggerDebouncedEvaluation() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.evaluatePath()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + SettingsManager.shared.debounceInterval, execute: workItem)
    }

    // MARK: - Zoxide Integration

    private func getZoxideExecutableURL() -> URL? {
        let commonPaths = [
            "/opt/homebrew/bin/zoxide",
            "/usr/local/bin/zoxide",
            "/opt/local/bin/zoxide",
            "/usr/bin/zoxide"
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private func runZoxideCommand(arguments: [String]) -> String? {
        guard let zoxideURL = getZoxideExecutableURL() else {
            Task { await FileLogger.shared.log("Error: Could not locate the zoxide executable.", type: .error) }
            return nil
        }

        let process = Process()
        process.executableURL = zoxideURL
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            Task { await FileLogger.shared.log("Failed to run zoxide: \(error)", type: .error) }
        }
        return nil
    }

    private func getZoxideScore(for path: String) -> Double {
        guard let output = runZoxideCommand(arguments: ["query", "-s", path]) else { return 0.0 }
        let components = output.split(separator: " ", omittingEmptySubsequences: true)
        if let first = components.first, let score = Double(first) {
            return score
        }
        return 0.0
    }

    private func addZoxidePath(_ path: String) {
        _ = runZoxideCommand(arguments: ["add", path])
    }

    // MARK: - Path Evaluation
    
    private func isBlacklisted(path: String) -> Bool {
        // Now accesses SettingsManager instead of hardcoded array
        for blacklistedPath in SettingsManager.shared.blacklist {
            if path == blacklistedPath || path.hasPrefix(blacklistedPath + "/") {
                return true
            }
        }
        return false
    }

    func evaluatePath() {
        autoreleasepool {
            guard let rawPath = getFrontmostFinderPath(), !rawPath.isEmpty else { return }
            
            var currentPath = rawPath
            if currentPath.hasSuffix("/") && currentPath.count > 1 {
                currentPath = String(currentPath.dropLast())
            }
            
            if currentPath != lastPath {
                lastPath = currentPath
                
                if isBlacklisted(path: currentPath) {
                    Task { await FileLogger.shared.log("Ignored (Blacklisted): \(currentPath)") }
                    return
                }
                
                Task { await FileLogger.shared.log("Scoped: \(currentPath)") }
                
                if SettingsManager.shared.isZoxideAddEnabled {
                    let scoreBefore = getZoxideScore(for: currentPath)
                    addZoxidePath(currentPath)
                    let scoreAfter = getZoxideScore(for: currentPath)
                    let delta = scoreAfter - scoreBefore
                    
                    let logStr = String(format: "  -> Before: %5.2f | After: %5.2f | Change: %+.2f", scoreBefore, scoreAfter, delta)
                    Task { await FileLogger.shared.log(logStr) }
                }
            }
        }
    }

    func getFrontmostFinderPath() -> String? {
        let scriptSource = """
            tell application "Finder"
                if not (exists front window) then return ""
                try
                    set target_path to (POSIX path of (target of front window as alias))
                    return target_path
                on error
                    return ""
                end try
            end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil {
                return output.stringValue
            }
        }
        return nil
    }
}
