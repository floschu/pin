import ApplicationServices
import AppKit
import Carbon.HIToolbox
import os

/// Captures selected text from the frontmost application.
///
/// Uses a two-stage strategy:
/// 1. Accessibility API (fast, non-destructive, but only works in apps that
///    properly expose kAXSelectedTextAttribute).
/// 2. Simulated Cmd+C (works in virtually all apps, including browsers and
///    Electron apps, at the cost of briefly touching the clipboard).
enum TextCaptureService {
    private static let logger = Logger(subsystem: "at.florianschuster.pin", category: "TextCapture")

    /// Attempt to read the selected text from the currently focused UI element.
    /// Calls `completion` on the main thread with the captured text, or nil.
    ///
    /// The completion-based API is required because the Cmd+C fallback must
    /// return control to the run loop so the simulated key events can flow
    /// through the CGEvent tap to the target app.
    @MainActor
    static func captureSelectedText(completion: @escaping @Sendable (String?) -> Void) {
        // Try the Accessibility API first (instant, doesn't touch the clipboard).
        if let text = captureViaAccessibility() {
            completion(text)
            return
        }

        // Fall back to simulating Cmd+C and reading the clipboard.
        captureViaClipboard(completion: completion)
    }

    // MARK: - Accessibility

    /// Query the system-wide focused element directly for its selected text.
    private static func captureViaAccessibility() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        // Get the focused UI element directly from the system-wide element.
        var focusedValue: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusResult == .success else {
            logger.info("AX focused element query failed: \(focusResult.rawValue, privacy: .public)")
            return nil
        }

