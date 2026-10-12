import Cocoa
import ApplicationServices
import os

/// Manages a global keyboard shortcut using a CGEvent tap.
///
/// This provides system-wide key interception, the same mechanism macOS uses for
/// shortcuts like Cmd+Space (Spotlight). Unlike Carbon's RegisterEventHotKey, this
/// approach uses the modern Core Graphics event tap API.
///
/// Requires Accessibility permissions at runtime. If permissions are not granted,
/// register() will skip event tap creation silently. AppSettings polls for permission
/// changes and calls register() again once granted.
@MainActor
final class HotkeyService {
    static let shared = HotkeyService()

    private static let logger = Logger(subsystem: "at.florianschuster.pin", category: "HotkeyService")

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var onHotkeyPressed: (() -> Void)?

    private init() {}

    /// Register the global hotkey based on current settings.
    ///
    /// Creates a CGEvent tap that monitors all key-down events system-wide,
    /// and fires `onHotkeyPressed` when the configured shortcut is detected.
    /// If Accessibility permissions have not been granted, this is a no-op.
    /// AppSettings will call register() again once the user grants permission.
    func register() {
        unregister()

        guard AXIsProcessTrusted() else {
            Self.logger.info("Accessibility permission not granted, deferring hotkey registration.")
            return
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: handleKeyDown,
            userInfo: selfPtr
        ) else {
            Self.logger.error("Failed to create event tap. Check Accessibility permissions.")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.runLoopSource = source
    }

    /// Unregister the event tap, removing it from the run loop.
    func unregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }

    deinit {
        // deinit is nonisolated, but this singleton is only deallocated
        // at app termination on the main thread.
        MainActor.assumeIsolated {
            unregister()
        }
    }
}

/// CGEvent tap callback. Defined at file scope since tapCreate requires a C function pointer.
///
/// Checks each key-down event against the configured hotkey. If matched, the event
/// is swallowed (returns nil) and `onHotkeyPressed` is fired. All other events pass through.
private func handleKeyDown(
    proxy: CGEventTapProxy,
    type: CGEventType,
    cgEvent: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(cgEvent)
    }
    let service = Unmanaged<HotkeyService>.fromOpaque(userInfo).takeUnretainedValue()

    // The system can disable taps that take too long to process events.
    // Re-enable the tap if that happens. The callback runs on the main
    // run loop, so MainActor.assumeIsolated is safe here.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated {
            if let tap = service.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(cgEvent)
    }

    // Ignore events Pin posted itself (the simulated Cmd+C in TextCaptureService),
    // so a hotkey like Cmd+C cannot re-trigger capture in a loop.
    guard cgEvent.getIntegerValueField(.eventSourceUnixProcessID) != Int64(getpid()) else {
        return Unmanaged.passUnretained(cgEvent)
    }

    // Read key code and modifiers straight from the CGEvent. This runs for every
    // keystroke on the system, so avoid allocating an NSEvent here.
    let keyCode = Int(cgEvent.getIntegerValueField(.keyboardEventKeycode))
    let currentModifiers = modifierFlags(from: cgEvent.flags)

    let (expectedModifiers, expectedKeyCode) = MainActor.assumeIsolated {
        let settings = AppSettings.shared
        return (
            NSEvent.ModifierFlags(rawValue: UInt(settings.hotkeyModifiers)).intersection(relevantModifierMask),
            settings.hotkeyKeyCode
        )
    }

    if keyCode == expectedKeyCode && currentModifiers == expectedModifiers {
        MainActor.assumeIsolated {
            service.onHotkeyPressed?()
        }
        return nil // Swallow the event
    }

    // Let all other keystrokes pass through
    return Unmanaged.passUnretained(cgEvent)
}

/// The modifier keys that take part in hotkey matching.
private let relevantModifierMask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

/// Maps CGEvent flags to the subset of NSEvent modifier flags used for matching.
private func modifierFlags(from flags: CGEventFlags) -> NSEvent.ModifierFlags {
    var result: NSEvent.ModifierFlags = []
    if flags.contains(.maskCommand) { result.insert(.command) }
    if flags.contains(.maskAlternate) { result.insert(.option) }
    if flags.contains(.maskControl) { result.insert(.control) }
    if flags.contains(.maskShift) { result.insert(.shift) }
    return result
}
