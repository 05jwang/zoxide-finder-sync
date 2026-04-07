import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var logText: String = "Loading logs..."
    @State private var newBlacklistPath: String = ""
    @State private var isAutoScrolling: Bool = true

    var body: some View {
        TabView {
            settingsTab
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }

            logsTab
                .tabItem {
                    Label("Logs", systemImage: "doc.text")
                }
        }
        .padding()
        .frame(minWidth: 550, minHeight: 450)
    }

    // MARK: - Settings Tab
    private var settingsTab: some View {
        Form {

            Section(header: Text("General").font(.headline)) {
                Toggle(
                    "Enable Zoxide Additions",
                    isOn: $settings.isZoxideAddEnabled
                )

                Stepper(
                    value: $settings.debounceInterval,
                    in: 0.1...5.0,
                    step: 0.25
                ) {
                    Text(
                        "Debounce Interval: \(settings.debounceInterval, specifier: "%.2f")s"
                    )
                }
            }
            .padding(.bottom, 10)

            Section(header: Text("Paths & Configuration").font(.headline)) {
                TextField(
                    "Custom Zoxide Executable Path",
                    text: $settings.zoxidePath
                )
                .textFieldStyle(.roundedBorder)
                .help(
                    "Leave blank for auto-discovery (/opt/homebrew/bin/zoxide, etc.)"
                )

                TextField(
                    "Top Folders Target Directory",
                    text: $settings.topFolderPath
                )
                .textFieldStyle(.roundedBorder)

                Stepper(value: $settings.topFolderCount, in: 1...50) {
                    Text("Top Folder Count: \(settings.topFolderCount)")
                }
            }
            .padding(.bottom, 10)

            Section(header: Text("Path Blacklist").font(.headline)) {
                HStack {
                    TextField(
                        "Enter path to ignore (e.g., /Volumes/Backup)",
                        text: $newBlacklistPath
                    )
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addBlacklistEntry() }

                    Button("Add") {
                        addBlacklistEntry()
                    }
                    .disabled(
                        newBlacklistPath.trimmingCharacters(in: .whitespaces)
                            .isEmpty
                    )
                }

                List {
                    if settings.blacklist.isEmpty {
                        Text("No blacklisted paths.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(settings.blacklist, id: \.self) { path in
                            HStack {
                                let exists = FileManager.default.fileExists(
                                    atPath: path
                                )

                                Text(path)
                                    .foregroundColor(exists ? .primary : .red)
                                    .help(
                                        exists
                                            ? ""
                                            : "Warning: Path does not currently exist."
                                    )

                                Spacer()
                                Button(action: {
                                    settings.blacklist.removeAll { $0 == path }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(minHeight: 100)
                .border(Color.secondary.opacity(0.2))
            }
        }
        .padding()
    }

    // MARK: - Logs Tab
    private var logsTab: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Application Logs")
                    .font(.headline)

                Spacer()

                if !isAutoScrolling {
                    Button(action: {
                        isAutoScrolling = true
                        // Trigger a slight text update or just rely on state change to flush the view
                        logText += ""
                    }) {
                        Label(
                            "Resume Auto-Scroll",
                            systemImage: "arrow.down.to.line"
                        )
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 10)
                }

            }
            .padding(.bottom, 5)

            // REPLACED: TextEditor with our custom LogTextView
            LogTextView(text: $logText, isAutoScrolling: $isAutoScrolling)
                .border(Color.secondary.opacity(0.2))
                // Append new logs dynamically as they are written
                .onReceive(
                    NotificationCenter.default.publisher(for: .newLogEntry)
                ) { notification in
                    if let newLog = notification.object as? String {
                        logText += newLog
                    }
                }
        }
        .padding()
        .onAppear {
            refreshLogs()
            // Reset auto-scroll when the tab appears
            isAutoScrolling = true
        }
    }

    // MARK: - Helpers
    private func addBlacklistEntry() {
        let trimmed = newBlacklistPath.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            settings.addBlacklistEntry(trimmed)
            newBlacklistPath = ""
        }
    }

    private func refreshLogs() {
        Task {
            logText = await FileLogger.shared.readLogs()
        }
    }
}
