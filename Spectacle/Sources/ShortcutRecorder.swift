import AppKit
import Carbon.HIToolbox

/// The field in Preferences that records a shortcut: click it, press a key combination.
///
/// The ⓧ badge on the right clears the shortcut (or cancels recording); Escape cancels. While
/// recording, system-wide shortcuts are suspended so the keys reach the field.
///
/// This is an AppKit view (SwiftUI cannot capture raw key presses like this); Preferences hosts it
/// with `ShortcutRecorderField`.
final class ShortcutRecorder: NSView {
  var shortcutName: String?
  var shortcut: Shortcut? {
    didSet {
      updateTrackingArea()
      needsDisplay = true
    }
  }
  /// Checks a recorded shortcut; throw to reject it (the error is shown in an alert).
  var validate: ((Shortcut) throws -> Void)?
  var onNewShortcut: ((Shortcut) -> Void)?
  var onClearShortcut: ((Shortcut?) -> Void)?
  /// Shows why a shortcut was rejected (an alert; replaceable for tests).
  var reportRejectedShortcut: (Error) -> Void = { Alerts.show($0) }

  private(set) var isRecording = false
  private var isMouseDown = false
  private var isMouseAboveBadge = false
  private var badgeTrackingArea: NSTrackingArea?
  private var savedHotKeyMode: UnsafeMutableRawPointer?

