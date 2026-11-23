import AppKit
import Testing

@testable import Spectacle

// The pieces between a shortcut and a moved window: coordinate conversion, undo history,
// screen detection and the window movers.

// MARK: - Coordinates

@MainActor
@Suite("Coordinate conversion")
struct CoordinateConversionTests {
  @Test("Cocoa to accessibility on the primary screen")
  func primary() {
    withPrimaryScreen(CGRect(x: 0, y: 0, width: 1440, height: 900)) {
      #expect(AccessibilityElement.normalize(CGRect(x: 0, y: 70, width: 720, height: 805)) == CGRect(x: 0, y: 25, width: 720, height: 805))
    }
  }

  @Test("The conversion is its own inverse", arguments: [
    CGRect(x: 0, y: 0, width: 1512, height: 944),
    CGRect(x: -204, y: 982, width: 1920, height: 1043),
    CGRect(x: -1920, y: -500, width: 1920, height: 1055),
    CGRect(x: 10.5, y: 20.25, width: 333.5, height: 444.75),
  ])
  func inverse(rect: CGRect) {
    withPrimaryScreen(CGRect(x: 0, y: 0, width: 1512, height: 982)) {
      #expect(AccessibilityElement.normalize(AccessibilityElement.normalize(rect)) == rect)
    }
  }

  @Test("Displays above the primary display have negative accessibility y")
  func above() {
    withPrimaryScreen(CGRect(x: 0, y: 0, width: 1512, height: 982)) {
      #expect(AccessibilityElement.normalize(CGRect(x: -204, y: 982, width: 1920, height: 1080)) == CGRect(x: -204, y: -1080, width: 1920, height: 1080))
    }
  }

  @Test("Null rects are left alone")
  func null() {
    withPrimaryScreen(CGRect(x: 0, y: 0, width: 1440, height: 900)) {
      #expect(AccessibilityElement.normalize(.null).isNull)
    }
  }

  @Test("Without an override the real primary screen is used")
  func realPrimary() throws {
    let primary = try #require(NSScreen.screens.first, "no screens attached")
    #expect(AccessibilityElement.primaryScreenFrameOverride == nil)
    #expect(AccessibilityElement.frameOfPrimaryScreen() == primary.frame)
  }

  @Test("An element without an accessibility object has no frame and does nothing")
  func detachedElement() {
    let element = AccessibilityElement()
    #expect(element.rect().isNull)
    #expect(!element.isSheet())
    #expect(!element.isSystemDialog())
    #expect(element.string(for: "AXTitle") == nil)
    #expect(element.element(for: "AXFocusedWindow") == nil)
    element.setRect(CGRect(x: 0, y: 0, width: 10, height: 10))
    #expect(element.rect().isNull)
  }
}

// MARK: - History

@MainActor
@Suite("Window history")
struct WindowHistoryTests {
  func item(_ x: CGFloat) -> WindowHistoryItem {
    WindowHistoryItem(window: nil, windowRect: CGRect(x: x, y: 0, width: 100, height: 100))
  }

  @Test("Undo and redo walk the history")
  func walk() {
    let history = WindowHistory()
    #expect(history.isEmpty)
    #expect(history.undo() == nil)
    #expect(history.redo() == nil)
    for x in 1...3 {
      history.add(item(CGFloat(x)))
    }
    #expect(history.undo()?.windowRect.minX == 2)
    #expect(history.undo()?.windowRect.minX == 1)
    #expect(history.undo() == nil)
    #expect(history.redo()?.windowRect.minX == 2)
    #expect(history.redo()?.windowRect.minX == 3)
    #expect(history.redo() == nil)
  }

  @Test("A new move after undo discards the redo branch")
  func branch() {
    let history = WindowHistory()
    for x in 1...3 {
      history.add(item(CGFloat(x)))
    }
    history.undo()
    history.add(item(4))
    #expect(history.redo() == nil)
    #expect(history.undo()?.windowRect.minX == 2)
    #expect(history.undo()?.windowRect.minX == 1)
  }

