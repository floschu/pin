import Testing
@testable import Pin

@Suite("ORPCalculator")
struct ORPCalculatorTests {
    // MARK: - orpIndex(for:)

    @Test("Empty string returns 0")
    func orpIndexEmptyString() {
        #expect(ORPCalculator.orpIndex(for: "") == 0)
    }

    @Test("Single character returns index 0")
    func orpIndexSingleChar() {
        #expect(ORPCalculator.orpIndex(for: "I") == 0)
    }

    @Test("2-character word returns index 1")
    func orpIndex2Chars() {
        #expect(ORPCalculator.orpIndex(for: "is") == 1)
    }

    @Test("5-character word returns index 1")
    func orpIndex5Chars() {
        #expect(ORPCalculator.orpIndex(for: "hello") == 1)
    }

    @Test("6-character word returns index 2")
    func orpIndex6Chars() {
        #expect(ORPCalculator.orpIndex(for: "stream") == 2)
    }

    @Test("9-character word returns index 2")
    func orpIndex9Chars() {
        #expect(ORPCalculator.orpIndex(for: "wonderful") == 2)
    }

    @Test("10-character word returns index 3")
    func orpIndex10Chars() {
        #expect(ORPCalculator.orpIndex(for: "incredible") == 3)
    }

    @Test("13-character word returns index 3")
    func orpIndex13Chars() {
        #expect(ORPCalculator.orpIndex(for: "communication") == 3)
    }

    @Test("14-character word returns index 4")
    func orpIndex14Chars() {
        #expect(ORPCalculator.orpIndex(for: "representation") == 4)
    }

    @Test("Very long word (20+ chars) returns index 4")
    func orpIndexVeryLongWord() {
        #expect(ORPCalculator.orpIndex(for: "internationalization") == 4)
    }

    // MARK: - Boundary tests

    @Test(
        "ORP index boundaries",
        arguments: [
            (1, 0), (2, 1), (3, 1), (4, 1), (5, 1),
            (6, 2), (7, 2), (8, 2), (9, 2),
            (10, 3), (11, 3), (12, 3), (13, 3),
            (14, 4), (15, 4), (20, 4),
        ]
    )
    func orpIndexBoundaries(length: Int, expectedIndex: Int) {
        let word = String(repeating: "x", count: length)
        #expect(ORPCalculator.orpIndex(for: word) == expectedIndex)
    }

    // MARK: - split(word:)

    @Test("Split empty string returns space as pinned")
    func splitEmptyString() {
        let result = ORPCalculator.split(word: "")
        #expect(result.before.isEmpty)
        #expect(result.pinned == " ")
        #expect(result.after.isEmpty)
    }

    @Test("Split single character")
    func splitSingleChar() {
        let result = ORPCalculator.split(word: "A")
        #expect(result.before.isEmpty)
        #expect(result.pinned == "A")
        #expect(result.after.isEmpty)
    }

    @Test("Split 2-character word")
    func split2Chars() {
        let result = ORPCalculator.split(word: "Hi")
        #expect(result.before == "H")
        #expect(result.pinned == "i")
        #expect(result.after.isEmpty)
    }

    @Test("Split 5-character word")
    func split5Chars() {
        let result = ORPCalculator.split(word: "Hello")
        #expect(result.before == "H")
        #expect(result.pinned == "e")
        #expect(result.after == "llo")
    }

    @Test("Split 6-character word")
    func split6Chars() {
        let result = ORPCalculator.split(word: "stream")
        #expect(result.before == "st")
        #expect(result.pinned == "r")
        #expect(result.after == "eam")
    }

    @Test("Split 10-character word")
    func split10Chars() {
        let result = ORPCalculator.split(word: "incredible")
        #expect(result.before == "inc")
        #expect(result.pinned == "r")
        #expect(result.after == "edible")
    }

    @Test("Split 14-character word")
    func split14Chars() {
        let result = ORPCalculator.split(word: "representation")
        #expect(result.before == "repr")
        #expect(result.pinned == "e")
        #expect(result.after == "sentation")
    }

    @Test("Before + pinned + after reconstructs the original word")
    func splitReconstructsWord() {
        let words = ["I", "am", "the", "quick", "stream", "wonderful", "incredible", "representation"]
        for word in words {
            let result = ORPCalculator.split(word: word)
            let reconstructed = result.before + String(result.pinned) + result.after
            #expect(reconstructed == word, "Failed to reconstruct '\(word)'")
        }
    }

    @Test("Split handles Unicode characters")
    func splitUnicodeChars() {
        let result = ORPCalculator.split(word: "cafe\u{0301}") // "café" as 5 characters
        #expect(result.before.count + 1 + result.after.count == "cafe\u{0301}".count)
    }
}
