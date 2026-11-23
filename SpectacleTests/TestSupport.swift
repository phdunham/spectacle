import AppKit
import Testing

@testable import Spectacle

// Shared test doubles and helpers.
//
// Coordinates: accessibility rects have their origin at the top-left of the primary screen
// (y down); Cocoa rects, like NSScreen.visibleFrame, at the bottom-left (y up).

/// A screen with a fixed frame and visible frame (Cocoa coordinates).
final class FakeScreen: NSScreen {
  let fakeFrame: CGRect
  let fakeVisibleFrame: CGRect
  let name: String

  init(_ name: String, frame: CGRect, visibleFrame: CGRect? = nil) {
    self.name = name
    fakeFrame = frame
    fakeVisibleFrame = visibleFrame ?? frame
    super.init()
  }

  override var frame: NSRect { fakeFrame }
  override var visibleFrame: NSRect { fakeVisibleFrame }
}

/// A window (accessibility coordinates) that can behave like real apps: a minimum size, a size
/// that rounds up to increments (Terminal's character grid), or being a sheet or system dialog.
@MainActor
final class FakeWindow: AccessibilityElement {
  var frame: CGRect
  var minimumSize = CGSize.zero
  var sizeIncrement = CGSize.zero
  var sheet = false
  var systemDialog = false
  private(set) var setCount = 0

  init(_ frame: CGRect) {
    self.frame = frame
    super.init(underlyingElement: nil)
  }

  override func rect() -> CGRect { frame }
  override func isSheet() -> Bool { sheet }
  override func isSystemDialog() -> Bool { systemDialog }

  override func setRect(_ newRect: CGRect) {
    setCount += 1
    func roundUp(_ value: CGFloat, _ step: CGFloat) -> CGFloat { step > 0 ? ceil(value / step) * step : value }
    var r = newRect
    r.size.width = max(roundUp(r.width, sizeIncrement.width), minimumSize.width)
    r.size.height = max(roundUp(r.height, sizeIncrement.height), minimumSize.height)
    frame = r
  }
}

final class FakeRunningApplication: NSRunningApplication, @unchecked Sendable {
  var fakeBundleIdentifier: String?
  override var bundleIdentifier: String? { fakeBundleIdentifier }
}

final class FakeWorkspace: NSWorkspace, @unchecked Sendable {
  let application = FakeRunningApplication()
  override var frontmostApplication: NSRunningApplication? { application }

  convenience init(bundleIdentifier: String?) {
    self.init()
    application.fakeBundleIdentifier = bundleIdentifier
  }
}

/// Runs `body` with the given primary screen frame used for coordinate conversion.
///
/// The override is global, so it is only set for the synchronous duration of `body`; Swift
/// Testing runs tests in parallel, but main-actor code without suspension points can't interleave.
@MainActor
func withPrimaryScreen<T>(_ frame: CGRect, _ body: () throws -> T) rethrows -> T {
  let previous = AccessibilityElement.primaryScreenFrameOverride
  AccessibilityElement.primaryScreenFrameOverride = frame
  defer { AccessibilityElement.primaryScreenFrameOverride = previous }
  return try body()
}

/// Converts a Cocoa rect to accessibility coordinates for a primary screen of the given height.
func accessibilityRect(_ cocoa: CGRect, primaryHeight: CGFloat) -> CGRect {
  CGRect(x: cocoa.minX, y: primaryHeight - cocoa.maxY, width: cocoa.width, height: cocoa.height)
}

// MARK: - Colors and rendering

func relativeLuminance(_ color: NSColor) -> CGFloat {
  guard let rgb = color.usingColorSpace(.sRGB) else {
    return 0
  }
  func channel(_ c: CGFloat) -> CGFloat {
    c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
  }
  return 0.2126 * channel(rgb.redComponent) + 0.7152 * channel(rgb.greenComponent) + 0.0722 * channel(rgb.blueComponent)
}

/// WCAG contrast ratio: 1 (none) to 21 (black on white).
func contrastRatio(_ a: NSColor, _ b: NSColor) -> CGFloat {
  let la = relativeLuminance(a)
  let lb = relativeLuminance(b)
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}

/// Resolves a dynamic color for an appearance.
@MainActor
func resolve(_ color: NSColor, _ appearance: NSAppearance.Name) -> NSColor {
  var resolved = color
  NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
    resolved = color.usingColorSpace(.sRGB) ?? color
  }
  return resolved
}

/// An RGBA bitmap to draw into.
func makeBitmap(width: Int, height: Int) -> NSBitmapImageRep {
  NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
}

/// Draws into `bitmap` with `body`, under the given appearance.
@MainActor
func draw(into bitmap: NSBitmapImageRep, appearance: NSAppearance.Name = .aqua, _ body: () -> Void) {
  NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    body()
    NSGraphicsContext.current?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
  }
}

func color(_ bitmap: NSBitmapImageRep, _ x: Int, _ y: Int) -> NSColor {
  bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) ?? .clear
}
