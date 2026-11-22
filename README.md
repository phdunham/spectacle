# Spectacle (unofficial fork)

Easily organize windows without using a mouse.

> **This is an unofficial fork.** It is based on [eczarny/spectacle](https://github.com/eczarny/spectacle), which is **no longer maintained or supported** by its original author. This fork ([phdunham/spectacle](https://github.com/phdunham/spectacle)) is maintained for personal use and updated for current versions of macOS. Please don't report problems with this version to the original project. The app's About window says the same.

## About this fork

Changes from upstream Spectacle 1.2 (this fork is version 1.3.0):

- Builds with current Xcode and the macOS SDK; requires **macOS 14 Sonoma or later** (tested on macOS 27).
- No third-party dependencies: Carthage, Sparkle (whose update feed no longer exists), Specta, Expecta, OCHamcrest and OCMockito were removed. The tests use XCTest.
- The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).
- Fixed: windows of many apps (Chrome and other Chromium/Electron apps, Microsoft Office, Firefox, ...) ending up at the wrong size or position for Fullscreen, Left Half, etc. Spectacle now turns off the app's `AXEnhancedUserInterface` setting while it resizes the window, then turns it back on.
- Fixed: changing a shortcut in Preferences, or using "Restore Defaults", disabled that shortcut until Spectacle was restarted.
- "Launch Spectacle at login" uses `SMAppService` (the old API stopped working on macOS 13).
- The accessibility prompt opens System Settings > Privacy & Security > Accessibility and closes itself once access is granted. Its buttons are now easy to see in Light and Dark Mode (blue "Open System Settings", grey "Quit Spectacle"; Return opens Settings, Escape quits). The old macOS 10.14 screenshot is replaced by a drawing of the current System Settings > Privacy & Security > Accessibility page, which switches between Light and Dark Mode with the system. To preview the dialog when access is already granted, run `open /Applications/Spectacle.app --args -SpectacleShowAccessibilityDialog YES`.
- Fixed: on macOS 14 and later the Preferences window was covered by a huge white rounded shape, because the shortcut fields drew outside their own bounds.
- The About window says this is an unofficial fork of the original project, which is no longer supported.
- Several smaller fixes: crashes on unusual accessibility values or a corrupt shortcuts file, a memory leak in the shortcut conflict check, and a broken display ordering comparison.

## Original note from the author

**This project is not being actively maintained.** Unfortunately, after almost a decade of on-and-off development I can no longer dedicate the time needed to be a responsible maintainer of this project. Spectacle will remain available for download but please use at your own risk. The source code will continue to be free and open to anyone, so feel free to make Spectacle your own.

Thanks to all the folks that have made Spectacle the first app they install a new Mac!

