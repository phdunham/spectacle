import CoreGraphics
import Foundation

/// The window layout math: where a window goes for each Spectacle action.
///
/// All rects are in Cocoa coordinates (origin at the bottom-left of the primary screen, y up),
/// the coordinate space of `NSScreen.visibleFrame`. This is a direct port of the JavaScript files
/// that earlier releases evaluated with JavaScriptCore, and produces identical results, including
/// their rounding (`floor` for sizes, JavaScript's round-half-up for centering).
enum WindowLayout {
  /// The actions this file knows how to lay out. The raw values match `kSpectacleWindowAction…`.
  enum Action: String, CaseIterable, Sendable {
    case center = "SpectacleWindowActionCenter"
    case fullscreen = "SpectacleWindowActionFullscreen"
    case leftHalf = "SpectacleWindowActionLeftHalf"
    case rightHalf = "SpectacleWindowActionRightHalf"
    case topHalf = "SpectacleWindowActionTopHalf"
    case bottomHalf = "SpectacleWindowActionBottomHalf"
    case upperLeft = "SpectacleWindowActionUpperLeft"
    case upperRight = "SpectacleWindowActionUpperRight"
    case lowerLeft = "SpectacleWindowActionLowerLeft"
    case lowerRight = "SpectacleWindowActionLowerRight"
    case nextThird = "SpectacleWindowActionNextThird"
    case previousThird = "SpectacleWindowActionPreviousThird"
    case larger = "SpectacleWindowActionLarger"
    case smaller = "SpectacleWindowActionSmaller"
    case nextDisplay = "SpectacleWindowActionNextDisplay"
    case previousDisplay = "SpectacleWindowActionPreviousDisplay"
  }

  /// How much Larger and Smaller change the width and height, in points.
  static let resizeStep: CGFloat = 30

  /// The new window rect for `action`.
  ///
  /// - Parameters:
  ///   - window: The window's current rect.
  ///   - source: The visible frame of the screen the window is on.
  ///   - destination: The visible frame of the screen it should end up on (the same screen
  ///     except for the next/previous display actions).
  static func rect(for action: Action, window: CGRect, source: CGRect, destination: CGRect) -> CGRect {
    switch action {
    case .center:
      return centered(window, in: destination)
    case .fullscreen:
      return destination
    case .leftHalf:
      return side(window, in: destination, edge: .left)
    case .rightHalf:
      return side(window, in: destination, edge: .right)
    case .topHalf:
      return side(window, in: destination, edge: .top)
    case .bottomHalf:
      return side(window, in: destination, edge: .bottom)
    case .upperLeft:
      return corner(window, in: destination, top: true, right: false)
    case .upperRight:
      return corner(window, in: destination, top: true, right: true)
    case .lowerLeft:
      return corner(window, in: destination, top: false, right: false)
    case .lowerRight:
      return corner(window, in: destination, top: false, right: true)
    case .nextThird:
      return third(after: window, in: destination, step: 1)
    case .previousThird:
      return third(after: window, in: destination, step: -1)
    case .larger:
      return resized(window, in: destination, by: resizeStep)
    case .smaller:
      return resized(window, in: destination, by: -resizeStep)
    case .nextDisplay, .previousDisplay:
      return movedToDisplay(window, destination: destination)
    }
  }

  // MARK: - Center and displays

  static func centered(_ window: CGRect, in screen: CGRect) -> CGRect {
    var result = window
    result.origin.x = jsRound((screen.width - window.width) / 2) + screen.minX
    result.origin.y = jsRound((screen.height - window.height) / 2) + screen.minY
    return result
  }

  static func movedToDisplay(_ window: CGRect, destination: CGRect) -> CGRect {
    fits(window, in: destination) ? centered(window, in: destination) : destination
  }

  // MARK: - Halves (cycling 1/2 → 2/3 → 1/3)

  private enum Edge {
    case left, right, top, bottom
  }

