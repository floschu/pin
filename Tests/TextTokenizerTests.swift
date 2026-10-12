import Testing
@testable import Pin

@Suite("TextTokenizer")
struct TextTokenizerTests {
    // MARK: - tokenize(_:)

    @Test("Empty string returns empty result")
    func tokenizeEmpty() {
        let result = TextTokenizer.tokenize("")
        #expect(result.words.isEmpty)
        #expect(result.pauseBefore.isEmpty)
    }

    @Test("Whitespace-only string returns empty result")
    func tokenizeWhitespace() {
        let result = TextTokenizer.tokenize("   \n\n  \t  ")
        #expect(result.words.isEmpty)
        #expect(result.pauseBefore.isEmpty)
    }

    @Test("Single word")
    func tokenizeSingleWord() {
        let result = TextTokenizer.tokenize("Hello")
        #expect(result.words == ["Hello"])
        #expect(result.pauseBefore.isEmpty)
    }

    @Test("Multiple words on one line")
    func tokenizeMultipleWords() {
        let result = TextTokenizer.tokenize("The quick brown fox")
        #expect(result.words == ["The", "quick", "brown", "fox"])
        #expect(result.pauseBefore.isEmpty)
    }

    @Test("Multiple spaces between words are collapsed")
    func tokenizeMultipleSpaces() {
        let result = TextTokenizer.tokenize("hello    world")
        #expect(result.words == ["hello", "world"])
    }

    @Test("Line break inserts 1.5x pause")
    func tokenizeLineBreak() {
        let result = TextTokenizer.tokenize("first line\nsecond line")
        #expect(result.words == ["first", "line", "second", "line"])
        // Pause before "second" (index 2) should be 1.5
        #expect(result.pauseBefore[2] == 1.5)
    }

    @Test("Paragraph break (blank line) inserts 2.5x pause")
    func tokenizeParagraphBreak() {
        let result = TextTokenizer.tokenize("first paragraph\n\nsecond paragraph")
        #expect(result.words == ["first", "paragraph", "second", "paragraph"])
        // Pause before "second" (index 2) should be 2.5
        #expect(result.pauseBefore[2] == 2.5)
    }

    @Test("Multiple blank lines still produce a single paragraph pause")
    func tokenizeMultipleBlankLines() {
        let result = TextTokenizer.tokenize("above\n\n\n\nbelow")
        #expect(result.words == ["above", "below"])
        #expect(result.pauseBefore[1] == 2.5)
    }

    @Test("Leading/trailing whitespace and newlines are trimmed")
    func tokenizeTrimming() {
        let result = TextTokenizer.tokenize("\n\n  Hello world  \n\n")
        #expect(result.words == ["Hello", "world"])
        #expect(result.pauseBefore.isEmpty)
    }

    @Test("Mixed line breaks and paragraph breaks")
    func tokenizeMixedBreaks() {
        let text = "Line one\nLine two\n\nParagraph two"
        let result = TextTokenizer.tokenize(text)
        #expect(result.words == ["Line", "one", "Line", "two", "Paragraph", "two"])
        // Line break before "Line" at index 2
        #expect(result.pauseBefore[2] == 1.5)
        // Paragraph break before "Paragraph" at index 4
        #expect(result.pauseBefore[4] == 2.5)
    }

    @Test("No pause before the first content")
    func tokenizeNoPauseAtStart() {
        let result = TextTokenizer.tokenize("Hello world")
        #expect(result.pauseBefore[0] == nil)
    }

    // MARK: - isSentenceEnd(_:)

    @Test("Period ends a sentence")
    func sentenceEndPeriod() {
        #expect(TextTokenizer.isSentenceEnd("end."))
    }

    @Test("Question mark ends a sentence")
    func sentenceEndQuestion() {
        #expect(TextTokenizer.isSentenceEnd("what?"))
    }

    @Test("Exclamation mark ends a sentence")
    func sentenceEndExclamation() {
        #expect(TextTokenizer.isSentenceEnd("wow!"))
    }

    @Test("Ellipsis character ends a sentence")
    func sentenceEndEllipsis() {
        #expect(TextTokenizer.isSentenceEnd("wait\u{2026}"))
    }

    @Test("Word without punctuation is not a sentence end")
    func sentenceEndNoPunctuation() {
        #expect(!TextTokenizer.isSentenceEnd("hello"))
    }

    @Test("Comma is not a sentence end")
    func sentenceEndComma() {
        #expect(!TextTokenizer.isSentenceEnd("however,"))
    }

    @Test("Empty string is not a sentence end")
    func sentenceEndEmpty() {
        #expect(!TextTokenizer.isSentenceEnd(""))
    }

    // MARK: - isClauseBoundary(_:)

    @Test("Comma is a clause boundary")
    func clauseComma() {
        #expect(TextTokenizer.isClauseBoundary("however,"))
    }

    @Test("Semicolon is a clause boundary")
    func clauseSemicolon() {
        #expect(TextTokenizer.isClauseBoundary("done;"))
    }

    @Test("Colon is a clause boundary")
    func clauseColon() {
        #expect(TextTokenizer.isClauseBoundary("note:"))
    }

    @Test("Period is not a clause boundary")
    func clausePeriod() {
        #expect(!TextTokenizer.isClauseBoundary("end."))
    }

    @Test("Word without punctuation is not a clause boundary")
    func clauseNoPunctuation() {
        #expect(!TextTokenizer.isClauseBoundary("hello"))
    }

    @Test("Empty string is not a clause boundary")
    func clauseEmpty() {
        #expect(!TextTokenizer.isClauseBoundary(""))
    }

    // MARK: - isStopword(_:)

    @Test("'the' is a stopword")
    func stopwordThe() {
        #expect(TextTokenizer.isStopword("the"))
    }

    @Test("Case insensitive: 'The' is a stopword")
    func stopwordTheCased() {
        #expect(TextTokenizer.isStopword("The"))
    }

    @Test("Strips punctuation: 'the,' is a stopword")
    func stopwordWithPunctuation() {
        #expect(TextTokenizer.isStopword("the,"))
    }

    @Test("'and' is a stopword")
    func stopwordAnd() {
        #expect(TextTokenizer.isStopword("and"))
    }

    @Test("'hello' is not a stopword")
    func notStopword() {
        #expect(!TextTokenizer.isStopword("hello"))
    }

    @Test("Empty string is not a stopword")
    func stopwordEmpty() {
        #expect(!TextTokenizer.isStopword(""))
    }

    @Test("All defined stopwords are recognized")
    func allStopwordsRecognized() {
        for word in TextTokenizer.stopwords {
            #expect(TextTokenizer.isStopword(word), "'\(word)' should be recognized as a stopword")
        }
    }
}
