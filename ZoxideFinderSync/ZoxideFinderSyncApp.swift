import AppKit
import SwiftUI

@main
struct ZoxideFinderSyncApp: App {
    let observer = FinderObserver()
    @StateObject private var settings = SettingsManager.shared

    init() {
        observer.start()
        Task {
            await FileLogger.shared.log("ZoxideFinderSync App launched.")
        }
    }

    var body: some Scene {
        // The Menu Bar Icon is now the ONLY scene.
        MenuBarExtra("Zoxide Sync", systemImage: "folder.badge.gearshape") {
            Button("Open Settings & Logs") {
                SettingsWindowManager.shared.openWindow(with: settings)
            }

            Divider()

            Button("Quit ZoxideFinderSync") {
                Task {
                    await FileLogger.shared.log("App terminating via Menu Bar.")
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}

// Manages the lifecycle of the settings window to prevent multiple instances
// and ensure it doesn't open on application startup.
@MainActor
final class SettingsWindowManager: NSObject {
    static let shared = SettingsWindowManager()
    private var window: NSWindow?

    private override init() {}

    func openWindow(with settings: SettingsManager) {
        // If the window already exists, just bring it to the front
        if let existingWindow = window {
            NSApp.activate(ignoringOtherApps: true)
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
            return
        }

        // Otherwise, create a new window holding the ContentView
        let contentView = ContentView()
            .environmentObject(settings)
            // Ensure the window has a reasonable default size
            .frame(minWidth: 800, minHeight: 600)

        let hostingController = NSHostingController(rootView: contentView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        newWindow.title = "ZoxideFinderSync Settings"
        newWindow.contentViewController = hostingController
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        // Handle window closure to free up the reference
        newWindow.delegate = self

        self.window = newWindow

        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless() 
    }
}

// Keep your existing extension exactly as it was:
extension SettingsWindowManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Nil out the reference when closed so it can be cleanly recreated later
        self.window = nil
    }
}