  /// A half of the screen against `edge`. Pressing the same shortcut again cycles the window
  /// through 2/3 and 1/3 of the screen, staying against that edge.
  private static func side(_ window: CGRect, in screen: CGRect, edge: Edge) -> CGRect {
    let horizontal = (edge == .left || edge == .right)
    let length = horizontal ? screen.width : screen.height
    let half = strip(edge: edge, length: floor(length / 2), in: screen, isHalf: true)
    // Only cycle while the window is still lined up with this half along the other axis.
    let linedUp = horizontal
      ? abs(window.midY - half.midY) <= 1
      : abs(window.midX - half.midX) <= 1
    guard linedUp else {
      return half
    }
    let twoThirds = strip(edge: edge, length: floor(length * 2 / 3), in: screen, isHalf: false)
    if isCentered(window, within: half) {
      return twoThirds
    }
    if isCentered(window, within: twoThirds) {
      return strip(edge: edge, length: floor(length / 3), in: screen, isHalf: false)
    }
    return half
  }

  /// A full-height (or full-width) strip of `length` against `edge`.
  ///
  /// On screens with an odd width (or height) the right (or top) half starts right after the
  /// left (or bottom) half, at `floor(width / 2)`, so the halves tile with the leftover point at
  /// the far edge; the 2/3 and 1/3 strips are flush with the far edge instead. This matches the
  /// original JavaScript exactly.
  private static func strip(edge: Edge, length: CGFloat, in screen: CGRect, isHalf: Bool) -> CGRect {
    var rect = screen
    switch edge {
    case .left:
      rect.size.width = length
    case .bottom:
      rect.size.height = length
    case .right:
      rect.size.width = length
      rect.origin.x = isHalf ? screen.minX + length : screen.minX + screen.width - length
    case .top:
      rect.size.height = length
      rect.origin.y = isHalf
        ? screen.minY + length + screen.height.truncatingRemainder(dividingBy: 2)
        : screen.minY + screen.height - length
    }
    return rect
  }

  // MARK: - Quarters (cycling width 1/2 → 2/3 → 1/3)

  private static func corner(_ window: CGRect, in screen: CGRect, top: Bool, right: Bool) -> CGRect {
    var quarter = screen
    quarter.size.width = floor(screen.width / 2)
    quarter.size.height = floor(screen.height / 2)
    if right {
      quarter.origin.x += quarter.width
    }
    if top {
      quarter.origin.y = screen.minY + floor(screen.height / 2) + screen.height.truncatingRemainder(dividingBy: 2)
    }
    guard abs(window.midY - quarter.midY) <= 1 else {
      return quarter
    }
    func withWidth(_ width: CGFloat) -> CGRect {
      var rect = quarter
      rect.size.width = width
      if right {
        rect.origin.x = screen.minX + screen.width - width
      }
      return rect
    }
    let twoThirds = withWidth(floor(screen.width * 2 / 3))
    if isCentered(window, within: quarter) {
      return twoThirds
    }
    if isCentered(window, within: twoThirds) {
      return withWidth(floor(screen.width / 3))
    }
    return quarter
  }

  // MARK: - Thirds

  /// The three vertical thirds left to right, then the three horizontal thirds top to bottom.
  static func thirds(of screen: CGRect) -> [CGRect] {
    let width = floor(screen.width / 3)
    let height = floor(screen.height / 3)
    let columns = (0..<3).map { i in
      CGRect(x: screen.minX + width * CGFloat(i), y: screen.minY, width: width, height: screen.height)
    }
    let rows = (0..<3).map { i in
      CGRect(x: screen.minX, y: screen.minY + screen.height - height * CGFloat(i + 1), width: screen.width, height: height)
    }
    return columns + rows
  }

  private static func third(after window: CGRect, in screen: CGRect, step: Int) -> CGRect {
    let all = thirds(of: screen)
    guard let index = all.firstIndex(where: { isCentered(window, within: $0) }) else {
      return all[0]
    }
    let count = all.count
    return all[((index + step) % count + count) % count]
  }