  @Test("Only the last 50 positions are kept", arguments: [1, 49, 50, 51, 120])
  func capacity(count: Int) {
    let history = WindowHistory()
    for x in 1...count {
      history.add(item(CGFloat(x)))
    }
    var steps = 0
    var oldest: WindowHistoryItem?
    while let item = history.undo() {
      oldest = item
      steps += 1
    }
    #expect(steps == min(count, WindowHistory.capacity) - 1)
    if count > 1 {
      #expect(oldest?.windowRect.minX == CGFloat(max(1, count - WindowHistory.capacity + 1)))
    }
  }

  @Test("Discarded items are released")
  func releasesDiscardedItems() {
    let history = WindowHistory()
    weak var discarded: WindowHistoryItem?
    do {
      let second = item(2)
      discarded = second
      history.add(item(1))
      history.add(second)
      history.undo()
      history.add(item(3))
    }
    #expect(discarded == nil)
  }
}

// MARK: - Screen detection

@MainActor
@Suite("Screen detection")
struct ScreenDetectorTests {
  let primary = FakeScreen("primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900))
  let right = FakeScreen("right", frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080))
  let left = FakeScreen("left", frame: CGRect(x: -1280, y: 100, width: 1280, height: 800))
  let above = FakeScreen("above", frame: CGRect(x: 0, y: 900, width: 1440, height: 900))

  /// Detects for a window at a Cocoa rect.
  func detect(_ action: WindowAction, _ cocoa: CGRect, _ screens: [NSScreen]) -> ScreenDetectionResult {
    withPrimaryScreen(primary.frame) {
      let window = FakeWindow(accessibilityRect(cocoa, primaryHeight: 900))
      return ScreenDetector().detect(action: action, window: window, screens: screens, mainScreen: primary)
    }
  }

  @Test("Finds the screen containing the window")
  func containing() {
    let screens = [primary, right, left, above]
    #expect(detect(.center, CGRect(x: 100, y: 100, width: 300, height: 300), screens).sourceScreen === primary)
    #expect(detect(.center, CGRect(x: 1600, y: 100, width: 300, height: 300), screens).sourceScreen === right)
    #expect(detect(.center, CGRect(x: -1000, y: 200, width: 300, height: 300), screens).sourceScreen === left)
    #expect(detect(.center, CGRect(x: 100, y: 1000, width: 300, height: 300), screens).sourceScreen === above)
  }

  @Test("Placement actions stay on the window's screen")
  func sameScreen() {
    let result = detect(.leftHalf, CGRect(x: 1600, y: 100, width: 300, height: 300), [primary, right])
    #expect(result.sourceScreen === right)
    #expect(result.destinationScreen === right)
  }

  @Test("A window across two screens belongs to the one with more of it")
  func straddling() {
    #expect(detect(.center, CGRect(x: 1340, y: 100, width: 400, height: 300), [primary, right]).sourceScreen === right)
    #expect(detect(.center, CGRect(x: 1140, y: 100, width: 400, height: 300), [primary, right]).sourceScreen === primary)
  }

  @Test("Off-screen, zero-sized and frameless windows fall back to the main screen")
  func fallback() {
    #expect(detect(.center, CGRect(x: 9000, y: 9000, width: 300, height: 300), [right, primary]).sourceScreen === primary)
    #expect(detect(.center, CGRect(x: 5000, y: 5000, width: 0, height: 0), [primary, right]).sourceScreen === primary)
    let result = withPrimaryScreen(primary.frame) {
      ScreenDetector().detect(action: .center, window: FakeWindow(.null), screens: [right, primary], mainScreen: primary)
    }
    #expect(result.sourceScreen === primary)
  }

  @Test("Next display visits every screen and wraps; previous goes back")
  func nextAndPrevious() {
    let screens: [NSScreen] = [primary, right, left]
    var rect = CGRect(x: 100, y: 100, width: 300, height: 300)
    var visited: [String] = []
    for _ in screens {
      let next = detect(.nextDisplay, rect, screens).destinationScreen as? FakeScreen
      #expect(next != nil)
      visited.append(next?.name ?? "-")
      rect = CGRect(x: (next?.frame.minX ?? 0) + 10, y: (next?.frame.minY ?? 0) + 10, width: 300, height: 300)
    }
    #expect(Set(visited).count == 3)
    #expect(visited.last == "primary")
    let next = detect(.nextDisplay, CGRect(x: 100, y: 100, width: 300, height: 300), screens).destinationScreen!
    let back = detect(.previousDisplay, CGRect(x: next.frame.minX + 10, y: next.frame.minY + 10, width: 300, height: 300), screens).destinationScreen
    #expect(back === primary)
  }

