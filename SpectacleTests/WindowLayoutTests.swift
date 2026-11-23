import CoreGraphics
import Testing

@testable import Spectacle

/// Properties of `WindowLayout` on many screen geometries. The exact results of the original
/// specs are checked in OriginalLayoutExpectationTests.
@Suite("Window layout")
struct WindowLayoutTests {
  /// Visible frames of real setups: notch MacBook, Dock at the bottom, Dock on the left (odd
  /// height), an external display to the right, a display above, one left and lower, portrait.
  static let screens: [CGRect] = [
    CGRect(x: 0, y: 0, width: 1512, height: 944),
    CGRect(x: 0, y: 70, width: 1440, height: 805),
    CGRect(x: 64, y: 0, width: 1856, height: 1055),
    CGRect(x: 2560, y: 180, width: 1920, height: 1055),
    CGRect(x: -204, y: 982, width: 1920, height: 1043),
    CGRect(x: -1920, y: -500, width: 1920, height: 1055),
    CGRect(x: 2560, y: -400, width: 1080, height: 1895),
  ]

  static func window(in screen: CGRect) -> CGRect {
    CGRect(x: screen.minX + 101, y: screen.minY + 87, width: floor(screen.width * 0.4), height: floor(screen.height * 0.45))
  }

  func layout(_ action: WindowLayout.Action, _ window: CGRect, _ screen: CGRect) -> CGRect {
    WindowLayout.rect(for: action, window: window, source: screen, destination: screen)
  }

  // MARK: - Every action

  @Test("Every action lands inside the screen on whole points", arguments: WindowLayout.Action.allCases, screens)
  func insideTheScreen(action: WindowLayout.Action, screen: CGRect) {
    let result = layout(action, Self.window(in: screen), screen)
    #expect(!result.isEmpty)
    #expect(screen.contains(result))
    #expect(result == result.integral)
  }

  @Test("Fullscreen is the visible frame", arguments: screens)
  func fullscreen(screen: CGRect) {
    #expect(layout(.fullscreen, Self.window(in: screen), screen) == screen)
  }

  @Test("Only placement actions have a layout")
  func layoutActions() {
    #expect(WindowLayout.Action(rawValue: WindowAction.undo.rawValue) == nil)
    #expect(WindowLayout.Action(rawValue: WindowAction.redo.rawValue) == nil)
    #expect(WindowLayout.Action(rawValue: WindowAction.none.rawValue) == nil)
    #expect(WindowLayout.Action(rawValue: "SpectacleWindowActionDoesNotExist") == nil)
    #expect(WindowLayout.Action.allCases.count == 16)
    for action in WindowLayout.Action.allCases {
      // Every layout belongs to a shortcut.
      #expect(Shortcut.windowActions.values.contains(WindowAction(rawValue: action.rawValue)), "\(action)")
    }
  }

  @Test("Quarters sit in the corners", arguments: screens)
  func quarters(screen: CGRect) {
    let window = Self.window(in: screen)
    let upperLeft = layout(.upperLeft, window, screen)
    let upperRight = layout(.upperRight, window, screen)
    let lowerLeft = layout(.lowerLeft, window, screen)
    let lowerRight = layout(.lowerRight, window, screen)
    #expect(upperLeft.minX == screen.minX && upperLeft.maxY == screen.maxY)
    #expect(upperRight.maxY == screen.maxY && upperRight.minX == upperLeft.maxX)
    #expect(lowerLeft.minX == screen.minX && lowerLeft.minY == screen.minY)
    #expect(lowerRight.minY == screen.minY && lowerRight.minX == lowerLeft.maxX)
  }

  // MARK: - Halves and quarters

  @Test("Halves on a classic 1440×873 screen")
  func halves() {
    let screen = CGRect(x: 0, y: 4, width: 1440, height: 873)
    let window = CGRect(x: 165, y: 245, width: 564, height: 384)
    #expect(layout(.leftHalf, window, screen) == CGRect(x: 0, y: 4, width: 720, height: 873))
    #expect(layout(.rightHalf, window, screen) == CGRect(x: 720, y: 4, width: 720, height: 873))
    // Odd height: the leftover point goes to the top half's origin, as it always has.
    #expect(layout(.topHalf, window, screen) == CGRect(x: 0, y: 441, width: 1440, height: 436))
    #expect(layout(.bottomHalf, window, screen) == CGRect(x: 0, y: 4, width: 1440, height: 436))
  }

