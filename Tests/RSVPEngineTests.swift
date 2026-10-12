import Testing
@testable import Pin

@Suite("RSVPEngine")
struct RSVPEngineTests {
    // MARK: - Helpers

    /// Creates a ReaderState + RSVPEngine pair for testing.
    /// Uses AppSettings.shared since its init is private.
    @MainActor
    private static func makeEngine(
        text: String = "The quick brown fox jumps over the lazy dog",
        wpm: Int = 300
    ) -> (state: ReaderState, engine: RSVPEngine) {
        let state = ReaderState()
        let settings = AppSettings.shared
        settings.wordsPerMinute = wpm
        // Disable features that complicate timing tests
        settings.speedVariability = false
        settings.stopwordSkipping = false
        settings.rampUp = false
        settings.pauseAtSentenceEnd = false
        settings.pauseAtClauseBoundary = false

        state.load(text: text, wpm: wpm)
        let engine = RSVPEngine(state: state, settings: settings)
        return (state, engine)
    }

    // MARK: - play()

    @Test("Play sets state to playing")
    @MainActor func playStartsPlayback() {
        let (state, engine) = Self.makeEngine()
        engine.play()
        #expect(state.playbackState == .playing)
    }

    @Test("Play does nothing when there is no text")
    @MainActor func playWithNoText() {
        let state = ReaderState()
        let engine = RSVPEngine(state: state, settings: AppSettings.shared)
        engine.play()
        #expect(state.playbackState == .idle)
    }

    @Test("Play resets index if at end of text")
    @MainActor func playResetsAtEnd() {
        let (state, engine) = Self.makeEngine()
        state.currentIndex = state.totalWords // Past the end
        engine.play()
        #expect(state.currentIndex == 0)
        #expect(state.playbackState == .playing)
    }

    // MARK: - pause()

    @Test("Pause sets state to paused")
    @MainActor func pauseSetsState() {
        let (state, engine) = Self.makeEngine()
        engine.play()
        engine.pause()
        #expect(state.playbackState == .paused)
    }

    // MARK: - togglePlayPause()

    @Test("Toggle from idle starts playing")
    @MainActor func toggleFromIdle() {
        let (state, engine) = Self.makeEngine()
        state.playbackState = .idle
        // Ensure we have text loaded
        engine.togglePlayPause()
        #expect(state.playbackState == .playing)
    }

    @Test("Toggle from playing pauses")
    @MainActor func toggleFromPlaying() {
        let (state, engine) = Self.makeEngine()
        engine.play()
        engine.togglePlayPause()
        #expect(state.playbackState == .paused)
    }

    @Test("Toggle from paused starts playing")
    @MainActor func toggleFromPaused() {
        let (state, engine) = Self.makeEngine()
        engine.play()
        engine.pause()
        engine.togglePlayPause()
        #expect(state.playbackState == .playing)
    }

    @Test("Toggle from finished starts playing")
    @MainActor func toggleFromFinished() {
        let (state, engine) = Self.makeEngine()
        state.playbackState = .finished
        engine.togglePlayPause()
        #expect(state.playbackState == .playing)
    }

    // MARK: - restart()

    @Test("Restart resets index to 0 and pauses")
    @MainActor func restartResetsIndex() {
        let (state, engine) = Self.makeEngine()
        engine.play()
        state.currentIndex = 5
        engine.restart()
        #expect(state.currentIndex == 0)
        #expect(state.playbackState == .paused)
    }

    // MARK: - stop()

    @Test("Stop sets state to idle")
    @MainActor func stopSetsIdle() {
        let (state, engine) = Self.makeEngine()
        engine.play()
        engine.stop()
        #expect(state.playbackState == .idle)
    }

    // MARK: - skipForward()

    @Test("Skip forward advances by one word")
    @MainActor func skipForwardAdvances() {
        let (state, engine) = Self.makeEngine()
        #expect(state.currentIndex == 0)
        engine.skipForward()
        #expect(state.currentIndex == 1)
        #expect(state.playbackState == .paused)
    }

    @Test("Skip forward does not exceed last word index")
    @MainActor func skipForwardClamps() {
        let (state, engine) = Self.makeEngine()
        state.currentIndex = state.totalWords - 1
        engine.skipForward()
        #expect(state.currentIndex == state.totalWords - 1)
    }

    @Test("Skip forward does nothing when there is no text")
    @MainActor func skipForwardWithNoText() {
        let (state, engine) = Self.makeEngine(text: "")
        engine.skipForward()
        #expect(state.currentIndex == 0)
    }

    // MARK: - skipBackward()

    @Test("Skip backward moves back by one word")
    @MainActor func skipBackwardMoves() {
        let (state, engine) = Self.makeEngine()
        state.currentIndex = 5
        engine.skipBackward()
        #expect(state.currentIndex == 4)
        #expect(state.playbackState == .paused)
    }

    @Test("Skip backward does not go below 0")
    @MainActor func skipBackwardClamps() {
        let (state, engine) = Self.makeEngine()
        state.currentIndex = 0
        engine.skipBackward()
        #expect(state.currentIndex == 0)
    }

    // MARK: - nextIndex(after:)

    @Test("Next index advances by one when stopword skipping is off")
    @MainActor func nextIndexWithoutSkipping() {
        let (_, engine) = Self.makeEngine(text: "one of the words")
        #expect(engine.nextIndex(after: 0) == 1)
    }

    @Test("Next index skips a run of stopwords")
    @MainActor func nextIndexSkipsStopwordRun() {
        let (_, engine) = Self.makeEngine(text: "one of the words")
        AppSettings.shared.stopwordSkipping = true
        defer { AppSettings.shared.stopwordSkipping = false }
        #expect(engine.nextIndex(after: 0) == 3)
    }

    @Test("Next index never skips the last word")
    @MainActor func nextIndexKeepsLastWord() {
        let (_, engine) = Self.makeEngine(text: "one of the")
        AppSettings.shared.stopwordSkipping = true
        defer { AppSettings.shared.stopwordSkipping = false }
        #expect(engine.nextIndex(after: 0) == 2)
    }

    // MARK: - adjustWPM(by:)

    @Test("Adjust WPM increases speed")
    @MainActor func adjustWPMUp() {
        let (state, engine) = Self.makeEngine(wpm: 300)
        engine.adjustWPM(by: 50)
        #expect(state.currentWPM == 350)
    }

    @Test("Adjust WPM decreases speed")
    @MainActor func adjustWPMDown() {
        let (state, engine) = Self.makeEngine(wpm: 300)
        engine.adjustWPM(by: -50)
        #expect(state.currentWPM == 250)
    }

    @Test("Adjust WPM clamps to minimum of 50")
    @MainActor func adjustWPMMinClamp() {
        let (state, engine) = Self.makeEngine(wpm: 60)
        engine.adjustWPM(by: -100)
        #expect(state.currentWPM == 50)
    }

    @Test("Adjust WPM clamps to maximum of 1000")
    @MainActor func adjustWPMMaxClamp() {
        let (state, engine) = Self.makeEngine(wpm: 990)
        engine.adjustWPM(by: 100)
        #expect(state.currentWPM == 1000)
    }

    @Test("Adjust WPM while playing restarts the timer (stays playing)")
    @MainActor func adjustWPMWhilePlaying() {
        let (state, engine) = Self.makeEngine(wpm: 300)
        engine.play()
        engine.adjustWPM(by: 10)
        #expect(state.playbackState == .playing)
        #expect(state.currentWPM == 310)
    }
}
