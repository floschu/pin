import Testing
import SwiftUI
@testable import Pin

@Suite("Color Storage")
struct ColorStorageTests {
    // MARK: - Color.Resolved encoding

    @Test("Color.Resolved round-trips through JSON encoding")
    func resolvedRoundTrip() throws {
        let resolved = Color.Resolved(red: 0.5, green: 0.25, blue: 0.75)
        let data = try JSONEncoder().encode(resolved)
        let decoded = try JSONDecoder().decode(Color.Resolved.self, from: data)
        #expect(decoded.red == resolved.red)
        #expect(decoded.green == resolved.green)
        #expect(decoded.blue == resolved.blue)
    }

    @Test("Pure red round-trips losslessly")
    func redRoundTrip() throws {
        let resolved = Color.Resolved(red: 1.0, green: 0.0, blue: 0.0)
        let data = try JSONEncoder().encode(resolved)
        let decoded = try JSONDecoder().decode(Color.Resolved.self, from: data)
        #expect(decoded.red == 1.0)
        #expect(decoded.green == 0.0)
        #expect(decoded.blue == 0.0)
    }

    @Test("Black round-trips losslessly")
    func blackRoundTrip() throws {
        let resolved = Color.Resolved(red: 0.0, green: 0.0, blue: 0.0)
        let data = try JSONEncoder().encode(resolved)
        let decoded = try JSONDecoder().decode(Color.Resolved.self, from: data)
        #expect(decoded.red == 0.0)
        #expect(decoded.green == 0.0)
        #expect(decoded.blue == 0.0)
    }

    // MARK: - Color -> Resolved -> Color

    @Test("Color resolves and reconstructs")
    func colorResolvedReconstruction() {
        let original = Color(red: 0.2, green: 0.4, blue: 0.6)
        let resolved = original.resolve(in: EnvironmentValues())
        let reconstructed = Color(resolved)
        let reResolved = reconstructed.resolve(in: EnvironmentValues())
        #expect(reResolved.red == resolved.red)
        #expect(reResolved.green == resolved.green)
        #expect(reResolved.blue == resolved.blue)
    }

    // MARK: - AppSettings.orpColor

    @Test("AppSettings orpColor defaults to red")
    @MainActor func defaultOrpColor() {
        let settings = AppSettings.shared
        let resolved = settings.orpColor.resolve(in: EnvironmentValues())
        // Default is approximately #FF2600 (red: 1.0, green: 0.149, blue: 0.0)
        #expect(resolved.red > 0.9)
        #expect(resolved.green < 0.2)
        #expect(resolved.blue < 0.1)
    }

    @Test("AppSettings orpColor setter persists to UserDefaults")
    @MainActor func orpColorPersistence() throws {
        let settings = AppSettings.shared
        let testColor = Color(red: 0.1, green: 0.2, blue: 0.3)
        settings.orpColor = testColor

        // Verify data was written to UserDefaults
        let data = UserDefaults.standard.data(forKey: "orpColor")
        #expect(data != nil)

        // Verify the getter reconstructs the same resolved values
        let readBack = settings.orpColor.resolve(in: EnvironmentValues())
        let original = testColor.resolve(in: EnvironmentValues())
        #expect(abs(readBack.red - original.red) < 0.001)
        #expect(abs(readBack.green - original.green) < 0.001)
        #expect(abs(readBack.blue - original.blue) < 0.001)

        // Restore default
        settings.orpColor = Color(red: 1.0, green: 0.149, blue: 0.0)
    }
}
