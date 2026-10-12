import SwiftUI
import AppKit

/// The main RSVP display view shown inside the floating panel.
struct ReaderView: View {
    @Bindable var state: ReaderState
    var engine: RSVPEngine
    var settings: AppSettings
    var onDismiss: () -> Void

    @State private var fontCache = FontCache()

    private var isError: Bool { state.errorMessage != nil }

    private var viewWidth: CGFloat {
        Self.panelWidth(fontSize: settings.fontSize)
    }

    /// Panel width for a given font size. Also used to size the onboarding window.
    static func panelWidth(fontSize: Double) -> CGFloat {
        min(700, max(400, 300 + fontSize * 5.5))
    }

    private var orpSideWidth: CGFloat {
        viewWidth * 0.38
    }

    private func readerFont(size: Double, weight: NSFont.Weight) -> Font {
        let family = settings.fontFamily.trimmingCharacters(in: .whitespacesAndNewlines)
        let fontSize = CGFloat(size)
        return Font(fontCache.font(family: family, size: fontSize, weight: weight))
    }

    var body: some View {
        ZStack {
            // Background with vibrancy
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)

            VStack(spacing: 0) {
                // Top bar: counter (left) and WPM (right)
                if !isError {
                    HStack {
                        if settings.showWordCount {
                            Text(counterText)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(counterAccessibilityLabel)
                        }

                        Spacer()

                        if settings.showWPM {
                            Text(wpmText)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(wpmAccessibilityLabel)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                // Center: the pinned word
                wordView
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, max(20, settings.fontSize * 0.55))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(wordAccessibilityLabel)

                HStack {
                    Spacer(minLength: 0)

                    // Bottom: keyboard hints
                    if isError {
                        formattedHints([(["⌘V"], "paste"), (["esc"], "close")])
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    } else if settings.showKeyboardHints {
                        formattedHints([(["space"], "play/pause")])
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(width: viewWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: settings.fontFamily) {
            fontCache.clear()
        }
        .onChange(of: settings.fontSize) {
            fontCache.clear()
        }
    }

    // MARK: - Counter + WPM

    private var counterText: String {
        guard state.hasText else { return "0/0" }
        return "\(state.currentIndex + 1)/\(state.totalWords)"
    }

    private var counterAccessibilityLabel: String {
        guard state.hasText else { return "Word 0 of 0" }
        return "Word \(state.currentIndex + 1) of \(state.totalWords)"
    }

    private var wpmText: String {
        "\(state.currentWPM) WPM"
    }

    private var wpmAccessibilityLabel: String {
        "Speed \(state.currentWPM) words per minute"
    }

    private var wordAccessibilityLabel: String {
        if let errorMessage = state.errorMessage {
            return "No text selected. \(errorMessage)"
        }
        guard state.hasText else { return "No text loaded" }
        if state.playbackState == .finished {
            return "Done reading"
        }
        let status: String
        switch state.playbackState {
        case .playing:
            status = "playing"
        case .paused:
            status = "paused"
        case .idle:
            status = "ready"
        case .finished:
            status = "finished"
        }
        return "Word \(state.currentWord), \(status)"
    }

    // MARK: - Word Display

    @ViewBuilder
    private var wordView: some View {
        if let errorMessage = state.errorMessage {
            VStack(spacing: 6) {
                Text("No Text Selected")
                    .font(readerFont(size: settings.fontSize * 0.6, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(errorMessage)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        } else if state.hasText {
            if state.playbackState == .finished {
                Text("Done")
                    .font(readerFont(size: settings.fontSize, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if settings.orpEnabled {
                orpWordView(word: state.currentWord)
            } else {
                Text(state.currentWord)
                    .font(readerFont(size: settings.fontSize, weight: .medium))
                    .foregroundStyle(.primary)
            }
        } else {
            Text("No text")
                .font(readerFont(size: settings.fontSize, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }

    /// Word display with ORP (pinned letter) highlighting.
    /// The pinned letter is displayed in the accent color and the word is positioned
    /// so the pinned letter always appears at the center of the view.
    /// An optional red pin icon sits above the highlighted letter.
    private func orpWordView(word: String) -> some View {
        let parts = ORPCalculator.split(word: word)

        return HStack(spacing: 0) {
            // Before the pin: right-aligned to push the pin to center
            Text(parts.before)
                .font(readerFont(size: settings.fontSize, weight: .regular))
                .foregroundStyle(.primary.opacity(settings.orpSideOpacity))
                .lineLimit(1)
                .frame(width: orpSideWidth, alignment: .trailing)

            // The pinned letter with optional pin indicator above
            let orpForegroundStyle = settings.orpColorEnabled ?
                AnyShapeStyle(settings.orpColor) : AnyShapeStyle(.primary)
            Text(String(parts.pinned))
                .font(readerFont(size: settings.fontSize, weight: .bold))
                .foregroundStyle(orpForegroundStyle)
                .overlay(alignment: .top) {
                    if settings.showPinIndicator {
                        Image(systemName: "pin.fill")
                            .font(.system(size: settings.fontSize * 0.22))
                            .foregroundStyle(orpForegroundStyle)
                            .offset(y: -(settings.fontSize * 0.28))
                    }
                }

            // After the pin: left-aligned
            Text(parts.after)
                .font(readerFont(size: settings.fontSize, weight: .regular))
                .foregroundStyle(.primary.opacity(settings.orpSideOpacity))
                .lineLimit(1)
                .frame(width: orpSideWidth, alignment: .leading)
        }
    }

    // MARK: - Hints

    private func keyCap(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            )
            .accessibilityLabel("\(label) key")
    }

    private func formattedHints(_ hints: [(keys: [String], action: String)]) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                HStack(spacing: 3) {
                    ForEach(Array(hint.keys.enumerated()), id: \.offset) { _, key in
                        keyCap(key)
                    }
                    Text(hint.action)
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundStyle(.tertiary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private final class FontCache {
    private var cache: [FontKey: NSFont] = [:]

    func font(family: String, size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let key = FontKey(family: family, size: size, weight: weight)
        if let cached = cache[key] {
            return cached
        }
        if !family.isEmpty {
            let descriptor = NSFontDescriptor(fontAttributes: [
                .family: family,
                .traits: [NSFontDescriptor.TraitKey.weight: weight.rawValue]
            ])
            if let customFont = NSFont(descriptor: descriptor, size: size) {
                cache[key] = customFont
                return customFont
            }
        }
        let systemFont = NSFont.systemFont(ofSize: size, weight: weight)
        cache[key] = systemFont
        return systemFont
    }

    func clear() {
        cache.removeAll(keepingCapacity: true)
    }
}

private struct FontKey: Hashable {
    let family: String
    let size: CGFloat
    let weight: NSFont.Weight
}

// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Previews

#Preview("Reader - Playing") {
    let settings = AppSettings.shared
    let state = ReaderState()
    state.load(text: "The quick brown fox jumps over the lazy dog near the riverbank", wpm: settings.wordsPerMinute)
    state.playbackState = .paused
    let engine = RSVPEngine(state: state, settings: settings)
    return ReaderView(state: state, engine: engine, settings: settings, onDismiss: {})
}

#Preview("Reader - Finished") {
    let settings = AppSettings.shared
    let state = ReaderState()
    state.load(text: "Done reading", wpm: settings.wordsPerMinute)
    state.playbackState = .finished
    let engine = RSVPEngine(state: state, settings: settings)
    return ReaderView(state: state, engine: engine, settings: settings, onDismiss: {})
}

#Preview("Reader - Error") {
    let settings = AppSettings.shared
    let state = ReaderState()
    state.errorMessage = "Select some text in any application, then press \(settings.hotkeyDescription) to speed read it."
    let engine = RSVPEngine(state: state, settings: settings)
    return ReaderView(state: state, engine: engine, settings: settings, onDismiss: {})
}
