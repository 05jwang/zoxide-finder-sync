import SwiftUI

@main
struct ZoxideFinderSyncApp: App {
    // Keep a strong reference to your observer so it doesn't deallocate
    let observer = FinderObserver()
    @StateObject private var settings = SettingsManager.shared

    init() {
        // Start tracking Finder immediately upon app launch
        observer.start()

        Task {
            await FileLogger.shared.log("ZoxideFinderSync App launched.")
        }
    }

    var body: some Scene {
        // The main window for Settings and Logs
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }

        // The Menu Bar Icon
        MenuBarExtra("Zoxide Sync", systemImage: "folder.badge.gearshape") {
            Button("Open Settings & Logs") {
                // Brings the hidden UIElement app window to the foreground
                NSApp.activate(ignoringOtherApps: true)

                // If the window was closed, this forces it to reopen
                if let window = NSApplication.shared.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
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
