# Zoxide Finder Sync - AI Assistant Instructions

## Project Overview
`ZoxideFinderSync` is a macOS background utility designed to synchronize frecency data between the `zoxide` terminal utility and the macOS Finder. It observes active Finder windows and automatically adds the focused directories to the local `zoxide` database.

**Primary Tech Stack:** Swift (macOS), AppleScript, Bash (for deployment).

## Architecture & Core Files
The project logic resides in `Sources/ZoxideFinderSync/`:

1.  **`ZoxideFinderSync.swift`**: The entry point. Uses `AXObserver` to track the frontmost Finder window. It extracts the path via AppleScript and uses `Process()` to execute `zoxide add <path>`.
2.  **`SettingsManager.swift`**: Manages user defaults (`UserDefaults`). Controls the debounce timer, a master toggle (`isZoxideAddEnabled`), and a directory `blacklist`. Built with Combine (`@Published`) to support a future SwiftUI settings window.
3.  **`FileLogger.swift`**: An actor-based thread-safe logger writing to `osLog` and a local file at `~/Library/Logs/ZoxideFinderSync/ZoxideFinderSync.log`.

## Environment & Build Rules

* **Development:** The application is developed, built, and run using **Xcode**. When suggesting code modifications, ensure they are compatible with standard Xcode build processes.
* **Deployment:** The project includes an `install.sh` and `uninstall.sh` script. `install.sh` compiles a release binary using `swift build -c release`, generates a dynamic `.plist` file, and registers the app as a macOS background daemon via `launchctl`.
* **Paths:** The installation directory is `~/.local/bin/ZoxideFinderSync`.

## Testing & Debugging Directives for AI

If I ask you to help debug an issue or add a feature, please adhere to the following context:

1.  **Accessibility Permissions:** The app requires macOS Accessibility permissions. If debugging silent failures, always consider whether permissions were dropped or denied (`AXIsProcessTrustedWithOptions`).
2.  **Logs:** Assume logs can be checked via `tail -f ~/Library/Logs/ZoxideFinderSync/ZoxideFinderSync.log`. If adding complex logic, implement `FileLogger.shared.log()` statements to aid in debugging.
3.  **zoxide Executable:** The app searches for the `zoxide` binary in standard locations (Homebrew, MacPorts, etc.). If debugging execution errors, consider environment variable `$PATH` limitations when running under `launchd`.
4.  **Debouncing:** Ensure any new observation logic respects or utilizes the existing `DispatchWorkItem` debounce mechanism in `ZoxideFinderSync.swift`.
