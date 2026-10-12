import Foundation

/// Tokenizes text into individual words for RSVP display.
enum TextTokenizer {
    /// Common stopwords that convey minimal meaning.
    static let stopwords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "is", "am", "are", "was",
        "were", "be", "been", "being", "in", "on", "at", "to", "for",
        "of", "with", "by", "as", "it", "its", "this", "that", "from",
    ]

    /// Result of tokenizing text, containing clean words and structural pause info.
    struct TokenizedText {
        let words: [String]
        /// Maps word index to a pause multiplier applied to the *previous* word's
        /// display interval, creating a pause before this word is shown.
        let pauseBefore: [Int: Double]
    }

    /// Split text into words, recognizing structural elements like newlines
    /// and paragraph breaks.
    static func tokenize(_ text: String) -> TokenizedText {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return TokenizedText(words: [], pauseBefore: [:]) }

        var words: [String] = []
        var pauseBefore: [Int: Double] = [:]

        let lines = trimmed.components(separatedBy: .newlines)

        var previousWasEmpty = false
        var isFirstContent = true

        for line in lines {
            let stripped = line.trimmingCharacters(in: .whitespaces)

            if stripped.isEmpty {
                previousWasEmpty = true
                continue
            }

            // Split on whitespace
            let lineWords = stripped
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            guard !lineWords.isEmpty else { continue }

            // Record structural pauses between sections
            if !isFirstContent {
                let nextIndex = words.count
                if previousWasEmpty {
                    // Paragraph break (blank line): longer pause
                    pauseBefore[nextIndex] = 2.5
                } else {
                    // Line break (no blank line): shorter pause
                    pauseBefore[nextIndex] = 1.5
                }
            }

            words.append(contentsOf: lineWords)
            isFirstContent = false
            previousWasEmpty = false
        }

        return TokenizedText(words: words, pauseBefore: pauseBefore)
    }

    /// Check if a word ends a sentence (ends with . ? ! or ...).
    static func isSentenceEnd(_ word: String) -> Bool {
        guard let last = word.last else { return false }
        return last == "." || last == "?" || last == "!" || last == "\u{2026}"
    }

    /// Check if a word ends at a clause boundary (ends with , ; or :).
    static func isClauseBoundary(_ word: String) -> Bool {
        guard let last = word.last else { return false }
        return last == "," || last == ";" || last == ":"
    }

    /// Check if a word is a stopword (case insensitive, ignoring punctuation).
    static func isStopword(_ word: String) -> Bool {
        let cleaned = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        return stopwords.contains(cleaned)
    }
}
