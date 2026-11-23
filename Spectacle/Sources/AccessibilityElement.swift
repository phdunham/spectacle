import AppKit
import ApplicationServices
import os

/// A window (or application) seen through the macOS Accessibility API.
///
/// Rects are in accessibility coordinates: origin at the top-left of the primary screen, y down.
/// `normalize(_:)` converts between those and Cocoa coordinates (bottom-left origin, y up).
///
/// The class is subclassed by the tests to fake windows; override `rect()`, `setRect(_:)`,
/// `isSheet()` and `isSystemDialog()`.
@MainActor
class AccessibilityElement {
  private static let log = Logger(subsystem: "com.divisiblebyzero.Spectacle", category: "Accessibility")
  private static let enhancedUserInterfaceAttribute = "AXEnhancedUserInterface" as CFString

  let underlyingElement: AXUIElement?

  init(underlyingElement: AXUIElement?) {
    self.underlyingElement = underlyingElement
  }

  /// An element not backed by the Accessibility API (used by test doubles).
  convenience init() {
    self.init(underlyingElement: nil)
  }

  // MARK: - Finding elements

  static func frontmostApplication() -> AccessibilityElement? {
    guard let application = NSWorkspace.shared.frontmostApplication else {
      log.notice("Failed to find the application that currently has focus.")
      return nil
    }
    return AccessibilityElement(underlyingElement: AXUIElementCreateApplication(application.processIdentifier))
  }

  /// The focused window of the frontmost application, or nil (e.g. when only the desktop is
  /// frontmost, or Spectacle has no Accessibility access).
  static func frontmostWindow() -> AccessibilityElement? {
    frontmostApplication()?.element(for: kAXFocusedWindowAttribute as String)
  }

  func element(for attribute: String) -> AccessibilityElement? {
    guard let value = copyValue(attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else {
      return nil
    }
    return AccessibilityElement(underlyingElement: (value as! AXUIElement))
  }

  // MARK: - Attributes

  func string(for attribute: String) -> String? {
    copyValue(attribute) as? String
  }

  private func copyValue(_ attribute: String) -> CFTypeRef? {
    guard let underlyingElement else {
      return nil
    }
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(underlyingElement, attribute as CFString, &value)
    guard result == .success else {
      return nil
    }
    return value
  }

  private func axValue(_ attribute: String, type: AXValueType) -> AXValue? {
    guard let value = copyValue(attribute), CFGetTypeID(value) == AXValueGetTypeID() else {
      return nil
    }
    let axValue = value as! AXValue
    return AXValueGetType(axValue) == type ? axValue : nil
  }

  private func point(_ attribute: String) -> CGPoint? {
    var point = CGPoint.zero
    guard let value = axValue(attribute, type: .cgPoint), AXValueGetValue(value, .cgPoint, &point) else {
      return nil
    }
    return point
  }

  private func size(_ attribute: String) -> CGSize? {
    var size = CGSize.zero
    guard let value = axValue(attribute, type: .cgSize), AXValueGetValue(value, .cgSize, &size) else {
      return nil
    }
    return size
  }

  /// The element's frame, or `.null` if it has none.
  func rect() -> CGRect {
    guard let position = point(kAXPositionAttribute as String), let size = size(kAXSizeAttribute as String) else {
      return .null
    }
    return CGRect(origin: position, size: size)
  }

  /// Moves and resizes the element.
  ///
  /// Many applications (Chromium/Electron apps, Microsoft Office, Firefox, …) switch on
  /// AXEnhancedUserInterface when an assistive app talks to them; while it is on they animate
  /// frame changes, so a size set here is applied late and the window ends up the wrong size or
  /// in the wrong place. It is switched off for the change and restored afterwards.
  ///
  /// The size is set, then the position, then the size again: the first resize can be limited by
  /// the screen the window is still on (e.g. when moving to a larger display).
  func setRect(_ rect: CGRect) {
    guard let underlyingElement else {
      return
    }
    var application: AXUIElement?
    var processIdentifier: pid_t = 0
    if AXUIElementGetPid(underlyingElement, &processIdentifier) == .success {
      application = AXUIElementCreateApplication(processIdentifier)
    }
    var enhancedUserInterfaceWasOn = false
    if let application {
      var value: CFTypeRef?
      if AXUIElementCopyAttributeValue(application, Self.enhancedUserInterfaceAttribute, &value) == .success,
         let value, CFGetTypeID(value) == CFBooleanGetTypeID() {
        enhancedUserInterfaceWasOn = CFBooleanGetValue((value as! CFBoolean))
      }
      if enhancedUserInterfaceWasOn {
        AXUIElementSetAttributeValue(application, Self.enhancedUserInterfaceAttribute, kCFBooleanFalse)
      }
    }
    var origin = rect.origin
    var size = rect.size
    if let position = AXValueCreate(.cgPoint, &origin), let sizeValue = AXValueCreate(.cgSize, &size) {
      set(sizeValue, for: kAXSizeAttribute as String, on: underlyingElement)
      set(position, for: kAXPositionAttribute as String, on: underlyingElement)
      set(sizeValue, for: kAXSizeAttribute as String, on: underlyingElement)
    }
    if let application, enhancedUserInterfaceWasOn {
      AXUIElementSetAttributeValue(application, Self.enhancedUserInterfaceAttribute, kCFBooleanTrue)
    }
  }

  private func set(_ value: AXValue, for attribute: String, on element: AXUIElement) {
    let result = AXUIElementSetAttributeValue(element, attribute as CFString, value)
    if result != .success {
      Self.log.debug("Could not set \(attribute, privacy: .public): error \(result.rawValue)")
    }
  }

  func isSheet() -> Bool {
    string(for: kAXRoleAttribute as String) == kAXSheetRole as String
  }

  func isSystemDialog() -> Bool {
    string(for: kAXSubroleAttribute as String) == kAXSystemDialogSubrole as String
  }

  // MARK: - Coordinates

  /// Overrides the primary screen frame used for coordinate conversion (for tests); nil uses
  /// the real primary screen.
  static var primaryScreenFrameOverride: CGRect?

  /// The frame of the primary screen (the one with the menu bar), in Cocoa coordinates.
  static func frameOfPrimaryScreen() -> CGRect {
    if let primaryScreenFrameOverride {
      return primaryScreenFrameOverride
    }
    // The first screen is always the primary one; the accessibility coordinate space has its
    // origin at that screen's top-left corner.
    return NSScreen.screens.first?.frame ?? .null
  }

  /// Converts a rect between Cocoa and accessibility coordinates. The conversion is its own
  /// inverse and only depends on the height of the primary screen.
  static func normalize(_ rect: CGRect) -> CGRect {
    let primary = frameOfPrimaryScreen()
    guard !rect.isNull, !primary.isNull else {
      return rect
    }
    var result = rect
    result.origin.y = primary.maxY - rect.maxY
    return result
  }
}
