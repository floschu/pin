import SwiftUI
import Carbon.HIToolbox

/// A button that records a keyboard shortcut when clicked.
struct HotkeyRecorderButton: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    func makeNSView(context: Context) -> HotkeyRecorderNSButton {
        let button = HotkeyRecorderNSButton()
        button.keyCode = keyCode
        button.modifiers = modifiers
        button.onRecorded = { newKeyCode, newModifiers in
            keyCode = newKeyCode
            modifiers = newModifiers
            // Re-register the hotkey with the new combo
            HotkeyService.shared.register()
        }
        return button
    }

    func updateNSView(_ nsView: HotkeyRecorderNSButton, context: Context) {
        nsView.keyCode = keyCode
        nsView.modifiers = modifiers
        nsView.updateTitle()
    }
}

/// NSButton subclass that captures key events for hotkey recording.
final class HotkeyRecorderNSButton: NSButton {
    var keyCode: Int = kVK_Space
    var modifiers: Int = 0
    var isRecording = false
    var onRecorded: ((Int, Int) -> Void)?
    private var eventMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(buttonClicked)
        updateTitle()
        setAccessibilityRole(.button)
    }

    func updateTitle() {
        if isRecording {
            title = "Press shortcut..."
        } else {
            title = shortcutDescription()
        }
        setAccessibilityLabel(title)
    }

    private func shortcutDescription() -> String {
        var parts: [String] = []
        let mods = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        if mods.contains(.control) { parts.append("\u{2303}") }
        if mods.contains(.option) { parts.append("\u{2325}") }
        if mods.contains(.shift) { parts.append("\u{21E7}") }
        if mods.contains(.command) { parts.append("\u{2318}") }
        parts.append(KeyCodeNames.name(for: keyCode))
        return parts.joined()
    }

    @objc private func buttonClicked() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        updateTitle()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }

            let newKeyCode = Int(event.keyCode)

            // Escape cancels recording
            if newKeyCode == kVK_Escape {
                self.stopRecording()
                return nil
            }

            let relevantMask: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
            let newMods = event.modifierFlags.intersection(relevantMask)

            // Require at least one modifier
            guard !newMods.isEmpty else { return nil }

            self.keyCode = newKeyCode
            self.modifiers = Int(newMods.rawValue)
            self.onRecorded?(newKeyCode, Int(newMods.rawValue))
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        updateTitle()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
