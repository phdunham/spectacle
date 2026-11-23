import AppKit
import Carbon.HIToolbox

/// How shortcuts are shown to people ("⌥⌘←"), and conversion between Cocoa and Carbon modifier
/// flags.
enum KeyTranslation {
  /// The symbol for a key code: a fixed glyph for keys that are the same on every keyboard layout
  /// (function keys, arrows, Return, …), otherwise the character the current keyboard layout
  /// produces, uppercased. "?" if it cannot be determined.
  static func string(forKeyCode keyCode: Int) -> String {
    if let fixed = layoutIndependentKeys[keyCode] {
      return fixed
    }
    guard let layoutData = currentKeyboardLayoutData() else {
      return "?"
    }
    return layoutData.withUnsafeBytes { buffer -> String in
      guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
        return "?"
      }
      var deadKeyState: UInt32 = 0
      var length = 0
      var characters = [UniChar](repeating: 0, count: 4)
      let status = UCKeyTranslate(
        layout, UInt16(truncatingIfNeeded: keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
        OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, characters.count, &length, &characters)
      guard status == noErr else {
        return "?"
      }
      return String(utf16CodeUnits: characters, count: length).uppercased()
    }
  }

  private static func currentKeyboardLayoutData() -> Data? {
    for source in [TISCopyCurrentKeyboardLayoutInputSource(), TISCopyCurrentASCIICapableKeyboardLayoutInputSource()] {
      guard let source = source?.takeRetainedValue(),
            let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
      else {
        continue
      }
      return Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
    }
    return nil
  }

  /// The modifier glyphs in the standard order: ⌃⌥⇧⌘.
  static func string(forModifiers modifiers: UInt) -> String {
    let flags = NSEvent.ModifierFlags(rawValue: cocoaModifiersIfNecessary(modifiers))
    var glyphs = ""
    if flags.contains(.control) { glyphs += "⌃" }
    if flags.contains(.option) { glyphs += "⌥" }
    if flags.contains(.shift) { glyphs += "⇧" }
    if flags.contains(.command) { glyphs += "⌘" }
    return glyphs
  }

  static func string(for shortcut: Shortcut) -> String {
    string(forModifiers: shortcut.modifiers) + string(forKeyCode: shortcut.keyCode)
  }

  // MARK: - Modifier flags

  static func carbonModifiers(fromCocoa modifiers: UInt) -> UInt {
    let flags = NSEvent.ModifierFlags(rawValue: modifiers)
    var result: UInt = 0
    if flags.contains(.control) { result |= UInt(controlKey) }
    if flags.contains(.option) { result |= UInt(optionKey) }
    if flags.contains(.shift) { result |= UInt(shiftKey) }
    if flags.contains(.command) { result |= UInt(cmdKey) }
    return result
  }

  static func cocoaModifiers(fromCarbon modifiers: UInt) -> UInt {
    var flags: NSEvent.ModifierFlags = []
    if modifiers & UInt(controlKey) != 0 { flags.insert(.control) }
    if modifiers & UInt(optionKey) != 0 { flags.insert(.option) }
    if modifiers & UInt(shiftKey) != 0 { flags.insert(.shift) }
    if modifiers & UInt(cmdKey) != 0 { flags.insert(.command) }
    return flags.rawValue
  }

  /// Converts Cocoa flags to Carbon; Carbon flags are returned unchanged.
  static func carbonModifiersIfNecessary(_ modifiers: UInt) -> UInt {
    Shortcut.isValidCocoaModifiers(modifiers) ? carbonModifiers(fromCocoa: modifiers) : modifiers
  }

  /// Converts Carbon flags to Cocoa; Cocoa flags are returned unchanged.
  static func cocoaModifiersIfNecessary(_ modifiers: UInt) -> UInt {
    Shortcut.isValidCocoaModifiers(modifiers) ? modifiers : cocoaModifiers(fromCarbon: modifiers)
  }

  // MARK: - Fixed key symbols

  static let layoutIndependentKeys: [Int: String] = [
    kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
    kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
    kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15",
    kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    kVK_ANSI_KeypadDecimal: ".", kVK_ANSI_KeypadMultiply: "*", kVK_ANSI_KeypadPlus: "+",
    kVK_ANSI_KeypadClear: "⌧", kVK_ANSI_KeypadDivide: "/", kVK_ANSI_KeypadEnter: "⌤",
    kVK_ANSI_KeypadMinus: "-", kVK_ANSI_KeypadEquals: "=",
    kVK_ANSI_Keypad0: "0", kVK_ANSI_Keypad1: "1", kVK_ANSI_Keypad2: "2", kVK_ANSI_Keypad3: "3",
    kVK_ANSI_Keypad4: "4", kVK_ANSI_Keypad5: "5", kVK_ANSI_Keypad6: "6", kVK_ANSI_Keypad7: "7",
    kVK_ANSI_Keypad8: "8", kVK_ANSI_Keypad9: "9",
    kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "␣", kVK_Delete: "⌫", kVK_Escape: "⎋",
    kVK_Command: "⌘", kVK_Shift: "⇧", kVK_CapsLock: "⇪", kVK_Option: "⌥", kVK_Control: "⌃",
    kVK_RightShift: "", kVK_RightOption: "", kVK_RightControl: "", kVK_Function: "",
    kVK_VolumeUp: "", kVK_VolumeDown: "", kVK_Mute: "", kVK_Help: "",
    kVK_Home: "↖", kVK_PageUp: "⇞", kVK_ForwardDelete: "⌦", kVK_End: "↘", kVK_PageDown: "⇟",
    kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_DownArrow: "↓", kVK_UpArrow: "↑",
  ]
}
