//
//  TopFolderManager.swift
//  ZoxideFinderSync
//
//  Created by Jerry Wang on 3/31/26.
//

import Foundation
import os

actor TopFolderManager {
    static let shared = TopFolderManager()
    private let fm = FileManager.default

    private init() {}

    /// Synchronizes the target directory with the latest top paths.
    func syncTopFolders(paths: [String], targetDirectory: String) async {
        let dirURL = URL(fileURLWithPath: targetDirectory)

        // 1. Ensure target directory exists
        var isDirectory: ObjCBool = false
        if !fm.fileExists(atPath: dirURL.path, isDirectory: &isDirectory) {
            do {
                try fm.createDirectory(
                    at: dirURL,
                    withIntermediateDirectories: true
                )
                await FileLogger.shared.log(
                    "Created Zoxide Top directory at \(targetDirectory)"
                )
            } catch {
                await FileLogger.shared.log(
                    "Failed to create Top directory: \(error.localizedDescription)",
                    type: .error
                )
                return
            }
        } else if !isDirectory.boolValue {
            await FileLogger.shared.log(
                "Error: Target Top directory path is a file, not a directory.",
                type: .error
            )
            return
        }

        // 2. Prepare expected state
        var expectedSymlinks: [URL: URL] = [:]  // Link URL -> Destination URL
        for (index, path) in paths.enumerated() {
            let destURL = URL(fileURLWithPath: path)
            let folderName = destURL.lastPathComponent
            // Format to keep them ordered by rank (e.g., "01 - Documents")
            let linkName = String(format: "%02d - %@", index + 1, folderName)
            let linkURL = dirURL.appendingPathComponent(linkName)
            expectedSymlinks[linkURL] = destURL
        }

        // 3. Process existing contents (Resilience & Cleanup)
        do {
            let existingItems = try fm.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.isSymbolicLinkKey]
            )

            for itemURL in existingItems {
                let resourceValues = try? itemURL.resourceValues(forKeys: [
                    .isSymbolicLinkKey
                ])
                let isSymlink = resourceValues?.isSymbolicLink == true

                if isSymlink {
                    let currentDestPath = try? fm.destinationOfSymbolicLink(
                        atPath: itemURL.path
                    )
                    let expectedDest = expectedSymlinks[itemURL]

                    if expectedDest == nil
                        || expectedDest?.path != currentDestPath
                    {
                        try fm.removeItem(at: itemURL)
                        await FileLogger.shared.log(
                            "Removed outdated symlink: \(itemURL.lastPathComponent)"
                        )
                    }
                }
                // Resiliency check: If it's NOT a symlink, ignore it.
                // This prevents us from deleting actual files a user may have dropped in this folder.
            }
        } catch {
            await FileLogger.shared.log(
                "Failed to read Top directory contents: \(error.localizedDescription)",
                type: .error
            )
            return
        }

        // 4. Create missing symlinks
        for (linkURL, destURL) in expectedSymlinks {
            if !fm.fileExists(atPath: linkURL.path) {
                do {
                    try fm.createSymbolicLink(
                        at: linkURL,
                        withDestinationURL: destURL
                    )
                    await FileLogger.shared.log(
                        "Created Top symlink: \(linkURL.lastPathComponent) -> \(destURL.path)"
                    )
                } catch {
                    await FileLogger.shared.log(
                        "Failed to create symlink for \(linkURL.lastPathComponent): \(error.localizedDescription)",
                        type: .error
                    )
                }
            }
        }
    }
}
