import Foundation

/// Calculates the Optimal Recognition Point (ORP) for a word.
/// The ORP is the letter your eye should fixate on for fastest recognition.
/// It is typically about 1/3 from the left, adjusted for word length.
enum ORPCalculator {
    /// Returns the index of the ORP character for the given word.
    /// Uses the canonical Spritz algorithm based on Optimal Viewing Position research.
    static func orpIndex(for word: String) -> Int {
        let length = word.count
        guard length > 0 else { return 0 }

        switch length {
        case 1:      return 0  // 1 char: 1st letter
        case 2...5:  return 1  // 2-5 chars: 2nd letter
        case 6...9:  return 2  // 6-9 chars: 3rd letter
        case 10...13: return 3 // 10-13 chars: 4th letter
        default:     return 4  // 14+ chars: 5th letter
        }
    }

    /// Splits a word into (before, pinned, after) around the ORP index.
    static func split(word: String) -> (before: String, pinned: Character, after: String) {
        let idx = orpIndex(for: word)
        let chars = Array(word)
        guard !chars.isEmpty else {
            return ("", " ", "")
        }
        let safeIdx = min(idx, chars.count - 1)
        let before = String(chars[0..<safeIdx])
        let pinned = chars[safeIdx]
        let after = safeIdx + 1 < chars.count ? String(chars[(safeIdx + 1)...]) : ""
        return (before, pinned, after)
    }
}
