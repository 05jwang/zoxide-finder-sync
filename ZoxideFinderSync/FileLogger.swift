//
//  FileLogger.swift
//  ZoxideFinderSync
//
//  Created by Jerry Wang on 3/10/26.
//

import Foundation
import os

actor FileLogger {
  static let shared = FileLogger()

  private let osLog = Logger(subsystem: "com.jerrywang.ZoxideFinderSync", category: "Application")
  private var fileHandle: FileHandle?
  private let logFileURL: URL

  private init() {
    let fileManager = FileManager.default
    let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
    let logsDir = libraryDir.appendingPathComponent("Logs/ZoxideFinderSync")

    if !fileManager.fileExists(atPath: logsDir.path) {
      try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
    }

    logFileURL = logsDir.appendingPathComponent("ZoxideFinderSync.log")

    if !fileManager.fileExists(atPath: logFileURL.path) {
      fileManager.createFile(atPath: logFileURL.path, contents: nil)
    }

    do {
      fileHandle = try FileHandle(forWritingTo: logFileURL)
      try fileHandle?.seekToEnd()
    } catch {
      osLog.error("Failed to initialize file handle: \(error.localizedDescription)")
    }
  }

  func log(_ message: String, type: OSLogType = .default) {
    // 1. Log to macOS Console
    osLog.log(level: type, "\(message)")

    // 2. Log to File for future GUI
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logEntry = "[\(timestamp)] \(message)\n"

    if let data = logEntry.data(using: .utf8) {
      do {
        try fileHandle?.seekToEnd()
        try fileHandle?.write(contentsOf: data)
      } catch {
        osLog.error("Failed to write to log file: \(error.localizedDescription)")
      }
    }
  }

  // Allows retrieving logs for the future GUI
  func readLogs() -> String {
    do {
      return try String(contentsOf: logFileURL, encoding: .utf8)
    } catch {
      return "Failed to read logs: \(error.localizedDescription)"
    }
  }
}
