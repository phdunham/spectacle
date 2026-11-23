import AppKit

/// The screen a window is on, and the screen it should be moved to.
struct ScreenDetectionResult {
  let sourceScreen: NSScreen?
  let destinationScreen: NSScreen?
}

/// Works out which screen the frontmost window is on and, for the next/previous display
/// actions, which screen it should move to.
@MainActor
final class ScreenDetector {
  func detect(action: WindowAction, window: AccessibilityElement?, screens: [NSScreen], mainScreen: NSScreen?) -> ScreenDetectionResult {
    let ordered = Self.inConsistentOrder(screens)
    let windowRect = window?.rect() ?? .null
    let source = Self.screen(containing: windowRect, screens: ordered, mainScreen: mainScreen)
    var destination = source
    if action.isMovingToDisplay {
      destination = source.flatMap { Self.screen(nextTo: $0.frame, action: action, screens: ordered) }
    }
    return ScreenDetectionResult(sourceScreen: source, destinationScreen: destination)
  }

  /// The screen that contains the window (accessibility coordinates), or failing that the one
  /// containing the largest part of it, or failing that `mainScreen`.
  static func screen(containing windowRect: CGRect, screens: [NSScreen], mainScreen: NSScreen?) -> NSScreen? {
    var result = mainScreen
    var largestFraction: CGFloat = 0
    let cocoaRect = AccessibilityElement.normalize(windowRect)
    for screen in screens {
      let frame = screen.frame
      if frame.contains(cocoaRect) {
        return screen
      }
      let fraction = fractionOf(cocoaRect, within: frame)
      if fraction > largestFraction {
        largestFraction = fraction
        result = screen
      }
    }
    return result
  }

  /// The part of `rect` (0...1) that lies within `frame`.
  static func fractionOf(_ rect: CGRect, within frame: CGRect) -> CGFloat {
    let intersection = rect.intersection(frame)
    let area = rect.width * rect.height
    guard !intersection.isNull, area > 0 else {
      return 0
    }
    return intersection.width * intersection.height / area
  }

  /// The screen after (next display) or before (previous display) the one with `frame`,
  /// wrapping around. Nil with fewer than two screens.
  static func screen(nextTo frame: CGRect, action: WindowAction, screens: [NSScreen]) -> NSScreen? {
    guard screens.count > 1, let index = screens.firstIndex(where: { $0.frame == frame }) else {
      return nil
    }
    var other = index
    if action.isNextDisplay {
      other += 1
    } else if action.isPreviousDisplay {
      other -= 1
    }
    if other < 0 {
      other = screens.count - 1
    } else if other >= screens.count {
      other = 0
    }
    return screens[other]
  }

  /// Screens in the order next/previous display walks through them, independent of the order
  /// NSScreen reports them in: the screen at the origin (the primary one) first, then by
  /// x descending (and by y descending among screens with the same x).
  static func inConsistentOrder(_ screens: [NSScreen]) -> [NSScreen] {
    func atOrigin(_ screen: NSScreen) -> Bool {
      screen.frame.origin == .zero
    }
    // Two stable sorts, as in the original implementation: first by y, then by x.
    let byY = stableSorted(screens) { a, b in
      if atOrigin(a) != atOrigin(b) {
        return atOrigin(a)
      }
      return a.frame.origin.y > b.frame.origin.y
    }
    return stableSorted(byY) { a, b in
      if atOrigin(a) != atOrigin(b) {
        return atOrigin(a)
      }
      return a.frame.origin.x > b.frame.origin.x
    }
  }

  /// Sorts keeping equal elements in their original order (the standard library does not
  /// document `sorted(by:)` as stable).
  private static func stableSorted(_ screens: [NSScreen], by areInIncreasingOrder: (NSScreen, NSScreen) -> Bool) -> [NSScreen] {
    screens.enumerated()
      .sorted { a, b in
        if areInIncreasingOrder(a.element, b.element) {
          return true
        }
        if areInIncreasingOrder(b.element, a.element) {
          return false
        }
        return a.offset < b.offset
      }
      .map(\.element)
  }
}
