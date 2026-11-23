import CoreGraphics
import Foundation

/// One remembered window position: the window and where it was (accessibility coordinates).
@MainActor
final class WindowHistoryItem {
  let window: AccessibilityElement?
  let windowRect: CGRect
  /// The newer item. Items own the newer ones, so the chain stays alive from the oldest.
  fileprivate(set) var next: WindowHistoryItem?
  /// The older item (weak, to avoid a reference cycle).
  fileprivate(set) weak var previous: WindowHistoryItem?

  init(window: AccessibilityElement?, windowRect: CGRect) {
    self.window = window
    self.windowRect = windowRect
  }
}

/// Undo/redo history of window positions for one application, as a doubly linked list.
///
/// Adding an item after undoing discards the redo branch. At most `capacity` items are kept;
/// the oldest are dropped first.
@MainActor
final class WindowHistory {
  static let capacity = 50

  /// The oldest item still kept; it owns the rest of the chain through `next`.
  private var oldest: WindowHistoryItem?
  private var current: WindowHistoryItem?
  /// The number of items up to and including the current one.
  private var size = 0

  var isEmpty: Bool { size == 0 }

  func add(_ item: WindowHistoryItem) {
    if isEmpty {
      current = item
      oldest = item
    } else {
      item.previous = current
      // Replacing the current item's next item releases the old redo branch.
      current?.next = item
      current = item
    }
    size += 1
    if size > Self.capacity {
      let newOldest = oldest?.next
      newOldest?.previous = nil
      oldest = newOldest
      size -= 1
    }
  }

  /// Redo: moves forward and returns the newer item, or nil if there is nothing to redo.
  @discardableResult
  func redo() -> WindowHistoryItem? {
    guard let item = current?.next else {
      return nil
    }
    current = item
    size += 1
    return item
  }

  /// Undo: moves back and returns the older item, or nil if there is nothing to undo.
  @discardableResult
  func undo() -> WindowHistoryItem? {
    guard let item = current?.previous else {
      return nil
    }
    current = item
    size -= 1
    return item
  }
}
