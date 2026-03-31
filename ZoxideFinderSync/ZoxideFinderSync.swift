@preconcurrency import ApplicationServices
import Cocoa
import os

@MainActor
class FinderObserver: NSObject {
    var lastPath: String = ""
    var observer: AXObserver?
    var finderElement: AXUIElement?
    var runLoopSource: CFRunLoopSource?

    private var evaluationTask: Task<Void, Never>?

    func start() {
        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            Task {
                await FileLogger.shared.log(
                    "ERROR: Accessibility permissions required.",
                    type: .error
                )
            }
            exit(1)
        }

        if !SettingsManager.shared.isZoxideAddEnabled {
            Task {
                await FileLogger.shared.log(
                    "WARNING: Zoxide additions are currently disabled in settings."
                )
            }
        }

        setupWorkspaceObservers()

        if let finderApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.finder"
        }) {
            attachObserver(to: finderApp.processIdentifier)
            triggerDebouncedEvaluation()
        } else {
            Task {
                await FileLogger.shared.log(
                    "Finder is not running. Waiting for launch..."
                )
            }
        }
    }

    private func setupWorkspaceObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(
            self,
            selector: #selector(appDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(appDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    @objc private func appDidLaunch(_ notification: Notification) {
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
            app.bundleIdentifier == "com.apple.finder"
        else { return }

        Task {
            await FileLogger.shared.log(
                "Finder launch detected. Attaching observer..."
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.attachObserver(to: app.processIdentifier)
            self.triggerDebouncedEvaluation()
        }
    }

    @objc private func appDidTerminate(_ notification: Notification) {
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
            app.bundleIdentifier == "com.apple.finder"
        else { return }

        Task {
            await FileLogger.shared.log(
                "Finder termination detected. Cleaning up observer..."
            )
        }
        cleanupObserver()
    }

    private func attachObserver(to pid: pid_t) {
        cleanupObserver()

        let observerCallback: AXObserverCallback = {
            (observer, element, notification, refcon) in
            guard let refcon = refcon else { return }
            let tracker = Unmanaged<FinderObserver>.fromOpaque(refcon)
                .takeUnretainedValue()
            Task { @MainActor in
                tracker.triggerDebouncedEvaluation()
            }
        }

        var newObserver: AXObserver?
        let result = AXObserverCreate(pid, observerCallback, &newObserver)
        guard result == .success, let observer = newObserver else {
            Task {
                await FileLogger.shared.log(
                    "Failed to create AXObserver. Code: \(result.rawValue)",
                    type: .error
                )
            }
            return
        }
        self.observer = observer

        let finderElement = AXUIElementCreateApplication(pid)
        self.finderElement = finderElement

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        AXObserverAddNotification(
            observer,
            finderElement,
            kAXFocusedWindowChangedNotification as CFString,
            refcon
        )
        AXObserverAddNotification(
            observer,
            finderElement,
            kAXMainWindowChangedNotification as CFString,
            refcon
        )
        AXObserverAddNotification(
            observer,
            finderElement,
            kAXTitleChangedNotification as CFString,
            refcon
        )

        let source = AXObserverGetRunLoopSource(observer)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)

        Task {
            await FileLogger.shared.log(
                "Successfully attached to Finder (PID: \(pid))."
            )
        }
    }

    private func cleanupObserver() {
        evaluationTask?.cancel()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            self.runLoopSource = nil
        }
        self.observer = nil
        self.finderElement = nil
    }

    func triggerDebouncedEvaluation() {
        evaluationTask?.cancel()

        let interval = SettingsManager.shared.debounceInterval

        evaluationTask = Task {
            do {
                // Task.sleep uses nanoseconds. This yields the thread instead of blocking.
                try await Task.sleep(
                    nanoseconds: UInt64(interval * 1_000_000_000)
                )
                await evaluatePath()
            } catch {
                // Task was cancelled before sleep finished; do nothing.
            }
        }
    }
    // MARK: - Zoxide Integration

    private func getZoxideExecutableURL() -> URL? {
        // 1. Check user-defined custom path first
        let customPath = SettingsManager.shared.zoxidePath
        if !customPath.isEmpty
            && FileManager.default.fileExists(atPath: customPath)
        {
            return URL(fileURLWithPath: customPath)
        }

        // 2. Fallback to common paths
        let commonPaths = [
            "/opt/homebrew/bin/zoxide",
            "/usr/local/bin/zoxide",
            "/opt/local/bin/zoxide",
            "/usr/bin/zoxide",
        ]
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    // Detached task to prevent Process.waitUntilExit() from freezing the MainActor
    nonisolated private func runZoxideCommand(
        executableURL: URL,
        arguments: [String]
    ) async
        -> String?
    {
        return await Task.detached {
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    return String(data: data, encoding: .utf8)?
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                }
            } catch {
                Task {
                    await FileLogger.shared.log(
                        "Failed to run zoxide: \(error)",
                        type: .error
                    )
                }
            }
            return nil
        }.value
    }

    private func getZoxideScore(executableURL: URL, for path: String) async
        -> Double
    {
        guard
            let output = await runZoxideCommand(
                executableURL: executableURL,
                arguments: ["query", "-s", path]
            )
        else { return 0.0 }
        let components = output.split(
            separator: " ",
            omittingEmptySubsequences: true
        )
        if let first = components.first, let score = Double(first) {
            return score
        }
        return 0.0
    }
    private func addZoxidePath(executableURL: URL, _ path: String) async {
        _ = await runZoxideCommand(
            executableURL: executableURL,
            arguments: ["add", path]
        )
    }
    // MARK: - Path Evaluation

    private func getZoxideTopPaths(executableURL: URL, limit: Int) async
        -> [String]
    {
        guard limit > 0 else { return [] }
        guard
            let output = await runZoxideCommand(
                executableURL: executableURL,
                arguments: ["query", "-l"]
            )
        else { return [] }

        let lines = output.split(
            separator: "\n",
            omittingEmptySubsequences: true
        ).map(String.init)
        return Array(lines.prefix(limit))
    }

    private func isBlacklisted(path: String) -> Bool {
        let topFolder = NSString(string: SettingsManager.shared.topFolderPath)
            .expandingTildeInPath
        let sanitizedTopFolder =
            topFolder.hasSuffix("/") && topFolder.count > 1
            ? String(topFolder.dropLast()) : topFolder

        if path == sanitizedTopFolder
            || path.hasPrefix(sanitizedTopFolder + "/")
        {
            return true
        }
        for blacklistedPath in SettingsManager.shared.blacklist {
            if path == blacklistedPath || path.hasPrefix(blacklistedPath + "/")
            {
                return true
            }
        }
        return false
    }
    func evaluatePath() async {
        // We await the detached AppleScript execution
        guard let rawPath = await fetchFrontmostFinderPath(), !rawPath.isEmpty
        else { return }

        var currentPath = rawPath
        if currentPath.hasSuffix("/") && currentPath.count > 1 {
            currentPath = String(currentPath.dropLast())
        }

        if currentPath != lastPath {
            lastPath = currentPath

            if isBlacklisted(path: currentPath) {
                await FileLogger.shared.log(
                    "Ignored (Blacklisted): \(currentPath)"
                )
                return
            }

            await FileLogger.shared.log("Scoped: \(currentPath)")

            if SettingsManager.shared.isZoxideAddEnabled {
                guard let zoxideURL = getZoxideExecutableURL() else {
                    await FileLogger.shared.log(
                        "Error: Could not locate the zoxide executable.",
                        type: .error
                    )
                    return
                }

                // Await the scores without locking up the UI
                let scoreBefore = await getZoxideScore(
                    executableURL: zoxideURL,
                    for: currentPath
                )
                await addZoxidePath(executableURL: zoxideURL, currentPath)
                let scoreAfter = await getZoxideScore(
                    executableURL: zoxideURL,
                    for: currentPath
                )
                let delta = scoreAfter - scoreBefore

                let logStr = String(
                    format: "  -> Before: %5.2f | After: %5.2f | Change: %+.2f",
                    scoreBefore,
                    scoreAfter,
                    delta
                )
                await FileLogger.shared.log(logStr)

                let limit = SettingsManager.shared.topFolderCount
                let targetDir = SettingsManager.shared.topFolderPath
                let topPaths = await getZoxideTopPaths(
                    executableURL: zoxideURL,
                    limit: limit
                )
                await TopFolderManager.shared.syncTopFolders(
                    paths: topPaths,
                    targetDirectory: targetDir
                )
            }
        }
    }

    nonisolated private func fetchFrontmostFinderPath() async -> String? {
        return await Task.detached {
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
                if let error = error {
                    Task {
                        await FileLogger.shared.log(
                            "AppleScript Error: \(error)",
                            type: .error
                        )
                    }
                    return nil
                }
                return output.stringValue
            }
            return nil
        }.value
    }
}
