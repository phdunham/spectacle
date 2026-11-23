# Contributing

This repository ([phdunham/spectacle](https://github.com/phdunham/spectacle)) is an **unofficial, personally maintained fork** of [eczarny/spectacle](https://github.com/eczarny/spectacle). The original project is no longer maintained or supported, so please don't open issues or pull requests there for problems with this fork; open them here instead.

The fork is maintained for personal use. Issues and pull requests are welcome, but there is no promise of support or of a timely response.

## Issues

Before opening an issue, check that it hasn't been reported already and read the [common issues](README.md#common-issues) in the README. Please include:

* the Spectacle version (shown in the About window, e.g. 1.3.0) and how you built or installed it;
* the macOS version;
* the app whose window misbehaved, and the shortcut you used;
* your display setup if more than one display is involved (sizes and how they are arranged);
* any relevant Spectacle output from the Console app (search for "Spectacle").

Screenshots or screen recordings help a lot.

If Spectacle keeps asking for Accessibility access although it is switched on in System Settings, see [Code signing and Accessibility access](README.md#code-signing-and-accessibility-access) first.

## Development setup

Requirements: macOS 14 or later, Xcode 16 or later, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). There are no other dependencies.

`Spectacle.xcodeproj` is generated from `project.yml`. When you add, remove or rename files, or change build settings, edit `project.yml` and run:

    $ xcodegen generate

Commit both `project.yml` and the regenerated project.

Code signing is ad hoc by default. To use your own Apple Development certificate (so Accessibility access survives rebuilds), create `Configuration/Local.xcconfig`, which git ignores; see the README.

## Tests

Run the whole suite before opening a pull request:

    $ xcodebuild test -project Spectacle.xcodeproj -scheme Spectacle -derivedDataPath build/DerivedData

The tests use Swift Testing (`import Testing`, `@Test`, `#expect`) and live in `SpectacleTests/`. They run hosted in the app (`@testable import Spectacle`), but Spectacle skips its normal start-up (hot keys, status item, dialogs) while tests run. Some guidelines:

* **Window placement:** the layout math is in `WindowLayout.swift`; add cases to `WindowLayoutTests.swift`. For anything that changes where windows end up, add to `WindowPositionManagerTests.swift`, which runs the real pipeline with fake screens (`FakeScreen`) and fake windows (`FakeWindow`, which can simulate minimum sizes, size steps, sheets and dialogs). Don't change `OriginalLayoutExpectationTests.swift` unless the layout is meant to change.
* **Coordinates:** expectations are easiest to write in Cocoa coordinates (bottom-left origin, like `NSScreen.visibleFrame`) and convert with `accessibilityRect(_:primaryHeight:)`.
* **Parallel tests and global state:** Swift Testing runs tests in parallel. Wrap code that converts coordinates in `withPrimaryScreen(_:_:)`, which sets the primary screen only for the duration of the call. Never write to the user's real defaults or `~/Library/Application Support/Spectacle`: use `UserDefaults(suiteName:)` and `JSONShortcutStorage(fileURL:)`. Unregister any hot keys a test registers.
* **Light and Dark Mode:** UI changes should keep `InterfaceTests.swift` passing, and add to it where it makes sense. Prefer system or dynamic colors over fixed ones. Custom AppKit views must draw from their bounds, not the rect passed to `draw(_:)` (macOS 14 and later no longer clip views to their bounds by default).
* **Alerts:** anything that would show a modal alert must let tests replace it (see `PreferencesModel.confirmRestoreDefaults` and `ShortcutRecorder.reportRejectedShortcut`); a modal alert blocks the test run.
* **Real windows:** run `LiveAccessibilityTests` (see the README) when you change how windows are moved (`AccessibilityElement`, the window movers).

Each bug fix should come with a test that fails without the fix.

## Pull requests

1. Create a branch from `main`.
2. Add tests for your change.
3. Run the test suite and make sure it passes, with no new build warnings.
4. Rebase on the latest `main` before opening the pull request, and describe what you changed and how you tested it (including which macOS version).

## Coding style

The app is Swift 6 with complete concurrency checking; keep it free of warnings.

* Two spaces for indentation; Swift API naming.
* Pure logic (layout math, key bindings) in value types or `enum` namespaces, so it can be tested without AppKit.
* Anything touching AppKit, the Accessibility API or hot keys is `@MainActor`.
* User-facing text goes through `NSLocalizedString` or SwiftUI's `LocalizedStringKey`, keyed by the English text, with translations in `Spectacle/Resources/Localizations/*.lproj/Localizable.strings`.

Source files go in `Spectacle/Sources/`. Avoid APIs deprecated in the current macOS SDK.

## Versioning

The version is `MARKETING_VERSION` in `project.yml` (1.3.0 is the first release of this fork; the original's last release was 1.2). Use 1.3.x for fixes and 1.4.0 for new features. The build number is set automatically from the number of git commits.

## License

By contributing you agree that your contributions are licensed under the project's MIT license (see LICENSE.md). The original code is copyright © Eric Czarny.
