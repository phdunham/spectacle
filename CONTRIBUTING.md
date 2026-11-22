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

The tests use XCTest and live in `SpectacleTests/`. They run hosted in the app, but Spectacle skips its normal start-up (hot keys, status item, permission dialog) while tests run. Some guidelines:

* **Window placement:** add a case to the calculation tests for new math, and to `SpectacleWindowPositionManagerTests` for anything that changes where windows end up. Those tests run the real pipeline with fake screens (`SpectacleFakeScreen`) and fake windows (`SpectacleFakeWindowElement`, which can simulate minimum sizes and size increments).
* **Coordinates:** expectations are easiest to write in Cocoa coordinates (bottom-left origin, like `NSScreen.visibleFrame`) and convert with `SPTAccessibilityRect`.
* **Global state:** tests that set `+[SpectacleAccessibilityElement setPrimaryScreenFrameOverride:]` must reset it in `tearDown`. Never write to the user's real defaults or `~/Library/Application Support/Spectacle`; `SpectacleShortcutJSONStorage` accepts a file URL for tests.
* **Light and Dark Mode:** UI changes should keep `SpectacleAppearanceTests`, `SpectaclePreferencesWindowTests` and `SpectacleAccessibilitySettingsIllustrationTests` passing, and add to them where it makes sense. Prefer system or dynamic colors over fixed ones. Custom views must draw from their own bounds, not the rect passed to `drawRect:` (macOS 14 and later no longer clip views to their bounds by default).
* **Real windows:** `SpectacleLiveAccessibilityTests` moves a real TextEdit window and is skipped unless you opt in; see the README for how to run it. Run it when you change how windows are moved (`SpectacleAccessibilityElement`, the window movers).

Each bug fix should come with a test that fails without the fix.

## Pull requests

1. Create a branch from `main`.
2. Add tests for your change.
3. Run the test suite and make sure it passes, with no new build warnings.
4. Rebase on the latest `main` before opening the pull request, and describe what you changed and how you tested it (including which macOS version).

## Coding style

Match the existing Objective-C style: two spaces for indentation, braces on their own line for methods, and descriptive names (`SpectacleWindowPositionManager`, `moveFrontmostWindowElement:action:`). New source files go in `Spectacle/Sources/` with a `Spectacle` prefix. Avoid APIs deprecated in the current macOS SDK.

## Versioning

The version is `MARKETING_VERSION` in `project.yml` (1.3.0 is the first release of this fork; the original's last release was 1.2). Use 1.3.x for fixes and 1.4.0 for new features. The build number is set automatically from the number of git commits.

## License

By contributing you agree that your contributions are licensed under the project's MIT license (see LICENSE.md). The original code is copyright © Eric Czarny.
