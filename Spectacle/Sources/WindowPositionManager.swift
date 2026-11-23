import AppKit

/// Moves the frontmost window for an action: finds its screen, calculates the new position with
/// `WindowLayout`, records undo history (per application) and hands the move to the window mover
/// chain.
///
/// The accessibility API uses a top-left origin and the layout math Cocoa's bottom-left origin;
/// `AccessibilityElement.normalize(_:)` converts between them.
@MainActor
final class WindowPositionManager {
  private var applicationHistories: [String: WindowHistory] = [:]
  private let screenDetector: ScreenDetector
  private let workspace: NSWorkspace
  private let failureFeedback: () -> Void
  private let windowMover: WindowMover?

  init(
    screenDetector: ScreenDetector = ScreenDetector(),
    workspace: NSWorkspace = .shared,
    failureFeedback: @escaping () -> Void = { NSSound.beep() },
    windowMover: WindowMover? = WindowPositionManager.defaultWindowMover()
  ) {
    self.screenDetector = screenDetector
    self.workspace = workspace
    self.failureFeedback = failureFeedback
    self.windowMover = windowMover
  }

  /// The window mover chain used by the application: standard → quantized → best effort.
  static func defaultWindowMover() -> WindowMover {
    StandardWindowMover(next: QuantizedWindowMover(next: BestEffortWindowMover()))
  }

  // MARK: - Moving

  /// Performs `action` on the frontmost window using the real screens. Undo and redo go to
  /// the history.
  func perform(_ action: WindowAction, on window: AccessibilityElement? = AccessibilityElement.frontmostWindow()) {
    if action.isUndo {
      undo()
    } else if action.isRedo {
      redo()
    } else {
      move(window, action: action, screens: NSScreen.screens, mainScreen: NSScreen.main)
    }
  }

  /// Performs a placement action on `window` with the given screens (injectable for tests).
  func move(_ window: AccessibilityElement?, action: WindowAction, screens: [NSScreen], mainScreen: NSScreen?) {
    guard let window else {
      // No focused window (e.g. only the desktop is frontmost).
      failureFeedback()
      return
    }
    let detection = screenDetector.detect(action: action, window: window, screens: screens, mainScreen: mainScreen)
    let windowRect = window.rect()
    guard
      !window.isSheet(),
      !window.isSystemDialog(),
      !windowRect.isNull,
      let source = detection.sourceScreen,
      let destination = detection.destinationScreen,
      let layoutAction = WindowLayout.Action(rawValue: action.rawValue)
    else {
      failureFeedback()
      return
    }
    let history = historyForFrontmostApplication()
    // Remember where the window started, so the first move can be undone.
    if let history, history.isEmpty {
      history.add(WindowHistoryItem(window: window, windowRect: windowRect))
    }
    let cocoaRect = AccessibilityElement.normalize(windowRect)
    let newCocoaRect = WindowLayout.rect(for: layoutAction, window: cocoaRect, source: source.visibleFrame, destination: destination.visibleFrame)
    guard newCocoaRect != cocoaRect else {
      // The window is already there.
      failureFeedback()
      return
    }
    let newRect = AccessibilityElement.normalize(newCocoaRect)
    history?.add(WindowHistoryItem(window: window, windowRect: newRect))
    windowMover?.move(newRect, frameOfScreen: destination.frame, visibleFrameOfScreen: destination.visibleFrame, window: window, action: action)
  }

  // MARK: - Undo and redo

  func undo(screens: [NSScreen] = NSScreen.screens, mainScreen: NSScreen? = NSScreen.main) {
    restore(historyForFrontmostApplication()?.undo(), action: .undo, screens: screens, mainScreen: mainScreen)
  }

  func redo(screens: [NSScreen] = NSScreen.screens, mainScreen: NSScreen? = NSScreen.main) {
    restore(historyForFrontmostApplication()?.redo(), action: .redo, screens: screens, mainScreen: mainScreen)
  }

  private func restore(_ item: WindowHistoryItem?, action: WindowAction, screens: [NSScreen], mainScreen: NSScreen?) {
    guard let item, let window = item.window, !item.windowRect.isNull else {
      failureFeedback()
      return
    }
    let detection = screenDetector.detect(action: action, window: window, screens: screens, mainScreen: mainScreen)
    guard let destination = detection.destinationScreen else {
      failureFeedback()
      return
    }
    windowMover?.move(item.windowRect, frameOfScreen: destination.frame, visibleFrameOfScreen: destination.visibleFrame, window: window, action: action)
  }

  /// The undo history of the frontmost application, created on first use; nil when the
  /// frontmost application has no bundle identifier.
  private func historyForFrontmostApplication() -> WindowHistory? {
    guard let bundleIdentifier = workspace.frontmostApplication?.bundleIdentifier else {
      return nil
    }
    if let history = applicationHistories[bundleIdentifier] {
      return history
    }
    let history = WindowHistory()
    applicationHistories[bundleIdentifier] = history
    return history
  }
}
