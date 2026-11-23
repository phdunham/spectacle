import AppKit
import Carbon.HIToolbox

/// A named keyboard shortcut ("MoveToLeftHalf" = ⌥⌘←) and what it does when pressed.
///
/// Modifiers are stored as Carbon modifier flags (`cmdKey`, `optionKey`, …), the form
/// `RegisterEventHotKey` expects; Cocoa modifier flags passed in are converted.
///
/// The Objective-C name and `NSCoding` support let shortcuts saved by older releases in
/// user defaults (as "SpectacleShortcut", "SpectacleHotKey", "ZeroKitHotKey" or "ZKHotKey")
/// still be read.
@objc(SpectacleShortcut)
final class Shortcut: NSObject, NSCoding {
  typealias Action = @MainActor (Shortcut) -> Void

  let name: String?
  /// The virtual key code (`kVK_…`), or -1 for a cleared shortcut.
  let keyCode: Int
  /// Carbon modifier flags.
  let modifiers: UInt
  let action: Action?

  init(name: String?, keyCode: Int, modifiers: UInt, action: Action? = nil) {
    self.name = name
    self.keyCode = keyCode
    self.modifiers = KeyTranslation.carbonModifiersIfNecessary(modifiers)
    self.action = action
    super.init()
  }

  /// A shortcut from a key binding such as "alt+cmd+left"; nil or "" gives a cleared shortcut.
  convenience init(name: String?, keyBinding: String?, action: Action? = nil) {
    self.init(
      name: name,
      keyCode: KeyBinding.keyCode(from: keyBinding) ?? -1,
      modifiers: KeyBinding.modifiers(from: keyBinding) ?? 0,
      action: action)
  }

  func with(action: Action?) -> Shortcut {
    Shortcut(name: name, keyCode: keyCode, modifiers: modifiers, action: action)
  }

  @MainActor
  func trigger() {
    action?(self)
  }

  /// A shortcut with no key assigned.
  var isCleared: Bool {
    keyCode == -1 || (keyCode == 0 && modifiers == 0)
  }

  /// The key binding ("alt+cmd+left"), or nil for a cleared shortcut.
  var keyBinding: String? {
    KeyBinding.keyBinding(for: self)
  }

  /// The shortcut as shown to people, e.g. "⌥⌘←".
  var displayString: String {
    KeyTranslation.string(for: self)
  }

  /// The window action this shortcut performs, from its name.
  var windowAction: WindowAction {
    Self.windowActions[name ?? ""] ?? .none
  }

  static let windowActions: [String: WindowAction] = [
    "MoveToCenter": .center,
    "MoveToFullscreen": .fullscreen,
    "MoveToLeftHalf": .leftHalf,
    "MoveToRightHalf": .rightHalf,
    "MoveToTopHalf": .topHalf,
    "MoveToBottomHalf": .bottomHalf,
    "MoveToUpperLeft": .upperLeft,
    "MoveToLowerLeft": .lowerLeft,
    "MoveToUpperRight": .upperRight,
    "MoveToLowerRight": .lowerRight,
    "MoveToNextDisplay": .nextDisplay,
    "MoveToPreviousDisplay": .previousDisplay,
    "MoveToNextThird": .nextThird,
    "MoveToPreviousThird": .previousThird,
    "MakeLarger": .larger,
    "MakeSmaller": .smaller,
    "UndoLastMove": .undo,
    "RedoLastMove": .redo,
  ]

  /// Whether the shortcut uses exactly these modifiers (Cocoa or Carbon flags). Used to detect
  /// clashes with system-wide shortcuts, so ⌥⌘Space does not clash with Spotlight's ⌘Space.
  func contains(modifiers other: UInt) -> Bool {
    modifiers == KeyTranslation.carbonModifiersIfNecessary(other)
  }

  /// Whether `modifiers` contains at least one Cocoa modifier flag (⌃, ⌥, ⇧ or ⌘).
  static func isValidCocoaModifiers(_ modifiers: UInt) -> Bool {
    let flags = NSEvent.ModifierFlags(rawValue: modifiers)
    return !flags.intersection([.option, .command, .control, .shift]).isEmpty
  }

  // MARK: - Equality (same key and modifiers; the name does not matter)

  override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? Shortcut else {
      return false
    }
    return other === self || (other.keyCode == keyCode && other.modifiers == modifiers)
  }

  override var hash: Int {
    keyCode.hashValue ^ modifiers.hashValue
  }

  override var description: String {
    "<Shortcut \(name ?? "-") \(keyBinding ?? "cleared")>"
  }

  // MARK: - NSCoding (legacy user defaults storage)

  init?(coder: NSCoder) {
    name = coder.decodeObject(forKey: "name") as? String
    keyCode = coder.decodeInteger(forKey: "keyCode")
    modifiers = KeyTranslation.carbonModifiersIfNecessary(UInt(bitPattern: coder.decodeInteger(forKey: "modifiers")))
    action = nil
    super.init()
  }

  func encode(with coder: NSCoder) {
    coder.encode(name, forKey: "name")
    coder.encode(keyCode, forKey: "keyCode")
    coder.encode(Int(bitPattern: modifiers), forKey: "modifiers")
  }
}