  @Test("Halves tile the screen", arguments: screens)
  func halvesTile(screen: CGRect) {
    let window = Self.window(in: screen)
    let left = layout(.leftHalf, window, screen)
    let right = layout(.rightHalf, window, screen)
    let top = layout(.topHalf, window, screen)
    let bottom = layout(.bottomHalf, window, screen)
    #expect(left.maxX == right.minX)
    #expect(left.minX == screen.minX)
    #expect(top.maxY == screen.maxY)
    #expect(bottom.minY == screen.minY)
    #expect(bottom.maxY <= top.minY)
  }

  @Test(
    "Repeating a side or corner cycles 1/2 → 2/3 → 1/3 → 1/2",
    arguments: [WindowLayout.Action.leftHalf, .rightHalf, .topHalf, .bottomHalf, .upperLeft, .upperRight, .lowerLeft, .lowerRight],
    screens)
  func cycling(action: WindowLayout.Action, screen: CGRect) {
    let half = layout(action, Self.window(in: screen), screen)
    let twoThirds = layout(action, half, screen)
    let oneThird = layout(action, twoThirds, screen)
    #expect(twoThirds != half)
    #expect(oneThird != twoThirds)
    #expect(layout(action, oneThird, screen) == half)
  }

  @Test("Right-side strips stay against the right edge", arguments: screens)
  func rightEdge(screen: CGRect) {
    let half = layout(.rightHalf, Self.window(in: screen), screen)
    let twoThirds = layout(.rightHalf, half, screen)
    let oneThird = layout(.rightHalf, twoThirds, screen)
    #expect(twoThirds.maxX == screen.maxX)
    #expect(oneThird.maxX == screen.maxX)
    #expect(twoThirds.width == floor(screen.width * 2 / 3))
    #expect(oneThird.width == floor(screen.width / 3))
  }

  // MARK: - Thirds

  @Test("Next third visits all six thirds and wraps", arguments: screens)
  func nextThird(screen: CGRect) {
    let thirds = WindowLayout.thirds(of: screen)
    var window = Self.window(in: screen)
    for expected in thirds + [thirds[0]] {
      window = layout(.nextThird, window, screen)
      #expect(window == expected)
    }
  }

  @Test("Previous third undoes next third", arguments: screens)
  func previousThird(screen: CGRect) {
    var third = layout(.nextThird, Self.window(in: screen), screen)
    for _ in 0..<6 {
      let next = layout(.nextThird, third, screen)
      #expect(layout(.previousThird, next, screen) == third)
      third = next
    }
  }

  // MARK: - Center, displays, resizing

  @Test("Center keeps the size and centers, rounding halves up")
  func center() {
    let screen = CGRect(x: 1440, y: -100, width: 1920, height: 1055)
    let result = layout(.center, CGRect(x: 0, y: 0, width: 800, height: 600), screen)
    // (1055 - 600) / 2 = 227.5 rounds up to 228, like JavaScript's Math.round.
    #expect(result == CGRect(x: 2000, y: 128, width: 800, height: 600))
    #expect(WindowLayout.jsRound(-2.5) == -2)
    #expect(WindowLayout.jsRound(2.5) == 3)
  }

  @Test("Moving to a display centers a window that fits and fills the display otherwise")
  func display() {
    let source = CGRect(x: 0, y: 0, width: 2560, height: 1415)
    let destination = CGRect(x: 2560, y: 180, width: 1920, height: 1055)
    let small = WindowLayout.rect(for: .nextDisplay, window: CGRect(x: 10, y: 10, width: 800, height: 600), source: source, destination: destination)
    #expect(small.size == CGSize(width: 800, height: 600))
    #expect(destination.contains(small))
    let big = WindowLayout.rect(for: .previousDisplay, window: source, source: source, destination: destination)
    #expect(big == destination)
  }

  @Test("Larger then smaller restores the window", arguments: screens)
  func largerSmaller(screen: CGRect) {
    let start = Self.window(in: screen)
    let larger = layout(.larger, start, screen)
    #expect(larger.size == CGSize(width: start.width + 30, height: start.height + 30))
    #expect(layout(.smaller, larger, screen) == start)
  }

  @Test("Smaller stops above a quarter of the screen")
  func smallerLimit() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)
    var window = CGRect(x: 500, y: 300, width: 380, height: 240)
    for _ in 0..<20 {
      window = layout(.smaller, window, screen)
    }
    #expect(window.width > floor(screen.width / 4))
    #expect(window.height > floor(screen.height / 4))
  }

  @Test("Larger never exceeds the screen and keeps edges that touch the screen edge")
  func largerAtEdges() {
    let screen = CGRect(x: 0, y: 4, width: 1440, height: 873)
    var window = CGRect(x: 0, y: 4, width: 720, height: 873) // left half
    for _ in 0..<40 {
      window = layout(.larger, window, screen)
      #expect(window.minX == screen.minX)
      #expect(screen.contains(window))
    }
    #expect(window == screen)
  }
}
