import SwiftUI

/// Pin - A macOS speed reading app.
/// Reads selected text from any application and displays it word by word
/// in a floating panel using RSVP (Rapid Serial Visual Presentation).
@main
struct PinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings = AppSettings.shared
    private let panelController = ReaderPanelController.shared

    var body: some Scene {
        // Menu bar app
        MenuBarExtra("Pin", systemImage: "pin.fill") {
            MenuBarView()
        }

        // Settings window
        Settings {
            SettingsView(settings: settings)
        }
    }

    init() {
        setupHotkey()
        // Only auto-prompt for accessibility if onboarding is already done.
        // During onboarding, the user is guided to grant it in Step 3.
        if AppSettings.shared.hasCompletedOnboarding {
            checkAccessibility()
        }
    }

    // MARK: - Setup

    private func setupHotkey() {
        let hotkey = HotkeyService.shared
        hotkey.onHotkeyPressed = { [self] in
            triggerSpeedRead()
        }
        hotkey.register()
    }

    private func checkAccessibility() {
        if !TextCaptureService.hasAccessibilityPermission {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                TextCaptureService.resetAndRequestAccessibilityPermission()
            }
        }
    }

    // MARK: - Speed Reading Trigger

    private func triggerSpeedRead() {
        // If panel is already showing, dismiss it
        if panelController.isVisible {
            panelController.dismiss()
            return
        }

        // Capture selected text from the frontmost app.
        // The completion may fire asynchronously when the Cmd+C fallback is used,
        // because we must return to the run loop to let simulated key events flow
        // through the CGEvent tap before reading the clipboard.
        TextCaptureService.captureSelectedText { [self] text in
            MainActor.assumeIsolated {
                guard let text else {
                    var message = "Select some text in any application, then press \(AppSettings.shared.hotkeyDescription) to speed read it."
                    if !TextCaptureService.hasAccessibilityPermission {
                        message += "\n\nPin needs Accessibility permission. "
                        message += "Grant it in System Settings > Privacy & Security > Accessibility."
                    }
                    panelController.showError(message)
                    return
                }

                panelController.show(with: text)
            }
        }
    }
}

// MARK: - App Delegate

/// Handles app lifecycle events that SwiftUI's App protocol does not cover,
/// such as clicking the app icon in Finder or the Dock while the app is
/// already running as a menu bar agent.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Called when the user clicks the app icon while it is already running
    /// (or re-launches it from Finder/Dock). Show the appropriate window
    /// regardless of whether other windows are visible, since the menu bar
    /// extra does not count as a user-facing window and our own onboarding
    /// window may already be open.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !AppSettings.shared.hasCompletedOnboarding {
            OnboardingWindowController.shared.show()
        } else if !flag {
            openSettingsWindow()
        }
        return true
    }

    /// Called on initial launch. Show onboarding for first-time users,
    /// or open Settings for returning users.
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AppSettings.shared.hasCompletedOnboarding {
            OnboardingWindowController.shared.show()
        } else {
            openSettingsWindow()
        }
    }

    private func openSettingsWindow() {
        if NSApp.responds(to: Selector(("showSettingsWindow:"))) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
