import Cocoa
import ApplicationServices

class FinderObserver: NSObject {
    var lastPath: String = ""
    var observer: AXObserver?
    var finderElement: AXUIElement?
    var runLoopSource: CFRunLoopSource?
    
    // Debouncing properties
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.5 
    
    // Configuration Flags
    var isZoxideAddEnabled: Bool = true
    
    // Blacklist configuration (automatically sanitized to remove accidental trailing slashes)
    private let blacklist: [String] = [
        "/Users/jerrywang/code/2026 Spring/Enterprise Computing"
        // Add more directories here
    ].map { $0.hasSuffix("/") && $0.count > 1 ? String($0.dropLast()) : $0 }

    func start() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            print("ERROR: Accessibility permissions are required.")
            print("Please grant them in System Settings -> Privacy & Security -> Accessibility, then restart.")
            exit(1)
        }

        setupWorkspaceObservers()

        if let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
            attachObserver(to: finderApp.processIdentifier)
        } else {
            print("Finder is not currently running. Waiting for launch...")
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

        print("Finder launch detected. Attaching observer...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.attachObserver(to: app.processIdentifier)
            self.triggerDebouncedEvaluation()
        }
    }

    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "com.apple.finder" else { return }

        print("Finder termination detected. Cleaning up observer...")
        cleanupObserver()
    }

    private func attachObserver(to pid: pid_t) {
        cleanupObserver()

        let observerCallback: AXObserverCallback = { (observer, element, notification, refcon) in
            guard let refcon = refcon else { return }
            let tracker = Unmanaged<FinderObserver>.fromOpaque(refcon).takeUnretainedValue()
            tracker.triggerDebouncedEvaluation()
        }

        var newObserver: AXObserver?
        let result = AXObserverCreate(pid, observerCallback, &newObserver)
        guard result == .success, let observer = newObserver else {
            print("Failed to create AXObserver for new Finder process. Code: \(result.rawValue)")
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
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)

        print("Successfully attached to Finder (PID: \(pid)).")
    }

    private func cleanupObserver() {
        debounceWorkItem?.cancel()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    // MARK: - Zoxide Integration

    /// Attempts to locate the zoxide executable path
    private func getZoxideExecutableURL() -> URL? {
        let commonPaths = [
            "/opt/homebrew/bin/zoxide", // Apple Silicon Homebrew
            "/usr/local/bin/zoxide",    // Intel Homebrew
            "/opt/local/bin/zoxide",    // MacPorts
            "/usr/bin/zoxide"
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    /// Safely runs a zoxide command bypassing the shell to prevent injection
    private func runZoxideCommand(arguments: [String]) -> String? {
        guard let zoxideURL = getZoxideExecutableURL() else {
            print("Error: Could not locate the zoxide executable.")
            return nil
        }

        let process = Process()
        process.executableURL = zoxideURL
        process.arguments = arguments // Safely passes arguments without needing manual string escaping
        
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
            print("Failed to run zoxide: \(error)")
        }
        return nil
    }

    private func getZoxideScore(for path: String) -> Double {
        // No escaping needed! Just pass the raw path in the arguments array.
        guard let output = runZoxideCommand(arguments: ["query", "-s", path]) else { return 0.0 }
        
        let components = output.split(separator: " ", omittingEmptySubsequences: true)
        if let first = components.first, let score = Double(first) {
            return score
        }
        return 0.0
    }

    private func addZoxidePath(_ path: String) {
        // No escaping needed!
        _ = runZoxideCommand(arguments: ["add", path])
    }

    // MARK: - Path Evaluation
    
    private func isBlacklisted(path: String) -> Bool {
        for blacklistedPath in blacklist {
            // Check for exact match OR true subdirectory match
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
                    print("Ignored (Blacklisted): \(currentPath)")
                    return
                }
                
                print("Scoped: \(currentPath)")
                
                if isZoxideAddEnabled {
                    let scoreBefore = getZoxideScore(for: currentPath)
                    addZoxidePath(currentPath)
                    let scoreAfter = getZoxideScore(for: currentPath)
                    let delta = scoreAfter - scoreBefore
                    
                    print(String(format: "  -> Before: %5.2f | After: %5.2f | Change: %+.2f", scoreBefore, scoreAfter, delta))
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

let observer = FinderObserver()
observer.start()

print("Starting Zoxide Finder Tracker (With Blacklist)...")
RunLoop.current.run()