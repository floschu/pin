# AGENTS.md

## Project Overview

Pin is a macOS menu bar speed-reading app (RSVP). Swift 6.2, macOS 26.0+, zero external dependencies. Dual build system: XcodeGen (`project.yml`) and SPM (`Package.swift`). The app is an LSUIElement (menu bar agent, no Dock icon).

## Build / Lint / Test Commands

```bash
# Build (SPM)
swift build

# Run all tests
swift test

# Run a single test suite
swift test --filter PinTests.ORPCalculatorTests

# Run a single test by name
swift test --filter PinTests.ORPCalculatorTests/orpIndexSingleChar

# Run parameterized test
swift test --filter "PinTests.ORPCalculatorTests/ORP index boundaries"

# Regenerate Xcode project from project.yml (requires xcodegen)
xcodegen generate

# SwiftLint (if installed)
swiftlint
```

CI (`.github/workflows/ci.yml`) runs `swift build`, `swift test`, and `swiftlint` on pushes to `develop` and on pull requests. `.github/workflows/release.yml` builds an ad-hoc signed `Pin.app` on tag push (`vX.Y.Z`), passes the version from the tag as `MARKETING_VERSION`, and attaches a zip to the GitHub Release. Version and build number live in `project.yml`, `Info.plist` references them.

The app is ad-hoc signed (`CODE_SIGN_IDENTITY: "-"`) and not notarized. Do not add a development team or notarization steps.

## Project Structure

```
Pin/
  Sources/
    PinApp.swift              # @main App entry point
    Models/                   # State and settings
    Services/                 # Business logic and system integration
    Views/                    # SwiftUI views + AppKit bridging
  Resources/
    Info.plist
    Pin.entitlements
    AppIcon.icon/
Tests/                        # Swift Testing test files
Package.swift                 # SPM manifest
project.yml                   # XcodeGen spec
.swiftlint.yml
LICENSE                       # MIT
CONTRIBUTING.md
```

## Code Style

### Imports

Order by relevance, not alphabetically. No blank lines between imports. Typically 2-4 imports per file.

```swift
import SwiftUI
import AppKit
import Carbon.HIToolbox
```

In test files: `import Testing` first, then framework imports, then `@testable import Pin`.

### Access Control

- Explicit `private` on all implementation details (vars, funcs, init).
- Never write `internal` explicitly (it is the default).
- No `public` or `open` (single-module app).
- Use `private(set)` for externally readable but internally mutable properties.
- Use `fileprivate` only when a file-scope function needs access to a type's internals.

### Types

- **Every class must be `final`.**
- Caseless `enum` for static-only types (namespaces): `enum ORPCalculator { static func ... }`.
- `struct` for SwiftUI views and value types.
- `final class` for reference-type services and state objects.
- `enum` with cases for domain models (`PlaybackState`, `SettingsPage`).
- Singletons use `static let shared` with `private init()`.

### Naming

- Types: `UpperCamelCase` (e.g., `RSVPEngine`, `ORPCalculator`).
- Properties, variables, methods, enum cases: `lowerCamelCase`.
- Acronyms uppercase in type names (`ORP`, `RSVP`, `WPM`), lowercase in property names (`orpEnabled`, `currentWPM`).
- Booleans: prefix with `is`/`has` (e.g., `isVisible`, `hasText`, `hasCompletedOnboarding`).
- Closures/callbacks: prefix with `on` (e.g., `onFinished`, `onDismiss`, `onRecorded`).

### Formatting

- **Trailing commas required** in multiline collections (the `trailing_comma` SwiftLint rule is disabled for this reason).
- Max line length: 140 (warning), 200 (error). URLs and comments are excluded.
- Max 2 consecutive empty lines.
- Use `// MARK: - Section Name` (with dash) to organize every logical section in a file.

### Documentation

- `///` doc comments on all type declarations and significant methods.
- Single-line preferred; multiline with blank `///` separator for longer explanations.
- Inline `//` comments for implementation clarification.
- No `/* */` block comments. No `TODO`/`FIXME` comments.

### Error Handling

- No `throw`/`catch`. Errors are handled via optionals, `guard`/early return, and error state strings (`ReaderState.errorMessage: String?`).
- Use `os.Logger` with privacy-aware interpolation for logging (`TextCaptureService`, `HotkeyService`).
- `force_cast` and `force_try` are **forbidden** (SwiftLint severity: error).
- `force_unwrapping` triggers a warning. Avoid it.

### Guard / Early Return

Use `guard` pervasively for preconditions and optional binding:

```swift
guard state.hasText else { return }
guard let panel = panel else { return }
guard !trimmed.isEmpty else { return TokenizedText(words: [], pauseBefore: [:]) }
```

### Concurrency

- `@MainActor` on all stateful classes (observable models, services, controllers).
- `MainActor.assumeIsolated { }` in callbacks known to run on main thread (Timer, NotificationCenter with `.main` queue, CGEvent tap).
- `DispatchQueue.main.async` / `.asyncAfter` for deferred main-thread execution.
- No `async`/`await` or structured concurrency. No Combine.

### State Management

- **Observation framework only** (`@Observable`, `@Bindable`). No Combine, no `ObservableObject`, no `@Published`.
- `withObservationTracking` for manual observation outside SwiftUI views (e.g., `ReaderPanelController`).
- `@State private var` for local SwiftUI view state.

### SwiftUI / AppKit

Hybrid approach: SwiftUI for all views, AppKit for system integration (NSPanel, NSEvent monitors, NSPasteboard, AXUIElement). Bridge with `NSViewRepresentable` and `NSHostingView`.

## Testing

Uses **Swift Testing** framework (not XCTest).

```swift
import Testing
@testable import Pin

@Suite("ORPCalculator")
struct ORPCalculatorTests {
    @Test("Single character returns index 0")
    func orpIndexSingleChar() {
        #expect(ORPCalculator.orpIndex(for: "I") == 0)
    }

    @Test("ORP index boundaries", arguments: [(1, 0), (2, 1)])
    func orpIndexBoundaries(length: Int, expectedIndex: Int) {
        let word = String(repeating: "x", count: length)
        #expect(ORPCalculator.orpIndex(for: word) == expectedIndex)
    }
}
```

- Test structs, not classes.
- `@Suite("Name")` for grouping; `@Test("Description")` for each test.
- `#expect(...)` for assertions; `Issue.record("message")` for soft failures.
- `@Test("...", arguments: [...])` for parameterized tests.
- MARK comments group tests by the method under test.
- `@MainActor` on individual test methods that need main actor isolation.
- Test helper methods are `private static func`.
- Descriptive method names: `playStartsPlayback()`, `skipForwardClamps()`, `hexWithHash()`.

## SwiftLint

Key rules enforced (see `.swiftlint.yml` for full config):

- `force_cast`: error
- `force_try`: error
- `force_unwrapping`: warning
- `trailing_comma`: **disabled** (we use trailing commas)
- `todo`: disabled
- `line_length`: 140 warn / 200 error
- `function_body_length`: 50 warn / 100 error
- `cyclomatic_complexity`: 12 warn / 20 error
- Identifier min length: 2 (excluded: `id`, `x`, `y`, `r`, `g`, `b`, `i`)