  // MARK: - Larger and smaller

  /// Grows or shrinks the window by `offset` points in each dimension, keeping it centered on
  /// its current position, keeping edges that touch the screen edge against that edge, never
  /// larger than the screen and never smaller than a quarter of it.
  static func resized(_ window: CGRect, in screen: CGRect, by offset: CGFloat) -> CGRect {
    var resized = window
    resized.size.width += offset
    resized.origin.x -= floor(offset / 2)
    resized = adjustedHorizontally(original: window, resized: resized, screen: screen)
    if resized.width >= screen.width {
      resized.size.width = screen.width
    }
    resized.size.height += offset
    resized.origin.y -= floor(offset / 2)
    resized = adjustedVertically(original: window, resized: resized, screen: screen)
    if resized.height >= screen.height {
      resized.size.height = screen.height
      resized.origin.y = window.minY
    }
    if againstAllEdges(window, screen) && offset < 0 {
      resized.size.width = window.width + offset
      resized.origin.x = window.minX - floor(offset / 2)
      resized.size.height = window.height + offset
      resized.origin.y = window.minY - floor(offset / 2)
    }
    if isTooSmall(resized, screen) {
      return window
    }
    return resized
  }

  private static func isAgainstEdge(_ gap: CGFloat) -> Bool {
    abs(gap) <= 5
  }

  private static func againstLeft(_ window: CGRect, _ screen: CGRect) -> Bool {
    isAgainstEdge(window.minX - screen.minX)
  }

  private static func againstRight(_ window: CGRect, _ screen: CGRect) -> Bool {
    isAgainstEdge(window.minX + window.width - (screen.minX + screen.width))
  }

  private static func againstTop(_ window: CGRect, _ screen: CGRect) -> Bool {
    isAgainstEdge(window.minY + window.height - (screen.minY + screen.height))
  }

  private static func againstBottom(_ window: CGRect, _ screen: CGRect) -> Bool {
    isAgainstEdge(window.minY - screen.minY)
  }

  private static func againstAllEdges(_ window: CGRect, _ screen: CGRect) -> Bool {
    againstLeft(window, screen) && againstRight(window, screen) && againstTop(window, screen) && againstBottom(window, screen)
  }

  private static func adjustedHorizontally(original: CGRect, resized: CGRect, screen: CGRect) -> CGRect {
    var adjusted = resized
    if againstRight(original, screen) {
      adjusted.origin.x = screen.minX + screen.width - adjusted.width
      if againstLeft(original, screen) {
        adjusted.size.width = screen.width
      }
    }
    if againstLeft(original, screen) {
      adjusted.origin.x = screen.minX
    }
    return adjusted
  }

  private static func adjustedVertically(original: CGRect, resized: CGRect, screen: CGRect) -> CGRect {
    var adjusted = resized
    if againstTop(original, screen) {
      adjusted.origin.y = screen.minY + screen.height - adjusted.height
      if againstBottom(original, screen) {
        adjusted.size.height = screen.height
      }
    }
    if againstBottom(original, screen) {
      adjusted.origin.y = screen.minY
    }
    return adjusted
  }

  private static func isTooSmall(_ window: CGRect, _ screen: CGRect) -> Bool {
    window.width <= floor(screen.width / 4) || window.height <= floor(screen.height / 4)
  }

  // MARK: - Helpers

  /// Whether `window` lies inside `area` and is centered in it (within a point).
  static func isCentered(_ window: CGRect, within area: CGRect) -> Bool {
    area.contains(window)
      && abs(window.midX - area.midX) <= 1
      && abs(window.midY - area.midY) <= 1
  }

  static func fits(_ window: CGRect, in screen: CGRect) -> Bool {
    window.width <= screen.width && window.height <= screen.height
  }

  /// JavaScript's `Math.round`: halves round up (towards +∞), unlike Swift's `rounded()`.
  static func jsRound(_ value: CGFloat) -> CGFloat {
    floor(value + 0.5)
  }
}
