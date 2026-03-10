# ZoxideFinderSync: AI Workflow & Development Instructions

## 1. Project Overview

ZoxideFinderSync is a macOS background utility written in Swift. It observes the active macOS Finder window using the Accessibility API (`AXObserver`) and automatically adds the current directory to `zoxide` (a smarter `cd` command) to keep its database updated with GUI navigation.

**Core Technologies:** Swift, macOS Accessibility API (ApplicationServices), shell scripting (`zoxide`).

## 2. Project Structure

When suggesting file modifications or analyzing paths, refer to the following repository structure:

```text
.
├── bin
│   └── ZoxideFinderSync.app
│       └── Contents
│           ├── Info.plist
│           ├── MacOS
│           │   └── ZoxideFinderSync  <-- Compiled Executable
│           └── Resources
├── LICENSE
├── README.md
├── scripts
│   └── zoxide_finder_tracker.sh
└── src
    └── ZoxideFinderSync.swift        <-- Main Source Code

```

## 3. Build Instructions

The project is built directly using the Swift compiler (`swiftc`). No Xcode project file (`.xcodeproj`) or Swift Package Manager (`Package.swift`) is currently required.

To compile the source code, run the following command from the root directory:

```bash
swiftc src/ZoxideFinderSync.swift -o bin/ZoxideFinderSync.app/Contents/MacOS/ZoxideFinderSync

```

## 4. Execution & Permissions

To run the compiled application, execute the binary directly from the root directory:

```bash
./bin/ZoxideFinderSync.app/Contents/MacOS/ZoxideFinderSync

```

### Critical Runtime Requirement: Accessibility Permissions

Because this application hooks into the macOS Accessibility API to monitor Finder, **it will fail if it lacks system permissions.** Upon the first execution, the user MUST grant Accessibility access. If debugging a failure where the observer isn't attaching to Finder, verify permissions first:

1. Open **System Settings** -> **Privacy & Security** -> **Accessibility**. 2. Ensure the terminal emulator running the executable (e.g., Terminal, iTerm2, Kitty, Ghostty) is toggled ON.
2. Restart the application.
