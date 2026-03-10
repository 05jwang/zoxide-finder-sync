import Cocoa
import ApplicationServices

class FinderObserver {
    var lastPath: String = ""
    var observer: AXObserver?
    var finderElement: AXUIElement?

    func start() {
        // 1. Prompt for Accessibility Permissions if not granted
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            print("ERROR: Accessibility permissions are required.")
            print("Please grant them in System Settings -> Privacy & Security -> Accessibility, then restart.")
            exit(1)
        }

        // 2. Get Finder's PID
        guard let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            print("ERROR: Finder is not running.")
            exit(1)
        }
        let pid = finderApp.processIdentifier

        // 3. Define the Callback
        let observerCallback: AXObserverCallback = { (observer, element, notification, refcon) in
            guard let refcon = refcon else { return }
            // Extract the class instance from the C-pointer
            let tracker = Unmanaged<FinderObserver>.fromOpaque(refcon).takeUnretainedValue()
            tracker.evaluatePath()
        }

        // 4. Create the Observer
        var newObserver: AXObserver?
        let result = AXObserverCreate(pid, observerCallback, &newObserver)
        guard result == .success, let observer = newObserver else {
            print("ERROR: Failed to create AXObserver. Code: \(result.rawValue)")
            exit(1)
        }
        self.observer = observer

        // 5. Create AXUIElement for Finder and Register Notifications
        let finderElement = AXUIElementCreateApplication(pid)
        self.finderElement = finderElement
        
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        
        // Listen to window focus changes and navigation (which updates the window title)
        AXObserverAddNotification(observer, finderElement, kAXFocusedWindowChangedNotification as CFString, refcon)
        AXObserverAddNotification(observer, finderElement, kAXMainWindowChangedNotification as CFString, refcon)
        AXObserverAddNotification(observer, finderElement, kAXTitleChangedNotification as CFString, refcon)

        // 6. Add to RunLoop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)

        print("Starting Zoxide Finder Tracker (Event-Driven)...")
        
        // Evaluate immediately on startup to get the current state
        evaluatePath() 
    }

    func evaluatePath() {
        // Autoreleasepool ensures AppleScript memory is cleaned up per event
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

// Instantiate and start the observer
let observer = FinderObserver()
observer.start()

// Keep the command-line application alive to listen for events
RunLoop.current.run()