_Spectacle users have recommended [Rectangle](https://github.com/rxhanson/Rectangle) as an open source alternative._

## System requirements

This fork requires macOS 14 Sonoma or later. (Upstream Spectacle [0.8.6][1] was the last version to support Mac OS X 10.7, and [0.7][2] the last to support 10.6.)

## Keyboard Shortcuts

Spectacle makes use of several [keyboard shortcuts][3] that trigger specific _window actions_. A window action is nothing more than a command that tells Spectacle how to change the size and/or position of a particular window.

A keyboard shortcut consists of one or more modifier keys paired with a character key. The common modifier keys Spectacle takes advantage of are:

| Symbol    | Key         |
|:---------:|:-----------:|
|  &#8984;  | Command Key |
|  &#8963;  | Control Key |
|  &#8997;  | Option Key  |
|  &#8679;  | Shift Key   |

The default keyboard shortcuts can be changed at any time. Use new key combinations to trigger window actions, or clear particular keyboard shortcuts to disable window actions entirely.

### Basic window actions

To move a window to the center of the screen use the &#8997;&#8984;C keyboard shortcut. Centered windows will __not__ have their size altered. Maximize a window using the &#8997;&#8984;F shortcut.

Windows can be moved to a number of predefined regions of the screen:

- _Move to the left half_ &#8212; &#8997;&#8984;&#8592;
- _Move to the right half_ &#8212; &#8997;&#8984;&#8594;
- _Move to the top half_ &#8212; &#8997;&#8984;&#8593;
- _Move to the bottom half_ &#8212; &#8997;&#8984;&#8595;
<br /><br />
- _Move to the upper left_ &#8212; &#8963;&#8984;&#8592;
- _Move to the lower left_ &#8212; &#8963;&#8679;&#8984;&#8592;
- _Move to the upper right_ &#8212; &#8963;&#8984;&#8594;
- _Move to the lower right_ &#8212; &#8963;&#8679;&#8984;&#8594;

Windows may also be resized between thirds using any of the shortcuts above. For example, to have a window resized between 1/3 and 2/3 of the left region of the screen simply activate the *left half* &#8997;&#8984;&#8592; keyboard shortcut more than once. Each time the shortcut is activated Spectacle will move the window between 1/3, 2/3, and back to 1/2 of the left side of the screen. This feature also applies to the upper left, lower left, upper right, and lower right shortcuts.

Spectacle can also move windows between horizontal and vertical thirds of the screen. The &#8963;&#8997;&#8594; keyboard shortcut will move a window to the next third of the screen, starting with the horizontal third region on the left of the screen. &#8963;&#8997;&#8592; will move a window to the previous third of the screen.

Resizing a window is just as easy. To make a window a bit larger use the &#8963;&#8997;&#8679;&#8594; keyboard shortcut; &#8963;&#8997;&#8679;&#8592; can be used to make a window smaller. Spectacle will always attempt to maintain contact between the edges of a window and the edges of the screen when resizing.

### Multiple displays

The &#8963;&#8997;&#8984;&#8594; keyboard shortcut will move a window to the next available display. &#8963;&#8997;&#8984;&#8592; can be used to move a window to the previous display.

### Window action history

Spectacle remembers where every window was prior to executing a window action. To undo a window action use the &#8997;&#8984;Z keyboard shortcut. Use the &#8997;&#8679;&#8984;Z shortcut to redo the window action once again.

## Common Issues

### Spectacle is requesting access to use accessibility features

Apple's [OS X Accessibility Protocol][4] makes Spectacle possible. This protocol allows assistive applications to _drive the user interface of another application running in OS X_. In order to do its job Spectacle must be granted access to use these accessibility features. Instructions to do so will be displayed if Spectacle determines it does not have sufficient privileges.

### Spectacle does not resize a particular window as expected

OS X allows applications to place constraints on the size of its windows. This allows application developers to design their user interfaces without needing to worry about supporting every possible window dimension. In these cases Spectacle will not be able to resize those windows to fit into the exact dimensions intended by the shortcut used.

As an example suppose a display has a 2880x1800 resolution and a window is being resized to fit the left half of the display. If the window has specified a minimum allowable width of 1600 pixels Spectacle will not be able to resize the window to fit the expected 1440 pixels. The constraints placed on windows will always be respected despite leading to potentially unexpected results; in this example Spectacle will resize the window's width to 1600 pixels.

### Spectacle behaves strangely with Terminal windows

Terminal (and other terminal emulation applications like iTerm 2) place constraints on how windows are resized so entire rows and columns are always visible. This behavior works great since it guarantees no rows or columns are truncated. Unfortunately it does mean that Spectacle needs to do some extra work to make these windows fit.

To work around the limitations imposed on Terminal windows Spectacle will first try to resize a window to match the desired dimensions. If a window cannot be resized to fit Spectacle will immediately try to make the window a little smaller. This process is repeated until the window can be made to fit with its constraints still in place. The result is a window that is centered within the desired dimensions at the cost of a slightly jittery experience.

### Spectacle does not work with all applications

Most applications built with the Cocoa frameworks can be readily manipulated via the _macOS Accessibility API_; allowing Spectacle to interact with nearly every window it encounters. Unfortunately this is not always the case. Spectacle will be unable to manipulate the windows of applications that build their user interfaces in unexpected ways.

## Building and running

Requirements: Xcode 16 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

    $ xcodegen generate          # regenerate Spectacle.xcodeproj from project.yml
    $ open Spectacle.xcodeproj   # then press ⌘R

Or from the command line:

    $ xcodebuild -project Spectacle.xcodeproj -scheme Spectacle -configuration Release -derivedDataPath build/DerivedData build
    $ open build/DerivedData/Build/Products/Release/Spectacle.app

To install, quit Spectacle and copy the built app to /Applications:

    $ cp -R build/DerivedData/Build/Products/Release/Spectacle.app /Applications/

### Code signing and Accessibility access

macOS ties Accessibility access to the app's code signature. By default the project signs ad hoc ("Sign to Run Locally", set in `Configuration/Signing.xcconfig`), so every rebuild looks like a new app. The "Spectacle" switch in System Settings then belongs to an older build, and Spectacle keeps asking for access even though the switch is on.

To keep the same signature between builds, create `Configuration/Local.xcconfig` (git ignores it) with your own Apple Development identity:

    CODE_SIGN_IDENTITY = Apple Development
    DEVELOPMENT_TEAM = <your team ID>

You can find your team ID with `security find-identity -v -p codesigning`, then `security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject` (it is the `OU=` value).

If Spectacle keeps asking for access although it is switched on: in System Settings > Privacy & Security > Accessibility, select Spectacle, remove it with "−", reopen Spectacle and switch it on again.

### Other window managers

Rectangle, Magnet and similar apps use many of the same default shortcuts (⌥⌘←, ⌥⌘F, ...). Whichever app registers a shortcut first gets it, so quit the other app or change its shortcuts.

## Running the tests

    $ xcodebuild test -project Spectacle.xcodeproj -scheme Spectacle -derivedDataPath build/DerivedData

The suite (`SpectacleTests/`) covers:

- every window calculation (halves, quarters, thirds, center, fullscreen, larger/smaller, next/previous display) and the cycling between 1/2, 2/3 and 1/3, on many screen sizes;
- the full move flow (screen detection, coordinate conversion, calculation, window movers) for every placement action on every display of several multi-display layouts, including displays above, below and left of the main one, a portrait display, Dock positions and a notched menu bar;
- windows that resist resizing (minimum sizes, Terminal-style size increments);
- undo/redo history, kept separately per app;
- shortcut parsing, display strings, storage, migration and registration;
- Light and Dark Mode: the accessibility dialog and the Preferences window are loaded from their real nibs and checked for readable label colors, the default button, standard button styling, and shortcut fields that never draw outside their own bounds.

One live test moves a real TextEdit window through the Accessibility API. It is skipped by default. To run it, give the test host (`build/DerivedData/Build/Products/Debug/Spectacle.app`) Accessibility access, then run:

    $ TEST_RUNNER_SPECTACLE_LIVE_TESTS=1 xcodebuild test -project Spectacle.xcodeproj -scheme Spectacle -derivedDataPath build/DerivedData -only-testing:SpectacleTests/SpectacleLiveAccessibilityTests

# License

Copyright (c) 2017 Eric Czarny.

Spectacle should be accompanied by a LICENSE file containing the license relevant to this distribution.

[1]: https://s3.amazonaws.com/spectacle/downloads/Spectacle+0.8.6.zip
[2]: https://s3.amazonaws.com/spectacle/downloads/Spectacle+0.7.zip
[3]: http://support.apple.com/kb/ht1343
[4]: https://developer.apple.com/library/mac/documentation/Accessibility/Conceptual/AccessibilityMacOSX/OSXAXmodel.html
