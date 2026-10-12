import SwiftUI
import AppKit

/// Manages the onboarding window lifecycle.
@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    /// Padding around the reader panel inside the onboarding window.
    private static let horizontalPadding: CGFloat = 32

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let onboardingView = OnboardingView {
            self.close()
        }

        let hostingView = NSHostingView(rootView: onboardingView)

        let readerWidth = OnboardingView.readerPanelWidth
        let windowWidth = readerWidth + Self.horizontalPadding * 2

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.center()
        window.isReleasedWhenClosed = false

        // Hide system traffic lights; custom close button is rendered inside the view
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        window = nil
    }
}

// MARK: - Onboarding Pages

private enum OnboardingPage: Int, CaseIterable {
    case welcome
    case howItWorks
    case accessibility
    case ready
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @State private var currentPage: OnboardingPage = .welcome
    var settings: AppSettings = .shared
    var onComplete: () -> Void

    /// The reader panel width based on current settings, used to size the onboarding window.
    static var readerPanelWidth: CGFloat {
        ReaderView.panelWidth(fontSize: AppSettings.shared.fontSize)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)

            VStack(spacing: 0) {
                // Page content
                Group {
                    switch currentPage {
                    case .welcome:
                        WelcomePage()
                    case .howItWorks:
                        HowItWorksPage(settings: settings)
                    case .accessibility:
                        AccessibilityPage(settings: settings)
                    case .ready:
                        ReadyPage(settings: settings)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // Navigation bar
                HStack {
                    // Page indicators
                    HStack(spacing: 6) {
                        ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                            Circle()
                                .fill(page == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel("Page \(currentPage.rawValue + 1) of \(OnboardingPage.allCases.count)")

                    Spacer()

                    if currentPage != .welcome {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if let prev = OnboardingPage(rawValue: currentPage.rawValue - 1) {
                                    currentPage = prev
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }

                    Button(currentPage == .ready ? "Get Started" : "Continue") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if currentPage == .ready {
                                settings.hasCompletedOnboarding = true
                                onComplete()
                            } else if let next = OnboardingPage(rawValue: currentPage.rawValue + 1) {
                                currentPage = next
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
            }

            // Window close button
            WindowControlButtons()
                .padding(.top, 14)
                .padding(.leading, 14)
        }
        .frame(minWidth: 500, minHeight: 480)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Window Control Buttons

/// Custom close button that mimics the macOS traffic light style.
private struct WindowControlButtons: View {
    @State private var isHovering = false

    var body: some View {
        WindowControlButton(color: .red, systemImage: "xmark", isGroupHovering: isHovering) {
            NSApp.keyWindow?.close()
        }
        .onHover { isHovering = $0 }
    }
}

private struct WindowControlButton: View {
    let color: Color
    let systemImage: String
    var isGroupHovering: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                if isGroupHovering {
                    Image(systemName: systemImage)
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(.black.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

// MARK: - Welcome Page

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 188, height: 188)

            Text("Welcome to Pin")
                .font(.system(size: 28, weight: .bold))

            Text("Speed read any text on your Mac,\none word at a time.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - How It Works Page

private struct HowItWorksPage: View {
    var settings: AppSettings
    @State private var demoState = ReaderState()
    @State private var demoEngine: RSVPEngine?

    private static let sampleText = "Pin displays words one at a time at a fixed focal point, so your eyes stay still while you read."

    var body: some View {
        VStack(spacing: 16) {
            Text("How It Works")
                .font(.system(size: 22, weight: .bold))
                .padding(.top, 20)

            VStack(alignment: .leading, spacing: 12) {
                stepRow(
                    icon: "text.cursor",
                    title: "Select text",
                    description: "Highlight text in any application."
                )

                stepRow(
                    icon: "keyboard",
                    title: "Press \(settings.hotkeyDescription)",
                    description: "Your global hotkey triggers the reader."
                )

                stepRow(
                    icon: "eye",
                    title: "Speed read",
                    description: "Words appear one at a time at a fixed focal point."
                )
            }
            .padding(.horizontal, 8)

            // Live reader panel preview
            if let engine = demoEngine {
                ReaderView(
                    state: demoState,
                    engine: engine,
                    settings: settings,
                    onDismiss: {}
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .onAppear {
            demoState.load(text: Self.sampleText, wpm: settings.wordsPerMinute)
            demoState.playbackState = .paused
            demoEngine = RSVPEngine(state: demoState, settings: settings)
        }
        .onDisappear {
            demoEngine?.stop()
        }
    }

    private func stepRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .modifier(GlassIconModifier(tint: .blue))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Accessibility Page

private struct AccessibilityPage: View {
    @Bindable var settings: AppSettings

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Accessibility Permission")
                .font(.system(size: 22, weight: .bold))

            Text("Pin reads selected text from other apps using the macOS Accessibility API. This requires your permission.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            // Status indicator
            HStack(spacing: 8) {
                if settings.hasAccessibilityPermission {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 18))
                    Text("Permission Granted")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 18))
                    Text("Not Yet Granted")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)

            if !settings.hasAccessibilityPermission {
                Button {
                    TextCaptureService.resetAndRequestAccessibilityPermission()
                } label: {
                    Label("Grant Permission", systemImage: "gear")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Ready Page

private struct ReadyPage: View {
    var settings: AppSettings

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("You're All Set")
                .font(.system(size: 22, weight: .bold))

            Text("Select text anywhere and press your hotkey to start speed reading.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            // Show the configured hotkey
            hotkeyBadge

            HStack {
                Text("You can adjust settings anytime from the menu bar.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)

                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    private var hotkeyBadge: some View {
        Text(settings.hotkeyDescription)
            .font(.system(size: 18, weight: .medium, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView(onComplete: {})
}