  @Test("No next or previous display with a single screen")
  func singleScreen() {
    #expect(detect(.nextDisplay, CGRect(x: 100, y: 100, width: 300, height: 300), [primary]).destinationScreen == nil)
    #expect(detect(.previousDisplay, CGRect(x: 100, y: 100, width: 300, height: 300), [primary]).destinationScreen == nil)
  }

  @Test("Display order does not depend on the order screens are reported in")
  func consistentOrder() {
    func names(_ screens: [NSScreen]) -> [String] {
      ScreenDetector.inConsistentOrder(screens).map { ($0 as! FakeScreen).name }
    }
    let a = names([primary, right, left, above])
    #expect(a == names([above, left, right, primary]))
    #expect(a == names([left, primary, above, right]))
    #expect(a.first == "primary")
  }

  @Test("Fraction of a rect within a frame")
  func fraction() {
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    #expect(ScreenDetector.fractionOf(CGRect(x: 50, y: 0, width: 100, height: 100), within: frame) == 0.5)
    #expect(ScreenDetector.fractionOf(CGRect(x: 500, y: 0, width: 10, height: 10), within: frame) == 0)
    #expect(ScreenDetector.fractionOf(CGRect(x: 10, y: 10, width: 0, height: 0), within: frame) == 0)
  }
}

// MARK: - Window movers

/// Records each request and passes it on.
@MainActor
final class RecordingMover: WindowMover {
  var requests: [(rect: CGRect, action: WindowAction)] = []
  let next: WindowMover?

  init(next: WindowMover? = nil) {
    self.next = next
  }

  func move(_ windowRect: CGRect, frameOfScreen: CGRect, visibleFrameOfScreen: CGRect, window: AccessibilityElement, action: WindowAction) {
    requests.append((windowRect, action))
    next?.move(windowRect, frameOfScreen: frameOfScreen, visibleFrameOfScreen: visibleFrameOfScreen, window: window, action: action)
  }
}

