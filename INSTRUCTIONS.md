# ZoxideFinderSync - AI Developer Instructions

This file contains the architectural context and development workflows required to assist with ZoxideFinderSync.

## 1. Project Overview

ZoxideFinderSync is a macOS background utility that syncs macOS Finder navigation with the `zoxide` command-line tool. It monitors the active Finder window using Accessibility APIs, registers the path with `zoxide`, and generates a physical folder of symlinks pointing to the user's most frequently accessed directories.

**Tech Stack:**
* **Language:** Swift 5+ (Concurrency via `async/await` and `actor`)
* **UI Framework:** SwiftUI (Menu Bar Extra and Settings Window)
* **System APIs:** AppKit (NSWorkspace), ApplicationServices (AXObserver), Foundation (FileManager, Process).

## 2. Architecture & Data Flow
The app relies heavily on Swift Concurrency to ensure the Main Thread (UI) remains unblocked while performing shell commands and file system operations.

* **Entry Point (`ZoxideFinderSyncApp.swift`):** Launches the background observer and hosts the SwiftUI Menu Bar lifecycle.
* **Observer Engine (`ZoxideFinderSync.swift`):**
    * Uses `AXObserver` to watch for `kAXFocusedWindowChangedNotification`.
    * Debounces rapid directory changes using `Task.sleep`.
    * Executes AppleScript via `NSAppleScript` (on a detached task) to fetch the POSIX path of the Finder window.
    * Executes `zoxide add` and `zoxide query` via `Process()`.
* **State & Storage (`SettingsManager.swift`):** `@MainActor` class wrapping `UserDefaults`.
* **File System (`TopFolderManager.swift`):** An `actor` that handles idempotent creation/deletion of symlinks using `FileManager`.
* **Logging (`FileLogger.swift`):** An `actor` managing a `FileHandle` for thread-safe writing to `~/Library/Logs/ZoxideFinderSync/ZoxideFinderSync.log`.

## 3. Build & Run Instructions
1.  Open `ZoxideFinderSync.xcodeproj` in Xcode.
2.  Ensure your target is set to your local macOS machine.
3.  Build and Run (`Cmd + R`).

**CRITICAL: Accessibility Permissions Quirk**
To use `AXObserver`, the app needs Accessibility permissions.
* **Path:** System Settings -> Privacy & Security -> Accessibility.
* **Development Loop:** Every time the app is recompiled, macOS invalidates the previous permission. You *must* manually remove the old instance from the Accessibility list and let the new build request it again, or manually add the new binary.

## 4. Testing Guidelines
When generating tests for `ZoxideFinderSyncTests` or `ZoxideFinderSyncUITests`:
* **Do not execute real shell commands** in unit tests. You must abstract `Process()` calls or mock the `zoxide` binary to return predictable strings.
* **File System Mocking:** When testing `TopFolderManager`, use a temporary directory (`FileManager.default.temporaryDirectory`) instead of the user's actual `~/Zoxide Top` folder to avoid destroying user data.
* Ensure thread-safety is maintained. Await actor methods properly.

## 5. AI Assistant Rules for this Project
* **Concurrency:** Always use modern Swift concurrency (`async/await`, `Task`, `actor`). Avoid completion handlers or GCD (`DispatchQueue`) unless strictly necessary for legacy API wrapping.
* **Safety First:** If modifying `TopFolderManager.swift`, ensure destructive operations (`fm.removeItem`) are strictly fenced to symlinks only. Never delete standard directories or files.
* **Performance:** Always consider Time and Space Complexity when filtering or sorting large lists of paths from the CLI output. Keep string manipulation efficient.