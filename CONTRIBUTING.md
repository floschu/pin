# Contributing

Bug reports, ideas, and pull requests are welcome. Please open an [issue](https://github.com/floschu/pin/issues) first for larger changes.

## Requirements

- macOS 26.0 or later
- Xcode 26 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for the Xcode project
- [SwiftLint](https://github.com/realm/SwiftLint) (optional, CI runs it)

## Build and run

```
xcodegen generate
open Pin.xcodeproj
```

The project uses ad-hoc signing, so it builds without an Apple Developer account.

Open `Pin.xcodeproj`, not the folder or `Package.swift`. Opening the package in Xcode builds a bare executable without the app bundle, so there is no icon, no `Info.plist`, and Accessibility permission cannot be granted to it.

Pin also builds with Swift Package Manager, which is the fastest way to compile and run the tests:

```
swift build
swift test
swiftlint
```

## Accessibility permission during development

macOS ties the Accessibility grant to the app's code signature. An ad-hoc signature changes on every build, so the grant stops working after a rebuild. Click Request Permission in Settings > General, or run `tccutil reset Accessibility at.florianschuster.pin` and relaunch.

If you rebuild often, create a self-signed certificate for a stable signature:

1. Open Keychain Access > Certificate Assistant > Create a Certificate.
2. Name it, for example `Pin Dev`. Set Certificate Type to "Code Signing".
3. Build with `CODE_SIGN_IDENTITY="Pin Dev"`, for example by setting it in Xcode under Signing & Capabilities for your local build. Do not commit this change.

## Code style

[AGENTS.md](AGENTS.md) describes the conventions: access control, naming, concurrency, Observation, and testing with Swift Testing.

## Releases

Maintainers push a tag:

```
git tag v1.0.0
git push origin v1.0.0
```

The release workflow builds `Pin.app` with the version taken from the tag and the build number from the commit count, and attaches a zip to a new GitHub Release. `MARKETING_VERSION` in `project.yml` is only the fallback for local builds and does not need a bump.
