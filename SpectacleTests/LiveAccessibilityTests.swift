import AppKit
import ApplicationServices
import Testing

@testable import Spectacle

/// Moves a real TextEdit window through the Accessibility API, exactly like the shortcuts do.
///
/// Opt-in: give the test host (build/DerivedData/Build/Products/Debug/Spectacle.app) Accessibility
/// access, then run with TEST_RUNNER_SPECTACLE_LIVE_TESTS=1. It opens a new, empty TextEdit
/// document and closes it again without saving.
@MainActor
@Suite("Live accessibility", .enabled(if: ProcessInfo.processInfo.environment["SPECTACLE_LIVE_TESTS"] == "1"))
struct LiveAccessibilityTests {
  @Test("Fullscreen, left, right and top half on a real window")
  func realWindow() async throws {
    try #require(AXIsProcessTrusted(), "the test host needs Accessibility access")
    let url = try #require(NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit"))
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    let app = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    NSAppleScript(source: "tell application \"TextEdit\" to make new document")?.executeAndReturnError(nil)
    defer { NSAppleScript(source: "tell application \"TextEdit\" to close front document saving no")?.executeAndReturnError(nil) }

    var window: AccessibilityElement?
    for _ in 0..<50 where window == nil {
      window = AccessibilityElement(underlyingElement: AXUIElementCreateApplication(app.processIdentifier))
        .element(for: kAXFocusedWindowAttribute as String)
      if window == nil {
        try await Task.sleep(for: .milliseconds(100))
      }
    }
    let element = try #require(window, "could not get TextEdit's window")
    element.setRect(CGRect(x: 200, y: 200, width: 500, height: 400))

    var failures = 0
    let manager = WindowPositionManager(failureFeedback: { failures += 1 })
    let cocoa = AccessibilityElement.normalize(element.rect())
    let screen = NSScreen.screens.first { $0.frame.contains(CGPoint(x: cocoa.midX, y: cocoa.midY)) } ?? NSScreen.screens[0]
    let v = screen.visibleFrame
    let half = floor(v.width / 2)
    let halfHeight = floor(v.height / 2)
    let expectations: [(WindowAction, CGRect)] = [
      (.fullscreen, v),
      (.leftHalf, CGRect(x: v.minX, y: v.minY, width: half, height: v.height)),
      (.rightHalf, CGRect(x: v.minX + half, y: v.minY, width: half, height: v.height)),
      (.topHalf, CGRect(x: v.minX, y: v.minY + halfHeight + v.height.truncatingRemainder(dividingBy: 2), width: v.width, height: halfHeight)),
    ]
    for (action, expected) in expectations {
      manager.move(element, action: action, screens: NSScreen.screens, mainScreen: screen)
      let actual = element.rect()
      let target = AccessibilityElement.normalize(expected)
      // TextEdit has no size steps, so the window must land within a point of the target.
      #expect(abs(actual.minX - target.minX) <= 1 && abs(actual.minY - target.minY) <= 1, "\(action): \(actual) vs \(target)")
      #expect(abs(actual.width - target.width) <= 1 && abs(actual.height - target.height) <= 1, "\(action): \(actual) vs \(target)")
    }
    #expect(failures == 0)
  }
}
