import AppKit
import Carbon.HIToolbox

/// A rule a newly recorded shortcut must pass.
@MainActor
protocol ShortcutValidator {
  func isValid(_ shortcut: Shortcut, shortcutManager: ShortcutManager) -> Bool
}

/// Rejects shortcuts already used by another Spectacle action.
struct RegisteredShortcutValidator: ShortcutValidator {
  func isValid(_ shortcut: Shortcut, shortcutManager: ShortcutManager) -> Bool {
    !shortcutManager.contains(shortcut)
  }
}

/// Checks a newly recorded shortcut against the enabled system-wide shortcuts (System Settings >
/// Keyboard > Keyboard Shortcuts) and then the validators.
@MainActor
final class ShortcutValidation {
  struct ValidationError: LocalizedError {
    let errorDescription: String?
    let recoverySuggestion: String?
  }

  private let shortcutManager: ShortcutManager
  private let validators: [ShortcutValidator]

  init(shortcutManager: ShortcutManager, validators: [ShortcutValidator] = [RegisteredShortcutValidator()]) {
    self.shortcutManager = shortcutManager
    self.validators = validators
  }

  /// Throws a `ValidationError` describing why the shortcut can't be used.
  func validate(_ shortcut: Shortcut, systemShortcuts: [(keyCode: Int, modifiers: UInt)]? = nil) throws {
    let description = NSLocalizedString(
      "AlertMessageTextShortcutValidationError",
      comment: "The message text of the alert displayed when a shortcut is invalid")
    let display = shortcut.displayString
    for system in systemShortcuts ?? Self.enabledSystemShortcuts()
    where shortcut.keyCode == system.keyCode && shortcut.contains(modifiers: system.modifiers) {
      let suggestion = NSLocalizedString(
        "AlertInformativeTextSystemWideShortcutAlreadyUsed",
        comment: "The informative text of the alert displayed when a system-wide shortcut is already in use")
      throw ValidationError(
        errorDescription: String(format: description, display),
        recoverySuggestion: String(format: suggestion, display))
    }
    for validator in validators where !validator.isValid(shortcut, shortcutManager: shortcutManager) {
      let suggestion = NSLocalizedString(
        "AlertInformativeTextShortcutAlreadyInUse",
        comment: "The informative text of the alert displayed when a shortcut is already in use")
      throw ValidationError(
        errorDescription: String(format: description, display),
        recoverySuggestion: String(format: suggestion, display))
    }
  }

  /// The enabled system-wide shortcuts (key code and Carbon modifiers).
  static func enabledSystemShortcuts() -> [(keyCode: Int, modifiers: UInt)] {
    var unmanaged: Unmanaged<CFArray>?
    guard CopySymbolicHotKeys(&unmanaged) == noErr, let array = unmanaged?.takeRetainedValue() as? [[String: Any]] else {
      return []
    }
    return array.compactMap { entry in
      guard (entry[kHISymbolicHotKeyEnabled as String] as? Bool) == true,
            let keyCode = entry[kHISymbolicHotKeyCode as String] as? Int
      else {
        return nil
      }
      let modifiers = (entry[kHISymbolicHotKeyModifiers as String] as? Int) ?? 0
      return (keyCode, UInt(bitPattern: modifiers))
    }
  }
}
