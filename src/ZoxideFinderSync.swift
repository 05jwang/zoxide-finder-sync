import Cocoa
import ApplicationServices

// Inherit from NSObject to allow @objc selectors for NSWorkspace notifications
class FinderObserver: NSObject {
    var lastPath: String = ""
    var observer: AXObserver?
    var finderElement: AXUIElement?
    var runLoopSource: CFRunLoopSource?

    func start() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            print("ERROR: Accessibility permissions are required.")
            print("Please grant them in System Settings -> Privacy & Security -> Accessibility, then restart.")
            exit(1)
        }

        setupWorkspaceObservers()

        // Attempt initial attachment if Finder is already running
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
        
        // Delay slightly to ensure Finder's Accessibility hierarchy is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.attachObserver(to: app.processIdentifier)
            self.evaluatePath() // Immediately evaluate in case a window opened
        }
    }

    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "com.apple.finder" else { return }

        print("Finder termination detected. Cleaning up observer...")
        cleanupObserver()
    }

    private func attachObserver(to pid: pid_t) {
        cleanupObserver() // Ensure no lingering state

        let observerCallback: AXObserverCallback = { (observer, element, notification, refcon) in
            guard let refcon = refcon else { return }
            let tracker = Unmanaged<FinderObserver>.fromOpaque(refcon).takeUnretainedValue()
            tracker.evaluatePath()
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

        // Store the run loop source so it can be cleanly removed later
        let source = AXObserverGetRunLoopSource(observer)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)

        print("Successfully attached to Finder (PID: \(pid)).")
    }

    private func cleanupObserver() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
            self.runLoopSource = nil
        }
        self.observer = nil
        self.finderElement = nil
    }

    func evaluatePath() {
        autoreleasepool {
            if let currentPath = getFrontmostFinderPath(), !currentPath.isEmpty {
                if currentPath != lastPath {
                    print("Scoped: \(currentPath)")
                    lastPath = currentPath
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

print("Starting Zoxide Finder Tracker (Resilient Event-Driven)...")
RunLoop.current.run()