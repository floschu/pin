import Foundation

/// Timer-based RSVP engine that advances through words at the configured WPM.
@MainActor @Observable
final class RSVPEngine {
    private var timer: DispatchSourceTimer?
    private var state: ReaderState
    private var settings: AppSettings
    var onFinished: (() -> Void)?

    init(state: ReaderState, settings: AppSettings) {
        self.state = state
        self.settings = settings
    }

    // MARK: - Playback Control

    func play() {
        guard state.hasText else { return }

        if state.currentIndex >= state.totalWords {
            state.currentIndex = 0
        }

        state.playbackState = .playing
        scheduleNextWord()
    }

    func pause() {
        state.playbackState = .paused
        cancelTimer()
    }

    func togglePlayPause() {
        switch state.playbackState {
        case .playing:
            pause()
        case .paused, .finished:
            play()
        case .idle:
            play()
        }
    }

    func restart() {
        cancelTimer()
        state.currentIndex = 0
        state.playbackState = .paused
    }

    func stop() {
        cancelTimer()
        state.playbackState = .idle
    }

    func skipForward() {
        guard state.hasText else { return }
        cancelTimer()
        state.currentIndex = min(state.currentIndex + 1, state.totalWords - 1)
        state.playbackState = .paused
    }

    func skipBackward() {
        guard state.hasText else { return }
        cancelTimer()
        state.currentIndex = max(state.currentIndex - 1, 0)
        state.playbackState = .paused
    }

    func adjustWPM(by delta: Int) {
        let newWPM = max(50, min(1000, state.currentWPM + delta))
        state.currentWPM = newWPM
        settings.wordsPerMinute = newWPM

        // If playing, restart the timer with new interval
        if state.playbackState == .playing {
            cancelTimer()
            scheduleNextWord()
        }
    }

    // MARK: - Timer

    private func scheduleNextWord() {
        cancelTimer()

        let interval = intervalForCurrentWord()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak self] in
            self?.advance()
        }
        timer.resume()
        self.timer = timer
    }

    private func advance() {
        let nextIndex = nextIndex(after: state.currentIndex)

        if nextIndex >= state.totalWords {
            state.playbackState = .finished
            cancelTimer()
            onFinished?()
            return
        }

        state.currentIndex = nextIndex

        if state.playbackState == .playing {
            scheduleNextWord()
        }
    }

    /// Index of the word to show after `index`. Skips a run of stopwords when
    /// enabled, but always shows the last word of the text.
    func nextIndex(after index: Int) -> Int {
        var next = index + 1
        guard settings.stopwordSkipping else { return next }
        while next < state.totalWords - 1 && TextTokenizer.isStopword(state.words[next]) {
            next += 1
        }
        return next
    }

    private func intervalForCurrentWord() -> TimeInterval {
        let baseInterval = 60.0 / Double(state.currentWPM)
        var interval = baseInterval

        let word = state.currentWord
        let index = state.currentIndex

        // Speed variability: adjust based on word length using sqrt curve
        // for a gentler scaling than linear (e.g. 10-char word gets ~1.13x, not ~1.5x)
        if settings.speedVariability {
            let factor = 1.0 + sqrt(Double(word.count)) * 0.04
            interval *= factor
        }

        // Ramp-up: start slower for the first N words, linearly approaching full speed
        if settings.rampUp && index < settings.rampUpWords {
            let progress = Double(index) / Double(settings.rampUpWords)
            let rampFactor = 2.0 - progress  // 2x interval at word 0, 1x at rampUpWords
            interval *= rampFactor
        }

        // Use the largest applicable pause multiplier (structural or sentence-end)
        var pauseMultiplier = 1.0

        // Structural pause: check if the next word starts a new line/paragraph
        let nextIndex = index + 1
        if nextIndex < state.totalWords, let structuralPause = state.pauseBefore[nextIndex] {
            pauseMultiplier = max(pauseMultiplier, structuralPause)
        }

        // Sentence-end pause
        if settings.pauseAtSentenceEnd && TextTokenizer.isSentenceEnd(word) {
            pauseMultiplier = max(pauseMultiplier, settings.pauseMultiplier)
        }

        // Clause boundary pause (commas, semicolons, colons)
        if settings.pauseAtClauseBoundary && TextTokenizer.isClauseBoundary(word) {
            pauseMultiplier = max(pauseMultiplier, settings.clausePauseMultiplier)
        }

        interval *= pauseMultiplier

        return interval
    }

    private func cancelTimer() {
        timer?.cancel()
        timer = nil
    }
}
