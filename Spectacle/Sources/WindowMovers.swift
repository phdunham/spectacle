import CoreGraphics
import Foundation

/// One step in the chain that applies a calculated window position (see
/// `WindowPositionManager.defaultWindowMover()`: standard → quantized → best effort). Each step
/// does its part and passes the same request to the next.
///
/// `windowRect` is in accessibility coordinates; the screen frames are in Cocoa coordinates.
@MainActor
protocol WindowMover: AnyObject {
  func move(
    _ windowRect: CGRect,
    frameOfScreen: CGRect,
    visibleFrameOfScreen: CGRect,
    window: AccessibilityElement,
    action: WindowAction)
}

/// Sets the window's frame to the requested rect.
@MainActor
final class StandardWindowMover: WindowMover {
  private let next: WindowMover?

  init(next: WindowMover? = nil) {
    self.next = next
  }

  func move(_ windowRect: CGRect, frameOfScreen: CGRect, visibleFrameOfScreen: CGRect, window: AccessibilityElement, action: WindowAction) {
    guard !window.rect().isNull else {
      return
    }
    window.setRect(windowRect)
    next?.move(windowRect, frameOfScreen: frameOfScreen, visibleFrameOfScreen: visibleFrameOfScreen, window: window, action: action)
  }
}

/// Handles windows that only resize in steps (e.g. Terminal's character grid) and round the
/// requested size up, so they would spill out of the target area: shrinks the request two points
/// at a time until the window fits (giving up below 85%), then centers it in the target area.
@MainActor
final class QuantizedWindowMover: WindowMover {
  /// The smallest fraction of the requested size the window is shrunk to before giving up
  /// (0.85 as a single-precision float, exactly as the original implementation compared).
  static let minimumScale = CGFloat(Float(0.85))

  private let next: WindowMover?

  init(next: WindowMover? = nil) {
    self.next = next
  }

  func move(_ windowRect: CGRect, frameOfScreen: CGRect, visibleFrameOfScreen: CGRect, window: AccessibilityElement, action: WindowAction) {
    var movedRect = window.rect()
    if !movedRect.isNull && movedRect != windowRect {
      var adjustedRect = windowRect
      while movedRect.width > windowRect.width || movedRect.height > windowRect.height {
        if movedRect.width > windowRect.width {
          adjustedRect.size.width -= 2
        }
        if movedRect.height > windowRect.height {
          adjustedRect.size.height -= 2
        }
        if adjustedRect.width < windowRect.width * Self.minimumScale
          || adjustedRect.height < windowRect.height * Self.minimumScale {
          break
        }
        window.setRect(adjustedRect)
        movedRect = window.rect()
      }
      adjustedRect.origin.x += floor((windowRect.width - movedRect.width) / 2)
      adjustedRect.origin.y += floor((windowRect.height - movedRect.height) / 2)
      window.setRect(adjustedRect)
    }
    next?.move(windowRect, frameOfScreen: frameOfScreen, visibleFrameOfScreen: visibleFrameOfScreen, window: window, action: action)
  }
}

/// Last step: if the window ended up partly off the visible area (for example because it has a
/// minimum size larger than the target), slides it back on screen without resizing it.
@MainActor
final class BestEffortWindowMover: WindowMover {
  private let next: WindowMover?

  init(next: WindowMover? = nil) {
    self.next = next
  }

  func move(_ windowRect: CGRect, frameOfScreen: CGRect, visibleFrameOfScreen visible: CGRect, window: AccessibilityElement, action: WindowAction) {
    next?.move(windowRect, frameOfScreen: frameOfScreen, visibleFrameOfScreen: visible, window: window, action: action)
    let originalRect = window.rect()
    guard !originalRect.isNull else {
      // The window has no frame (it closed, or never had one); there is nothing to correct.
      return
    }
    var rect = originalRect
    // Horizontal: the x axis is the same in both coordinate systems.
    if rect.minX < visible.minX {
      rect.origin.x = visible.minX
    } else if rect.minX + rect.width > visible.minX + visible.width {
      rect.origin.x = visible.minX + visible.width - rect.width
    }
    // Vertical: compare in Cocoa coordinates, then convert back.
    rect = AccessibilityElement.normalize(rect)
    if rect.minY < visible.minY {
      rect.origin.y = visible.minY
    } else if rect.minY + rect.height > visible.minY + visible.height {
      rect.origin.y = visible.minY + visible.height - rect.height
    }
    rect = AccessibilityElement.normalize(rect)
    if rect != originalRect {
      window.setRect(rect)
    }
  }
}
