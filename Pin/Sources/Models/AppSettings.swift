import Foundation
import SwiftUI
import Carbon.HIToolbox
import ApplicationServices

/// All user-configurable settings, persisted via UserDefaults.
@MainActor @Observable
final class AppSettings {
    static let shared = AppSettings()

    // MARK: - Reading

    var wordsPerMinute: Int {
        didSet { UserDefaults.standard.set(wordsPerMinute, forKey: "wordsPerMinute") }
    }

    var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }

    var fontFamily: String {
        didSet {
            let trimmed = fontFamily.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != fontFamily {
                fontFamily = trimmed
                return
            }
            UserDefaults.standard.set(fontFamily, forKey: "fontFamily")
        }
    }

    // MARK: - ORP

    var orpEnabled: Bool {
        didSet { UserDefaults.standard.set(orpEnabled, forKey: "orpEnabled") }
    }

    var orpColorEnabled: Bool {
        didSet { UserDefaults.standard.set(orpColorEnabled, forKey: "orpColorEnabled") }
    }

    private var orpColorResolved: Color.Resolved

    var orpColor: Color {
        get { Color(orpColorResolved) }
        set {
            orpColorResolved = newValue.resolve(in: EnvironmentValues())
            if let data = try? JSONEncoder().encode(orpColorResolved) {
                UserDefaults.standard.set(data, forKey: "orpColor")
            }
        }
    }

    var orpSideOpacity: Double {
        didSet { UserDefaults.standard.set(orpSideOpacity, forKey: "orpSideOpacity") }
    }

    var showPinIndicator: Bool {
        didSet { UserDefaults.standard.set(showPinIndicator, forKey: "showPinIndicator") }
    }

    // MARK: - Pausing

    var pauseAtSentenceEnd: Bool {
        didSet { UserDefaults.standard.set(pauseAtSentenceEnd, forKey: "pauseAtSentenceEnd") }
    }

    var pauseMultiplier: Double {
        didSet { UserDefaults.standard.set(pauseMultiplier, forKey: "pauseMultiplier") }
    }

    var pauseAtClauseBoundary: Bool {
        didSet { UserDefaults.standard.set(pauseAtClauseBoundary, forKey: "pauseAtClauseBoundary") }
    }

    var clausePauseMultiplier: Double {
        didSet { UserDefaults.standard.set(clausePauseMultiplier, forKey: "clausePauseMultiplier") }
    }

    // MARK: - Appearance

    var unfocusedOpacity: Double {
        didSet { UserDefaults.standard.set(unfocusedOpacity, forKey: "unfocusedOpacity") }
    }

    var showKeyboardHints: Bool {
        didSet { UserDefaults.standard.set(showKeyboardHints, forKey: "showKeyboardHints") }
    }

    var showWPM: Bool {
        didSet { UserDefaults.standard.set(showWPM, forKey: "showWPM") }
    }

    var showWordCount: Bool {
        didSet { UserDefaults.standard.set(showWordCount, forKey: "showWordCount") }
    }

    // MARK: - Behavior

    var dismissOnClickOutside: Bool {
        didSet { UserDefaults.standard.set(dismissOnClickOutside, forKey: "dismissOnClickOutside") }
    }

    // MARK: - Hotkey

    var hotkeyModifiers: Int {
        didSet { UserDefaults.standard.set(hotkeyModifiers, forKey: "hotkeyModifiers") }
    }

    var hotkeyKeyCode: Int {
        didSet { UserDefaults.standard.set(hotkeyKeyCode, forKey: "hotkeyKeyCode") }
    }

    // MARK: - Advanced

    var speedVariability: Bool {
        didSet { UserDefaults.standard.set(speedVariability, forKey: "speedVariability") }
    }

    var stopwordSkipping: Bool {
        didSet { UserDefaults.standard.set(stopwordSkipping, forKey: "stopwordSkipping") }
    }

    var rampUp: Bool {
        didSet { UserDefaults.standard.set(rampUp, forKey: "rampUp") }
    }

    var rampUpWords: Int {
        didSet { UserDefaults.standard.set(rampUpWords, forKey: "rampUpWords") }
    }

    // MARK: - Onboarding

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        self.hasCompletedOnboarding = defaults.object(forKey: "hasCompletedOnboarding") as? Bool ?? false
        self.wordsPerMinute = defaults.object(forKey: "wordsPerMinute") as? Int ?? 300
        self.fontSize = defaults.object(forKey: "fontSize") as? Double ?? 36.0
        self.fontFamily = defaults.string(forKey: "fontFamily")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        self.orpEnabled = defaults.object(forKey: "orpEnabled") as? Bool ?? true
        self.orpColorEnabled = defaults.object(forKey: "orpColorEnabled") as? Bool ?? true
        if let data = defaults.data(forKey: "orpColor"),
           let resolved = try? JSONDecoder().decode(Color.Resolved.self, from: data) {
            self.orpColorResolved = resolved
        } else {
            // Default: red (#FF2600)
            self.orpColorResolved = Color.Resolved(red: 1.0, green: 0.149, blue: 0.0)
        }
        self.orpSideOpacity = defaults.object(forKey: "orpSideOpacity") as? Double ?? 0.5
        self.showPinIndicator = defaults.object(forKey: "showPinIndicator") as? Bool ?? false

        self.pauseAtSentenceEnd = defaults.object(forKey: "pauseAtSentenceEnd") as? Bool ?? true
        self.pauseMultiplier = defaults.object(forKey: "pauseMultiplier") as? Double ?? 1.5
        self.pauseAtClauseBoundary = defaults.object(forKey: "pauseAtClauseBoundary") as? Bool ?? true
        self.clausePauseMultiplier = defaults.object(forKey: "clausePauseMultiplier") as? Double ?? 1.3

        self.unfocusedOpacity = defaults.object(forKey: "unfocusedOpacity") as? Double ?? 0.4
        self.showKeyboardHints = defaults.object(forKey: "showKeyboardHints") as? Bool ?? true
        self.showWPM = defaults.object(forKey: "showWPM") as? Bool ?? true
        self.showWordCount = defaults.object(forKey: "showWordCount") as? Bool ?? true
        self.dismissOnClickOutside = defaults.object(forKey: "dismissOnClickOutside") as? Bool ?? true

        // Default: Option + Space
        self.hotkeyModifiers = defaults.object(forKey: "hotkeyModifiers") as? Int ?? Int(NSEvent.ModifierFlags.option.rawValue)
        self.hotkeyKeyCode = defaults.object(forKey: "hotkeyKeyCode") as? Int ?? kVK_Space

        self.speedVariability = defaults.object(forKey: "speedVariability") as? Bool ?? false
        self.stopwordSkipping = defaults.object(forKey: "stopwordSkipping") as? Bool ?? false
        self.rampUp = defaults.object(forKey: "rampUp") as? Bool ?? true
        self.rampUpWords = defaults.object(forKey: "rampUpWords") as? Int ?? 5

        // Start polling accessibility permission status
        self.hasAccessibilityPermission = AXIsProcessTrusted()
        startAccessibilityPolling()
    }

    // MARK: - Accessibility

    var hasAccessibilityPermission: Bool = false

    private var accessibilityTimer: Timer?

    private static let fastAccessibilityPollInterval: TimeInterval = 1.0
    private static let slowAccessibilityPollInterval: TimeInterval = 30.0

    private func startAccessibilityPolling() {
        let interval = hasAccessibilityPermission ?
            Self.slowAccessibilityPollInterval : Self.fastAccessibilityPollInterval
        scheduleAccessibilityPolling(interval: interval)
    }

    private func scheduleAccessibilityPolling(interval: TimeInterval) {
        accessibilityTimer?.invalidate()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                let granted = AXIsProcessTrusted()
                if self.hasAccessibilityPermission != granted {
                    self.hasAccessibilityPermission = granted
                    // When permission is newly granted, re-register the hotkey.
                    // CGEvent.tapCreate() requires Accessibility permissions, so
                    // the initial register() call at launch may have failed.
                    if granted {
                        HotkeyService.shared.register()
                        self.scheduleAccessibilityPolling(interval: Self.slowAccessibilityPollInterval)
                    } else {
                        HotkeyService.shared.unregister()
                        self.scheduleAccessibilityPolling(interval: Self.fastAccessibilityPollInterval)
                    }
                }
            }
        }
    }

    /// Human-readable description of the current hotkey.
    var hotkeyDescription: String {
        var parts: [String] = []
        let mods = NSEvent.ModifierFlags(rawValue: UInt(hotkeyModifiers))
        if mods.contains(.control) { parts.append("^") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }
        let keyName = KeyCodeNames.name(for: hotkeyKeyCode)
        parts.append(keyName)
        return parts.joined()
    }
}

// MARK: - Key code names

enum KeyCodeNames {
    static func name(for keyCode: Int) -> String {
        names[keyCode] ?? "Key(\(keyCode))"
    }

    private static let names: [Int: String] = [
        kVK_Space: "Space",
        kVK_Return: "Return",
        kVK_Tab: "Tab",
        kVK_Delete: "Delete",
        kVK_Escape: "Esc",
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
        kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
        kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
        kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
        kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
        kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}
