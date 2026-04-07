//
//  LogTextView.swift
//  ZoxideFinderSync
//
//  Created by Jerry Wang on 4/7/26.
//

import AppKit
import SwiftUI

// MARK: - AppKit Log Text View
struct LogTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var isAutoScrolling: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.autoresizingMask = [.width]
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.textColor
        textView.font = NSFont.monospacedSystemFont(
            ofSize: 12,
            weight: .regular
        )
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView

        // Listen for manual user scrolling
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleUserScroll),
            name: NSScrollView.didLiveScrollNotification,
            object: scrollView
        )

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        // Only update if the text actually changed to prevent unnecessary layout cycles
        if textView.string != text {
            textView.string = text
        }

        if isAutoScrolling {
            textView.scrollToEndOfDocument(nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: LogTextView

        init(_ parent: LogTextView) {
            self.parent = parent
        }

        @objc func handleUserScroll(_ notification: Notification) {
            // If the user starts scrolling manually, disable auto-scroll
            if parent.isAutoScrolling {
                DispatchQueue.main.async {
                    self.parent.isAutoScrolling = false
                }
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