        // Read the selected text attribute from the focused element.
        guard let focusedValue else {
            logger.info("AX focused element was nil")
            return nil
        }
        guard CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            logger.info("AX focused element was not an AXUIElement")
            return nil
        }
        let element = unsafeDowncast(focusedValue, to: AXUIElement.self)
        var selectedValue: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        )
        guard textResult == .success else {
            logger.info("AX selected text query failed: \(textResult.rawValue, privacy: .public)")
            return nil
        }

        let rawText: String?
        if let text = selectedValue as? String {
            rawText = text
        } else if let attributed = selectedValue as? NSAttributedString {
            rawText = attributed.string
        } else {
            logger.info("AX selected text returned unsupported type")
            return nil
        }

        let trimmed = (rawText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            logger.info("AX returned empty selected text")
            return nil
        }
        logger.debug("AX captured \(trimmed.count, privacy: .public) chars")
        return trimmed
    }

    // MARK: - Clipboard (Cmd+C simulation)

    /// Simulate Cmd+C, wait for the clipboard to update, then read the text.
    ///
    /// This MUST be async: we need to return control to the run loop so the
    /// simulated key events can pass through the CGEvent tap and reach the
    /// target application. Blocking with Thread.sleep inside the tap callback
    /// would deadlock the event pipeline.
    @MainActor
    private static func captureViaClipboard(completion: @escaping @Sendable (String?) -> Void) {
        let pasteboard = NSPasteboard.general

        // Snapshot current clipboard so we can restore it afterwards.
        let previousChangeCount = pasteboard.changeCount
        let savedItems = snapshotPasteboard(pasteboard)

        // Simulate Cmd+C. The events are posted to the HID layer and will
        // flow through the event system once we return to the run loop.
        simulateCopy()

        // Poll the clipboard until the target app has processed the copy command,
        // or give up after the timeout. Slow apps (Electron, remote desktops) can
        // need several hundred milliseconds.
        pollClipboard(pasteboard, previousChangeCount: previousChangeCount, attempt: 0) { captureChangeCount in
            // If the clipboard didn't change, there was nothing to copy.
            guard let captureChangeCount else {
                logger.info("Cmd+C fallback: clipboard unchanged")
                completion(nil)
                return
            }

            let copied = pasteboard.string(forType: .string)
            if copied == nil {
                logger.info("Cmd+C fallback: no string on clipboard")
                completion(nil)
                restorePasteboardIfSafe(
                    pasteboard,
                    from: savedItems,
                    expectedChangeCount: captureChangeCount,
                    expectedString: nil
                )
                return
            }

            let trimmed = (copied ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                logger.info("Cmd+C fallback: copied text was empty")
                completion(nil)
                restorePasteboardIfSafe(
                    pasteboard,
                    from: savedItems,
                    expectedChangeCount: captureChangeCount,
                    expectedString: copied
                )
                return
            }

            logger.debug("Cmd+C fallback captured \(trimmed.count, privacy: .public) chars")
            completion(trimmed)
            restorePasteboardIfSafe(
                pasteboard,
                from: savedItems,
                expectedChangeCount: captureChangeCount,
                expectedString: copied
            )
        }
    }

    private static let clipboardPollInterval: TimeInterval = 0.05
    private static let clipboardPollAttempts = 8

    /// Calls `completion` with the new change count once the clipboard changes,
    /// or with nil after the last attempt.
    @MainActor
    private static func pollClipboard(
        _ pasteboard: NSPasteboard,
        previousChangeCount: Int,
        attempt: Int,
        completion: @escaping @MainActor (Int?) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + clipboardPollInterval) {
            MainActor.assumeIsolated {
                let changeCount = pasteboard.changeCount
                if changeCount != previousChangeCount {
                    completion(changeCount)
                } else if attempt + 1 < clipboardPollAttempts {
                    pollClipboard(pasteboard, previousChangeCount: previousChangeCount, attempt: attempt + 1, completion: completion)
                } else {
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Pasteboard helpers

    private static func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        pasteboard.pasteboardItems?.compactMap { item in
            var dict = [NSPasteboard.PasteboardType: Data]()
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict.isEmpty ? nil : dict
        } ?? []
    }

    private static func restorePasteboard(_ pasteboard: NSPasteboard, from items: [[NSPasteboard.PasteboardType: Data]]) {
        pasteboard.clearContents()
        for itemDict in items {
            let item = NSPasteboardItem()
            for (type, data) in itemDict {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }
    }

    private static func restorePasteboardIfSafe(
        _ pasteboard: NSPasteboard,
        from items: [[NSPasteboard.PasteboardType: Data]],
        expectedChangeCount: Int,
        expectedString: String?
    ) {
        guard pasteboard.changeCount == expectedChangeCount else {
            logger.info("Cmd+C fallback: clipboard changed, not restoring")
            return
        }

        if let expectedString = expectedString {
            guard pasteboard.string(forType: .string) == expectedString else {
                logger.info("Cmd+C fallback: clipboard content changed, not restoring")
                return
            }
        }

        restorePasteboard(pasteboard, from: items)
    }

    /// Post a Cmd+C key event pair (key-down then key-up) to the HID event tap.
    private static func simulateCopy() {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        else {
            logger.error("Failed to create CGEvent for Cmd+C simulation")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        let tap = CGEventTapLocation.cghidEventTap
        keyDown.post(tap: tap)
        keyUp.post(tap: tap)
    }

    // MARK: - Permissions

    /// Check if the app has accessibility permissions.
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user for accessibility permissions.
    /// Triggers the system dialog that opens System Settings to the correct
    /// Privacy > Accessibility page.
    static func requestAccessibilityPermission() {
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt" as NSString: true]
        AXIsProcessTrustedWithOptions(options)
    }

    /// Remove Pin's Accessibility entry, then prompt for permission again.
    ///
    /// macOS ties the entry to the code signature. Every ad-hoc signed build has a
    /// new signature, so after an update the old entry still shows as enabled in
    /// System Settings but no longer applies. Resetting removes the stale entry so
    /// the prompt can add a fresh one.
    static func resetAndRequestAccessibilityPermission() {
        if let bundleID = Bundle.main.bundleIdentifier {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", "Accessibility", bundleID]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            if (try? process.run()) != nil {
                process.waitUntilExit()
            } else {
                logger.error("Failed to run tccutil to reset Accessibility permission")
            }
        }
        requestAccessibilityPermission()
    }
}
