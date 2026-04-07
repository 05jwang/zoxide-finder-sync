import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var logText: String = "Loading logs..."
    @State private var newBlacklistPath: String = ""

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
                                Text(path)
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
                Button(action: refreshLogs) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .padding(.bottom, 5)

            TextEditor(text: .constant(logText))
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .border(Color.secondary.opacity(0.2))
        }
        .padding()
        .onAppear {
            refreshLogs()
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
