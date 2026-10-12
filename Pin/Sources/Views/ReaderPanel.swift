import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A key-accepting floating panel (borderless panels return NO from canBecomeKey by default).
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private extension NSScreen {
    /// Returns the screen containing the current mouse cursor position.
    static var screenWithMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return Self.screens.first { $0.frame.contains(mouseLocation) }
    }
}

/// A floating NSPanel styled like Spotlight, used to display the speed reader.
@MainActor @Observable
final class ReaderPanelController {
    static let shared = ReaderPanelController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<ReaderView>?
    private var readerState: ReaderState
    private var engine: RSVPEngine
    private let settings = AppSettings.shared
    private var clickOutsideMonitor: Any?
    private var clickOutsideLocalMonitor: Any?
    private var keyEventMonitor: Any?
    private var notificationObservers: [Any] = []

    /// Observable visibility state, updated on show and dismiss.
    private(set) var isVisible: Bool = false

    /// True while the panel shows sample text from Settings. Click-outside
    /// dismissal is suspended so the user can adjust settings while watching.
    private var isPreviewing = false

    init() {
        let state = ReaderState()
        self.readerState = state
        self.engine = RSVPEngine(state: state, settings: AppSettings.shared)
    }

    func show(with text: String) {
        isPreviewing = false
        readerState.load(text: text, wpm: settings.wordsPerMinute)
        showPanel()

        // Auto-start playback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.engine.play()
        }
    }

    func showError(_ message: String) {
        isPreviewing = false
        readerState.reset()
        readerState.errorMessage = message
        showPanel()
    }

    /// Show the panel with sample text for previewing settings changes.
    /// Does not auto-start playback.
    func showPreview() {
        let sample = "The quick brown fox jumps over the lazy dog, while the bright sun sets behind the distant mountains."
        isPreviewing = true
        readerState.load(text: sample, wpm: settings.wordsPerMinute)
        readerState.playbackState = .paused
        showPanel()
    }

    private func showPanel() {
        if panel == nil {
            createPanel()
        }

        guard let panel = panel else { return }

        positionPanel(panel)

        panel.alphaValue = 1.0
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        installKeyEventMonitor()
        installClickOutsideMonitor()
        installNotificationObservers(panel)
        isVisible = true
    }

    func dismiss() {
        engine.stop()
        readerState.reset()
        savePosition()
        removeClickOutsideMonitor()
        removeKeyEventMonitor()
        removeNotificationObservers()
        panel?.orderOut(nil)
        isVisible = false
    }

    func toggle(with text: String) {
        if isVisible {
            dismiss()
        } else {
            show(with: text)
        }
    }

    // MARK: - Panel Creation

    private func createPanel() {
        let panel = KeyablePanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        let contentView = ReaderView(
            state: readerState,
            engine: engine,
            settings: settings,
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.wantsLayer = true

        panel.contentView = hostingView
        self.hostingView = hostingView

        self.panel = panel
        panel.alphaValue = 1.0
        observeLayout()
        observeUnfocusedOpacity()

        // Observe finished state to auto-close
        engine.onFinished = { [weak self] in
            // Brief delay so the user sees the last word
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                guard let self, self.readerState.playbackState == .finished else { return }
                self.dismiss()
            }
        }
    }

    // MARK: - Panel Sizing & Position

    private var suppressPositionSave = false

    private func positionPanel(_ panel: NSPanel) {
        let size = panelSize()
        suppressPositionSave = true

        // Use the screen where the mouse cursor is (where the user triggered the hotkey)
        let activeScreen = NSScreen.screenWithMouse ?? NSScreen.main

        if let cx = UserDefaults.standard.object(forKey: "panelCenterX") as? Double,
           let cy = UserDefaults.standard.object(forKey: "panelCenterY") as? Double {
            let savedCenter = NSPoint(x: cx, y: cy)
            // Only restore saved position if it falls on the active screen
            if let screen = activeScreen, screen.frame.contains(savedCenter) {
                let x = cx - Double(size.width) / 2
                let y = cy - Double(size.height) / 2
                panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
            } else {
                centerPanel(panel, size: size, on: activeScreen)
            }
        } else {
            centerPanel(panel, size: size, on: activeScreen)
        }
        suppressPositionSave = false
    }

    private func centerPanel(_ panel: NSPanel, size: NSSize, on screen: NSScreen? = nil) {
        let targetScreen = screen ?? NSScreen.screenWithMouse ?? NSScreen.main
        guard let screenFrame = targetScreen?.visibleFrame else { return }
        let x = screenFrame.midX - size.width / 2
        let y = screenFrame.midY - size.height / 2 + screenFrame.height * 0.1
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    private func savePosition() {
        guard !suppressPositionSave, let frame = panel?.frame else { return }
        UserDefaults.standard.set(Double(frame.midX), forKey: "panelCenterX")
        UserDefaults.standard.set(Double(frame.midY), forKey: "panelCenterY")
    }

    static func resetPosition() {
        UserDefaults.standard.removeObject(forKey: "panelCenterX")
        UserDefaults.standard.removeObject(forKey: "panelCenterY")
        if let panel = shared.panel, panel.isVisible {
            shared.suppressPositionSave = true
            shared.centerPanel(panel, size: shared.panelSize())
            shared.suppressPositionSave = false
        }
    }

    private func resizePanel() {
        guard let panel = panel else { return }
        let size = panelSize()
        let oldFrame = panel.frame
        let x = oldFrame.midX - size.width / 2
        let y = oldFrame.midY - size.height / 2
        suppressPositionSave = true
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true, animate: true)
        suppressPositionSave = false
    }

    private func panelSize() -> NSSize {
        hostingView?.fittingSize ?? NSSize(width: 520, height: 200)
    }

    private func observeLayout() {
        withObservationTracking {
            _ = settings.fontSize
            _ = settings.showKeyboardHints
            _ = settings.showWPM
            _ = settings.showWordCount
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.resizePanel()
                self.observeLayout()
            }
        }
    }

    // MARK: - Click Outside

    private func installClickOutsideMonitor() {
        removeClickOutsideMonitor()

        // Global monitor catches clicks in other applications.
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self,
                  self.settings.dismissOnClickOutside,
                  self.isVisible,
                  !self.isPreviewing else { return }
            DispatchQueue.main.async {
                self.dismiss()
            }
        }

        // Local monitor catches clicks within our own app but outside the panel
        // (e.g., clicking the menu bar icon or the settings window).
        clickOutsideLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self,
                  self.settings.dismissOnClickOutside,
                  self.isVisible,
                  !self.isPreviewing,
                  let panel = self.panel else { return event }

            // If the click landed in a different window (or no window), dismiss.
            if event.window != panel {
                DispatchQueue.main.async {
                    self.dismiss()
                }
            }

            return event
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        if let monitor = clickOutsideLocalMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideLocalMonitor = nil
        }
    }

    // MARK: - Key Event Monitor

    private func installKeyEventMonitor() {
        guard keyEventMonitor == nil else { return }
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible, event.window == self.panel else { return event }
            return self.handleKeyEvent(event) ? nil : event
        }
    }

    private func removeKeyEventMonitor() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }

    // MARK: - Notification Observers

    /// Observes panel move and focus changes. Called on every show, since
    /// `dismiss()` removes the observers again.
    private func installNotificationObservers(_ panel: NSPanel) {
        removeNotificationObservers()

        let moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.savePosition()
            }
        }
        notificationObservers.append(moveObserver)

        let becomeKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateOpacity(focused: true)
            }
        }
        notificationObservers.append(becomeKeyObserver)

        let resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateOpacity(focused: false)
            }
        }
        notificationObservers.append(resignKeyObserver)
    }

    private func removeNotificationObservers() {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }

    // MARK: - Focus-based Opacity

    private func updateOpacity(focused: Bool) {
        guard let panel = panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = focused ? 1.0 : settings.unfocusedOpacity
        }
    }

    private func observeUnfocusedOpacity() {
        withObservationTracking {
            _ = settings.unfocusedOpacity
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, let panel = self.panel else { return }
                if !panel.isKeyWindow {
                    panel.alphaValue = self.settings.unfocusedOpacity
                }
                self.observeUnfocusedOpacity()
            }
        }
    }

    // MARK: - Keyboard Handling

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        switch Int(event.keyCode) {
        case kVK_ANSI_V where modifiers.intersection([.command, .option, .control, .shift]) == .command: // Cmd+V
            if let text = NSPasteboard.general.string(forType: .string),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                engine.stop()
                readerState.load(text: text, wpm: settings.wordsPerMinute)
                engine.play()
            }
            return true
        case kVK_Space: // Space
            engine.togglePlayPause()
            return true
        case kVK_Escape: // Escape
            dismiss()
            return true
        case kVK_ANSI_R: // R
            engine.restart()
            return true
        case kVK_LeftArrow: // Left arrow
            engine.skipBackward()
            return true
        case kVK_RightArrow: // Right arrow
            engine.skipForward()
            return true
        case kVK_UpArrow: // Up arrow
            engine.adjustWPM(by: 10)
            return true
        case kVK_DownArrow: // Down arrow
            engine.adjustWPM(by: -10)
            return true
        default:
            return false
        }
    }
}
