import Foundation

/// Represents the playback state of the speed reader.
enum PlaybackState: Equatable {
    case idle
    case playing
    case paused
    case finished
}

/// Observable state for the RSVP reader session.
@MainActor @Observable
final class ReaderState {
    var words: [String] = []
    /// Structural pause multipliers: maps word index to a multiplier applied
    /// to the previous word's display interval (e.g. line break = 1.5x, paragraph = 2.5x).
    var pauseBefore: [Int: Double] = [:]
    var currentIndex: Int = 0
    var playbackState: PlaybackState = .idle
    var currentWPM: Int = 300

    var currentWord: String {
        guard !words.isEmpty, currentIndex >= 0, currentIndex < words.count else { return "" }
        return words[currentIndex]
    }

    var totalWords: Int { words.count }

    var isActive: Bool {
        playbackState == .playing || playbackState == .paused
    }

    var hasText: Bool { !words.isEmpty }

    var errorMessage: String?

    func load(text: String, wpm: Int) {
        self.errorMessage = nil
        let tokenized = TextTokenizer.tokenize(text)
        self.words = tokenized.words
        self.pauseBefore = tokenized.pauseBefore
        self.currentIndex = 0
        self.currentWPM = wpm
        self.playbackState = .paused
    }

    func reset() {
        words = []
        pauseBefore = [:]
        currentIndex = 0
        playbackState = .idle
        errorMessage = nil
    }
}
