import Foundation

// Function to execute AppleScript and retrieve the frontmost Finder path
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
        } else {
            // Silently fail or log error if needed
            return nil
        }
    }
    return nil
}

// Main execution block
print("Starting Zoxide Finder Tracker (Swift)...")

var lastPath = ""

while true {
    // Use autoreleasepool to ensure temporary objects created by NSAppleScript 
    // are deallocated during each iteration of the infinite loop.
    autoreleasepool {
        if let currentPath = getFrontmostFinderPath(), !currentPath.isEmpty {
            if currentPath != lastPath {
                print("Scoped: \(currentPath)")
                lastPath = currentPath
            }
        }
    }
    
    // Sleep for 2 seconds to match the Bash POC
    Thread.sleep(forTimeInterval: 2.0)
}