  private static let modifierMask: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
  private static let functionKeys: Set<Int> = [
    kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
    kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
  ]

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    // Since macOS 14 views no longer clip their drawing to their bounds by default.
    clipsToBounds = true
    setAccessibilityElement(true)
    setAccessibilityRole(.button)
    updateTrackingArea()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    clipsToBounds = true
    updateTrackingArea()
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: 160, height: 19)
  }

  // MARK: - Events

  override var acceptsFirstResponder: Bool { true }

  override func resignFirstResponder() -> Bool {
    stopRecording()
    return true
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func mouseDown(with event: NSEvent) {
    isMouseDown = true
    needsDisplay = true
  }

  override func mouseUp(with event: NSEvent) {
    let location = convert(event.locationInWindow, from: nil)
    if badgeTrackingArea != nil && Self.badgeRect(in: bounds).contains(location) {
      if isRecording {
        stopRecording()
      } else {
        clearShortcut()
      }
    } else if bounds.contains(location) {
      window?.makeFirstResponder(self)
      startRecording()
    } else {
      needsDisplay = true
    }
    isMouseDown = false
  }

  override func mouseEntered(with event: NSEvent) {
    isMouseAboveBadge = event.trackingArea == badgeTrackingArea
    needsDisplay = true
  }

  override func mouseExited(with event: NSEvent) {
    isMouseAboveBadge = event.trackingArea != badgeTrackingArea
    needsDisplay = true
  }

  override func keyDown(with event: NSEvent) {
    if !performKeyEquivalent(with: event) {
      super.keyDown(with: event)
    }
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard window?.firstResponder === self else {
      return false
    }
    return record(keyCode: Int(event.keyCode), modifiers: event.modifierFlags.intersection(Self.modifierMask))
  }

  /// Handles a key press while focused. Returns whether it was used.
  @discardableResult
  func record(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> Bool {
    if keyCode == kVK_Escape && modifiers.isEmpty {
      stopRecording()
      return true
    }
    let isFunctionKey = Self.functionKeys.contains(keyCode)
    guard isRecording, isFunctionKey || Shortcut.isValidCocoaModifiers(modifiers.rawValue) else {
      return false
    }
    let shortcut = Shortcut(name: shortcutName, keyCode: keyCode, modifiers: modifiers.rawValue)
    do {
      try validate?(shortcut)
      self.shortcut = shortcut
      onNewShortcut?(shortcut)
    } catch {
      reportRejectedShortcut(error)
    }
    stopRecording()
    return true
  }

  override func flagsChanged(with event: NSEvent) {
    if isRecording {
      needsDisplay = true
    }
  }

  // MARK: - Recording

  func startRecording() {
    guard !isRecording else {
      return
    }
    isRecording = true
    savedHotKeyMode = PushSymbolicHotKeyMode(OptionBits(kHIHotKeyModeAllDisabled))
    updateTrackingArea()
    needsDisplay = true
  }

  func stopRecording() {
    guard isRecording else {
      return
    }
    if let savedHotKeyMode {
      PopSymbolicHotKeyMode(savedHotKeyMode)
    }
    savedHotKeyMode = nil
    isRecording = false
    isMouseAboveBadge = false
    updateTrackingArea()
    needsDisplay = true
  }

  func clearShortcut() {
    onClearShortcut?(shortcut)
    shortcut = nil
    isMouseAboveBadge = false
  }

  private func updateTrackingArea() {
    if let badgeTrackingArea {
      removeTrackingArea(badgeTrackingArea)
      self.badgeTrackingArea = nil
    }
    if isRecording || shortcut != nil {
      let area = NSTrackingArea(
        rect: Self.badgeRect(in: bounds),
        options: [.mouseEnteredAndExited, .activeWhenFirstResponder, .enabledDuringMouseDrag],
        owner: self, userInfo: nil)
      addTrackingArea(area)
      badgeTrackingArea = area
    }
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    updateTrackingArea()
  }

  // MARK: - Drawing

  /// The text shown in the field.
  var label: String {
    let pressedModifiers = NSEvent.modifierFlags.intersection(Self.modifierMask)
    if isRecording && !pressedModifiers.isEmpty {
      return KeyTranslation.string(forModifiers: pressedModifiers.rawValue)
    }
    if isRecording && !isMouseAboveBadge {
      return NSLocalizedString("ShortcutRecorderLabelEnterShortcut", comment: "Shown while recording a shortcut")
    } else if isRecording && shortcut == nil {
      return NSLocalizedString("ShortcutRecorderLabelStopRecording", comment: "Shown over the badge while recording without a previous shortcut")
    } else if isRecording {
      return NSLocalizedString("ShortcutRecorderLabelUseExisting", comment: "Shown over the badge while recording with a previous shortcut")
    } else if let shortcut {
      return shortcut.displayString
    }
    return NSLocalizedString("ShortcutRecorderLabelClickToRecord", comment: "Shown when the shortcut is cleared")
  }

  override func draw(_ dirtyRect: NSRect) {
    // Always draw from the bounds: the dirty rect can be much larger than the view on macOS 14
    // and later, and using it painted a huge shape over the Preferences window.
    let rect = bounds
    let radius = rect.height / 2

    // Border.
    NSColor.separatorColor.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

    // Background: a light gradient, blue while recording, inverted while pressed.
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: radius, yRadius: radius)
    let start: NSColor
    let end: NSColor
    if isRecording {
      start = NSColor(srgbRed: 0.784, green: 0.953, blue: 1.0, alpha: 1)
      end = NSColor(srgbRed: 0.694, green: 0.859, blue: 1.0, alpha: 1)
    } else {
      start = NSColor(white: 0.8, alpha: 0.9)
      end = NSColor(white: 1.0, alpha: 0.9)
    }
    let pressed = !isRecording && isMouseDown && !isMouseAboveBadge
    NSGradient(starting: pressed ? end : start, ending: pressed ? start : end)?.draw(in: background, angle: 90)

    // Badge.
    let badge = Self.badgeRect(in: rect)
    if (isRecording && shortcut == nil) || (!isRecording && shortcut != nil) {
      drawClearBadge(in: badge, opacity: (isMouseAboveBadge && isMouseDown) ? 0.5 : 0.25)
    } else if isRecording {
      drawRevertBadge(in: badge)
    }

    // Label, always dark on the light field.
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byTruncatingTail
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
      .foregroundColor: NSColor.black,
      .paragraphStyle: paragraph,
    ]
    let text = label as NSString
    let height = text.size(withAttributes: attributes).height
    let textRect = NSRect(x: rect.minX + 4, y: rect.midY - height / 2, width: badge.minX - rect.minX - 6, height: height)
    text.draw(in: textRect, withAttributes: attributes)
  }

  private func drawClearBadge(in rect: NSRect, opacity: CGFloat) {
    NSColor(white: 0, alpha: opacity).setFill()
    NSBezierPath(ovalIn: rect).fill()
    let scale = rect.width / 13
    let cross = NSBezierPath()
    cross.lineWidth = scale * 1.4
    cross.move(to: NSPoint(x: rect.minX + 4 * scale, y: rect.minY + 4 * scale))
    cross.line(to: NSPoint(x: rect.minX + 9 * scale, y: rect.minY + 9 * scale))
    cross.move(to: NSPoint(x: rect.minX + 9 * scale, y: rect.minY + 4 * scale))
    cross.line(to: NSPoint(x: rect.minX + 4 * scale, y: rect.minY + 9 * scale))
    NSColor.white.setStroke()
    cross.stroke()
  }

  private func drawRevertBadge(in rect: NSRect) {
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
      NSPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }
    let swoosh = NSBezierPath()
    swoosh.move(to: point(0.0489685, 0.6181513))
    swoosh.line(to: point(0.4085750, 0.9469318))
    swoosh.line(to: point(0.4085750, 0.7226146))
    swoosh.curve(to: point(0.8508247, 0.4836237), controlPoint1: point(0.4085750, 0.7226146), controlPoint2: point(0.8371143, 0.7491841))
    swoosh.curve(to: point(0.5507195, 0.0530682), controlPoint1: point(0.8677834, 0.1545071), controlPoint2: point(0.5507195, 0.0530682))
    swoosh.curve(to: point(0.7421721, 0.3391942), controlPoint1: point(0.5507195, 0.0530682), controlPoint2: point(0.7458685, 0.1913146))
    swoosh.curve(to: point(0.4085750, 0.5154130), controlPoint1: point(0.7383412, 0.4930328), controlPoint2: point(0.4085750, 0.5154130))
    swoosh.line(to: point(0.4085750, 0.2654000))
    NSColor(white: 0, alpha: 0.5).setFill()
    swoosh.fill()
  }

  static func badgeRect(in bounds: NSRect) -> NSRect {
    let size: CGFloat = 13
    return NSRect(x: bounds.maxX - size - 4, y: floor((bounds.maxY - size) / 2), width: size, height: size)
  }
}