@MainActor
@Suite("Window movers")
struct WindowMoverTests {
  let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
  let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)

  func move(_ mover: WindowMover, _ target: CGRect, _ window: FakeWindow, frame: CGRect? = nil, visible: CGRect? = nil) {
    withPrimaryScreen(self.frame) {
      mover.move(target, frameOfScreen: frame ?? self.frame, visibleFrameOfScreen: visible ?? self.visible, window: window, action: .leftHalf)
    }
  }

  @Test("The standard mover sets the frame and passes the request on")
  func standard() {
    let recorder = RecordingMover()
    let window = FakeWindow(CGRect(x: 10, y: 10, width: 100, height: 100))
    move(StandardWindowMover(next: recorder), CGRect(x: 0, y: 25, width: 720, height: 875), window)
    #expect(window.frame == CGRect(x: 0, y: 25, width: 720, height: 875))
    #expect(recorder.requests.count == 1)
    #expect(recorder.requests.first?.action == .leftHalf)
  }

  @Test("The standard mover leaves windows without a frame alone")
  func standardNoFrame() {
    let recorder = RecordingMover()
    let window = FakeWindow(.null)
    move(StandardWindowMover(next: recorder), CGRect(x: 0, y: 25, width: 720, height: 875), window)
    #expect(window.setCount == 0)
    #expect(recorder.requests.isEmpty)
  }

  @Test("The quantized mover leaves exact fits alone")
  func quantizedExact() {
    let window = FakeWindow(CGRect(x: 0, y: 25, width: 720, height: 875))
    move(QuantizedWindowMover(), CGRect(x: 0, y: 25, width: 720, height: 875), window)
    #expect(window.setCount == 0)
  }

  @Test("Windows with size steps are shrunk to fit and centered",
        arguments: [CGSize(width: 7, height: 17), CGSize(width: 9, height: 19), CGSize(width: 13, height: 1)])
  func quantized(increment: CGSize) {
    let window = FakeWindow(CGRect(x: 0, y: 0, width: 10, height: 10))
    window.sizeIncrement = increment
    let target = CGRect(x: 720, y: 25, width: 720, height: 875)
    window.setRect(target)
    move(QuantizedWindowMover(), target, window)
    #expect(target.contains(window.frame))
    #expect(abs(window.frame.midX - target.midX) <= 1)
    #expect(abs(window.frame.midY - target.midY) <= 1)
    #expect(window.frame.width > target.width - increment.width)
  }

  @Test("The quantized mover gives up quickly on windows that can't shrink")
  func quantizedGivesUp() {
    let window = FakeWindow(CGRect(x: 0, y: 0, width: 10, height: 10))
    window.minimumSize = CGSize(width: 1000, height: 100)
    let target = CGRect(x: 720, y: 25, width: 720, height: 875)
    window.setRect(target)
    move(QuantizedWindowMover(), target, window)
    #expect(window.setCount < 100)
    #expect(window.frame.width == 1000)
  }

  @Test("The best-effort mover pulls windows back from either edge")
  func bestEffortHorizontal() {
    let tooFarRight = FakeWindow(CGRect(x: 720, y: 25, width: 1000, height: 875))
    move(BestEffortWindowMover(), CGRect(x: 720, y: 25, width: 720, height: 875), tooFarRight)
    #expect(tooFarRight.frame == CGRect(x: 440, y: 25, width: 1000, height: 875))
    let tooFarLeft = FakeWindow(CGRect(x: -50, y: 25, width: 600, height: 400))
    move(BestEffortWindowMover(), CGRect(x: 0, y: 25, width: 600, height: 400), tooFarLeft)
    #expect(tooFarLeft.frame == CGRect(x: 0, y: 25, width: 600, height: 400))
  }

  @Test("The best-effort mover keeps windows above the Dock and below the menu bar")
  func bestEffortVertical() {
    let withDock = CGRect(x: 0, y: 70, width: 1440, height: 805) // AX y range 25...830
    let tooLow = FakeWindow(CGRect(x: 0, y: 600, width: 720, height: 500))
    move(BestEffortWindowMover(), tooLow.frame, tooLow, visible: withDock)
    #expect(tooLow.frame == CGRect(x: 0, y: 330, width: 720, height: 500))
    let tooHigh = FakeWindow(CGRect(x: 0, y: 0, width: 720, height: 500))
    move(BestEffortWindowMover(), tooHigh.frame, tooHigh, visible: withDock)
    #expect(tooHigh.frame == CGRect(x: 0, y: 25, width: 720, height: 500))
  }

  @Test("The best-effort mover works on a display above the primary one")
  func bestEffortAbove() {
    // Cocoa (0, 900, 1440, 875) is AX (0, -875, 1440, 875).
    let window = FakeWindow(CGRect(x: 0, y: -400, width: 720, height: 600))
    move(BestEffortWindowMover(), window.frame, window,
         frame: CGRect(x: 0, y: 900, width: 1440, height: 900), visible: CGRect(x: 0, y: 900, width: 1440, height: 875))
    #expect(window.frame == CGRect(x: 0, y: -600, width: 720, height: 600))
  }

  @Test("The best-effort mover does nothing for windows on screen or without a frame")
  func bestEffortNoChange() {
    let onScreen = FakeWindow(CGRect(x: 0, y: 25, width: 720, height: 875))
    move(BestEffortWindowMover(), onScreen.frame, onScreen)
    #expect(onScreen.setCount == 0)
    let noFrame = FakeWindow(.null)
    move(BestEffortWindowMover(), CGRect(x: 0, y: 25, width: 720, height: 875), noFrame)
    #expect(noFrame.setCount == 0)
  }

  @Test("The default chain places windows exactly")
  func defaultChain() {
    let window = FakeWindow(CGRect(x: 300, y: 300, width: 400, height: 300))
    move(WindowPositionManager.defaultWindowMover(), CGRect(x: 0, y: 25, width: 1440, height: 875), window)
    #expect(window.frame == CGRect(x: 0, y: 25, width: 1440, height: 875))
  }
}
