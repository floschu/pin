import SwiftUI
import AppKit

/// Settings pages shown in the sidebar.
enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "General"
    case reading = "Reading"
    case appearance = "Appearance"
    case keybindings = "Keybindings"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "gearshape.fill"
        case .reading: "book.fill"
        case .appearance: "paintbrush.fill"
        case .keybindings: "keyboard.fill"
        case .about: "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .general: .gray
        case .reading: .blue
        case .appearance: .orange
        case .keybindings: .green
        case .about: .purple
        }
    }
}

/// Settings view with a macOS System Settings-style sidebar.
struct SettingsView: View {
    @Bindable var settings: AppSettings
    @State private var selectedPage: SettingsPage? = .general

    private var panelController: ReaderPanelController { .shared }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
            VStack(spacing: 0) {
                List(selection: $selectedPage) {
                    Label {
                        Text("Pin")
                    } icon: {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .modifier(GlassIconModifier(tint: .red))
                    }
                    .padding(.bottom, 16)

                    ForEach(SettingsPage.allCases) { page in
                        NavigationLink(value: page) {
                            Label {
                                Text(page.rawValue)
                            } icon: {
                                Image(systemName: page.icon)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .modifier(GlassIconModifier(tint: page.iconColor))
                            }
                        }
                    }
                }

                Divider()

                Button {
                    if panelController.isVisible {
                        panelController.dismiss()
                    } else {
                        panelController.showPreview()
                    }
                } label: {
                    Label(
                        panelController.isVisible ? "Hide Preview Panel" : "Show Preview Panel",
                        systemImage: panelController.isVisible ? "eye.slash" : "eye"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationSplitViewColumnWidth(215)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            detailView
        }
        .frame(minWidth: 650, maxWidth: 650, minHeight: 470, maxHeight: .infinity)
        .navigationTitle("")
        .background(WindowAccessor { window in
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        })
        .onDisappear {
            if panelController.isVisible {
                panelController.dismiss()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedPage {
        case .general:
            GeneralSettingsView(settings: settings)
        case .reading:
            ReadingSettingsView(settings: settings)
        case .appearance:
            AppearanceSettingsView(settings: settings)
        case .keybindings:
            KeybindingsSettingsView()
        case .about:
            AboutSettingsView()
        case nil:
            GeneralSettingsView(settings: settings)
        }
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    HotkeyRecorderButton(
                        keyCode: $settings.hotkeyKeyCode,
                        modifiers: $settings.hotkeyModifiers
                    )
                    .frame(width: 140, height: 24)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Global Hotkey")
                        Text("Select text in any app, then press this shortcut to start speed reading.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Toggle(isOn: $settings.dismissOnClickOutside) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dismiss on click outside")
                        Text("Automatically close the reader panel when clicking anywhere else.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                LabeledContent {
                    if settings.hasAccessibilityPermission {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not Granted", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility Permission")
                        Text("Required to read selected text from other applications.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent {
                    Button(settings.hasAccessibilityPermission ? "Open Settings" : "Request Permission") {
                        if settings.hasAccessibilityPermission {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        } else {
                            TextCaptureService.resetAndRequestAccessibilityPermission()
                        }
                    }
                } label: {
                    Text("Grant access in System Settings > Privacy & Security > Accessibility. After an update, request permission again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Reading

private struct ReadingSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text("\(settings.wordsPerMinute) WPM")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Words per minute")
                        Text("Controls how fast words are displayed. Higher values mean faster reading.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Slider(
                    value: .init(
                        get: { Double(settings.wordsPerMinute) },
                        set: { settings.wordsPerMinute = Int((($0) / 10).rounded() * 10) }
                    ),
                    in: 50...1000
                )
            }

            Section {
                Toggle(isOn: $settings.pauseAtSentenceEnd) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause at sentence endings")
                        Text("Briefly pause after periods, question marks, and exclamation marks.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if settings.pauseAtSentenceEnd {
                    LabeledContent {
                        Text(String(format: "%.1fx", settings.pauseMultiplier))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pause multiplier")
                            Text("How much longer to hold at sentence boundaries.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Slider(
                        value: .init(
                            get: { settings.pauseMultiplier },
                            set: { settings.pauseMultiplier = ($0 * 10).rounded() / 10 }
                        ),
                        in: 1.0...3.0
                    )
                }
            }

            Section {
                Toggle(isOn: $settings.pauseAtClauseBoundary) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause at clause boundaries")
                        Text("Briefly pause after commas, semicolons, and colons to mimic natural reading rhythm at phrase breaks.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if settings.pauseAtClauseBoundary {
                    LabeledContent {
                        Text(String(format: "%.1fx", settings.clausePauseMultiplier))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clause pause multiplier")
                            Text("How much longer to hold at clause boundaries.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Slider(
                        value: .init(
                            get: { settings.clausePauseMultiplier },
                            set: { settings.clausePauseMultiplier = ($0 * 10).rounded() / 10 }
                        ),
                        in: 1.0...2.5
                    )
                }
            }

            Section {
                Toggle(isOn: $settings.speedVariability) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Speed variability")
                        Text("Slow down for longer words, speed up for shorter ones.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Toggle(isOn: $settings.rampUp) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ramp-up start")
                        Text("Start slower for the first few words and gradually reach full speed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if settings.rampUp {
                    LabeledContent {
                        Text("\(settings.rampUpWords) words")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ramp-up length")
                            Text("Number of words over which speed ramps from half to full.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Slider(
                        value: .init(
                            get: { Double(settings.rampUpWords) },
                            set: { settings.rampUpWords = Int($0.rounded()) }
                        ),
                        in: 3...20
                    )
                }
            }

            Section {
                Toggle(isOn: $settings.stopwordSkipping) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Skip stopwords")
                        Text("Skip common words like \"the\", \"a\", \"is\" that convey minimal meaning.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance

private struct AppearanceSettingsView: View {
    @Bindable var settings: AppSettings

    @State private var fontFamilies: [String] = []

    init(settings: AppSettings) {
        self.settings = settings
        _fontFamilies = State(initialValue: Self.buildFontFamilies(current: settings.fontFamily))
    }

    private static func buildFontFamilies(current: String) -> [String] {
        var families = Set(NSFontManager.shared.availableFontFamilies)
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            families.insert(trimmed)
        }
        return families.sorted()
    }

    private func loadFontFamilies() {
        fontFamilies = Self.buildFontFamilies(current: settings.fontFamily)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text("\(Int(settings.fontSize))pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Font size")
                        Text("Size of the word displayed in the reader panel.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Slider(
                    value: .init(
                        get: { settings.fontSize },
                        set: { settings.fontSize = ($0 / 2).rounded() * 2 }
                    ),
                    in: 16...72
                )

                LabeledContent {
                    Picker("Font family", selection: $settings.fontFamily) {
                        Text("System").tag("")
                        ForEach(fontFamilies, id: \.self) { family in
                            Text(family).tag(family)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Font family")
                        Text("Choose a system font, or keep System for the default UI font.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Toggle(isOn: $settings.orpEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Highlight pinned letter (ORP)")
                        Text("Highlight the optimal recognition point to help your eyes fixate.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if settings.orpEnabled {
                    Toggle(isOn: $settings.showPinIndicator) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show pin indicator")
                            Text("Display a small marker above the pinned letter.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: $settings.orpColorEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Color pinned letter")
                            Text("Use a distinct color for the pinned letter. When off, it is bold only.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if settings.orpColorEnabled {
                        ColorPicker(selection: $settings.orpColor, supportsOpacity: false) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pin color")
                                Text("The color used to highlight the pinned letter.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    LabeledContent {
                        Text("\(Int(settings.orpSideOpacity * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Side character opacity")
                            Text("Dim letters around the pinned letter to make the focal point stand out more.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Slider(
                        value: .init(
                            get: { settings.orpSideOpacity },
                            set: { settings.orpSideOpacity = ($0 * 20).rounded() / 20 }
                        ),
                        in: 0.1...1.0
                    )
                }
            }

            Section {
                LabeledContent {
                    Text("\(Int(settings.unfocusedOpacity * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unfocused opacity")
                        Text("Panel transparency when it is not the active window.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Slider(
                    value: .init(
                        get: { settings.unfocusedOpacity },
                        set: { settings.unfocusedOpacity = ($0 * 20).rounded() / 20 }
                    ),
                    in: 0.1...0.9
                )
            }

            Section {
                Toggle(isOn: $settings.showKeyboardHints) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show keyboard hints")
                        Text("Display shortcut hints at the bottom of the reader panel.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $settings.showWPM) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show WPM")
                        Text("Display the current words-per-minute speed while reading.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $settings.showWordCount) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show word count")
                        Text("Display progress as a word counter in the reader panel.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Panel position")
                    Text("Reset the reader panel to the center of the screen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    Button("Reset to Center") {
                        ReaderPanelController.resetPosition()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadFontFamilies()
        }
        .onChange(of: settings.fontFamily) {
            loadFontFamilies()
        }
    }
}

// MARK: - Keybindings

private struct KeybindingsSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("These keyboard shortcuts are available while the reader panel is open.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Playback") {
                keybindingRow(key: "Space", description: "Play or pause reading")
                keybindingRow(key: "R", description: "Restart from the beginning")
                keybindingRow(key: "Esc", description: "Close the reader panel")
            }

            Section("Navigation") {
                keybindingRow(key: "\u{2190} Left Arrow", description: "Skip back one word")
                keybindingRow(key: "\u{2192} Right Arrow", description: "Skip forward one word")
            }

            Section("Speed") {
                keybindingRow(key: "\u{2191} Up Arrow", description: "Increase speed by 10 WPM")
                keybindingRow(key: "\u{2193} Down Arrow", description: "Decrease speed by 10 WPM")
            }

            Section("Other") {
                keybindingRow(key: "\u{2318}V", description: "Paste text from clipboard and start reading")
            }
        }
        .formStyle(.grouped)
    }

    private func keybindingRow(key: String, description: String) -> some View {
        LabeledContent {
            Text(key)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(.quaternary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                )
        } label: {
            Text(description)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - About

private struct AboutSettingsView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: buildNumber)
            }

            Section {
                AboutLinkRow(title: "Website", systemImage: "globe", url: AboutLinks.website)
                AboutLinkRow(title: "Source Code", systemImage: "chevron.left.forwardslash.chevron.right", url: AboutLinks.sourceCode)
                AboutLinkRow(title: "Support & Feedback", systemImage: "bubble.left.and.bubble.right", url: AboutLinks.issues)
            } footer: {
                Text("Pin is free and open source under the MIT License. It makes no network requests and collects no data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    OnboardingWindowController.shared.show()
                } label: {
                    LabeledContent {
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    } label: {
                        Label("Show Welcome Guide", systemImage: "hand.wave")
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .formStyle(.grouped)
    }
}

/// External links shown on the About page.
private enum AboutLinks {
    static let website = URL(string: "https://pin.flosch.at")
    static let sourceCode = URL(string: "https://github.com/floschu/pin")
    static let issues = URL(string: "https://github.com/floschu/pin/issues")
}

/// A row on the About page that opens an external link in the default browser.
private struct AboutLinkRow: View {
    let title: String
    let systemImage: String
    let url: URL?

    var body: some View {
        Button {
            guard let url else { return }
            NSWorkspace.shared.open(url)
        } label: {
            LabeledContent {
                Image(systemName: "arrow.up.forward")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            } label: {
                Label(title, systemImage: systemImage)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Window Accessor

/// An NSViewRepresentable that grabs its hosting NSWindow and runs a
/// configuration closure once. Used to customise the SwiftUI Settings window.
private struct WindowAccessor: NSViewRepresentable {
    var configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Preview

#Preview("Settings") {
    SettingsView(settings: .shared)
        .frame(width: 650, height: 500)
}
