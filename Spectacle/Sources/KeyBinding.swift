import Carbon.HIToolbox

/// Converts between shortcuts and key bindings, the text form used in Shortcuts.json:
/// modifiers and a key joined with "+", e.g. "alt+cmd+left" or "ctrl+shift+F1".
///
/// Parsing ignores case and spaces and accepts aliases (cmd/command, alt/option, ctrl/control).
/// Writing always uses ctrl, alt, shift, cmd (in that order) and a lowercase key.
enum KeyBinding {
  /// The key code of the binding's key, or nil if there is none or it is unknown.
  static func keyCode(from keyBinding: String?) -> Int? {
    guard let keyBinding,
          let key = keyBinding.components(separatedBy: "+").last?.trimmingCharacters(in: .whitespacesAndNewlines),
          !key.isEmpty
    else {
      return nil
    }
    let normalized = key.uppercased()
    return namedKeyCodes[normalized] ?? characterKeyCodes[normalized]
  }

  /// The Carbon modifier flags of the binding, or nil if it has no modifier part.
  static func modifiers(from keyBinding: String?) -> UInt? {
    guard let keyBinding else {
      return nil
    }
    let components = keyBinding.components(separatedBy: "+")
    guard components.count >= 2 else {
      return nil
    }
    var modifiers: UInt = 0
    for component in components.dropLast() {
      let normalized = component.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
      if let modifier = modifierFlags[normalized] {
        modifiers |= modifier
      }
    }
    return modifiers
  }

  /// The key binding for a shortcut, or nil for a cleared shortcut or an unknown key.
  static func keyBinding(for shortcut: Shortcut) -> String? {
    guard !shortcut.isCleared, let key = component(forKeyCode: shortcut.keyCode)?.lowercased() else {
      return nil
    }
    return (modifierComponents(for: shortcut.modifiers) + [key]).joined(separator: "+")
  }

  // MARK: - Tables

  static func component(forKeyCode keyCode: Int) -> String? {
    if let named = namedKeyNames[keyCode], !named.isEmpty {
      return named
    }
    return characterKeys[keyCode]
  }

  private static func modifierComponents(for modifiers: UInt) -> [String] {
    var components: [String] = []
    if modifiers & UInt(controlKey) != 0 { components.append("ctrl") }
    if modifiers & UInt(optionKey) != 0 { components.append("alt") }
    if modifiers & UInt(shiftKey) != 0 { components.append("shift") }
    if modifiers & UInt(cmdKey) != 0 { components.append("cmd") }
    return components
  }

  static let modifierFlags: [String: UInt] = [
    "COMMAND": UInt(cmdKey),
    "CMD": UInt(cmdKey),
    "SHIFT": UInt(shiftKey),
    "OPTION": UInt(optionKey),
    "ALT": UInt(optionKey),
    "CONTROL": UInt(controlKey),
    "CTRL": UInt(controlKey),
  ]

  /// Keys written as their character ("A", "1", "=").
  static let characterKeys: [Int: String] = [
    kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
    kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
    kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E",
    kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J",
    kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
    kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
    kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X", kVK_ANSI_Y: "Y",
    kVK_ANSI_Z: "Z",
    kVK_ANSI_Equal: "=", kVK_ANSI_Minus: "-", kVK_ANSI_RightBracket: "]", kVK_ANSI_LeftBracket: "[",
    kVK_ANSI_Quote: "'", kVK_ANSI_Semicolon: ";", kVK_ANSI_Backslash: "\\", kVK_ANSI_Comma: ",",
    kVK_ANSI_Slash: "/", kVK_ANSI_Period: ".", kVK_ANSI_Grave: "`",
  ]

  private static let characterKeyCodes: [String: Int] = Dictionary(
    uniqueKeysWithValues: characterKeys.map { ($0.value, $0.key) })

  /// Keys written by name ("F1", "LEFT", "KEYPAD0", "SPACE").
  static let namedKeyCodes: [String: Int] = [
    "F1": kVK_F1, "F2": kVK_F2, "F3": kVK_F3, "F4": kVK_F4, "F5": kVK_F5,
    "F6": kVK_F6, "F7": kVK_F7, "F8": kVK_F8, "F9": kVK_F9, "F10": kVK_F10,
    "F11": kVK_F11, "F12": kVK_F12, "F13": kVK_F13, "F14": kVK_F14, "F15": kVK_F15,
    "F16": kVK_F16, "F17": kVK_F17, "F18": kVK_F18, "F19": kVK_F19, "F20": kVK_F20,
    "KEYPADDECIMAL": kVK_ANSI_KeypadDecimal, "KEYPADMULTIPLY": kVK_ANSI_KeypadMultiply,
    "KEYPADPLUS": kVK_ANSI_KeypadPlus, "KEYPADCLEAR": kVK_ANSI_KeypadClear,
    "KEYPADDIVIDE": kVK_ANSI_KeypadDivide, "KEYPADENTER": kVK_ANSI_KeypadEnter,
    "KEYPADMINUS": kVK_ANSI_KeypadMinus, "KEYPADEQUALS": kVK_ANSI_KeypadEquals,
    "KEYPAD0": kVK_ANSI_Keypad0, "KEYPAD1": kVK_ANSI_Keypad1, "KEYPAD2": kVK_ANSI_Keypad2,
    "KEYPAD3": kVK_ANSI_Keypad3, "KEYPAD4": kVK_ANSI_Keypad4, "KEYPAD5": kVK_ANSI_Keypad5,
    "KEYPAD6": kVK_ANSI_Keypad6, "KEYPAD7": kVK_ANSI_Keypad7, "KEYPAD8": kVK_ANSI_Keypad8,
    "KEYPAD9": kVK_ANSI_Keypad9,
    "RETURN": kVK_Return, "TAB": kVK_Tab, "SPACE": kVK_Space, "DELETE": kVK_Delete,
    "ESCAPE": kVK_Escape, "COMMAND": kVK_Command, "SHIFT": kVK_Shift, "CAPSLOCK": kVK_CapsLock,
    "OPTION": kVK_Option, "CONTROL": kVK_Control, "RIGHTSHIFT": kVK_RightShift,
    "RIGHTOPTION": kVK_RightOption, "RIGHTCONTROL": kVK_RightControl, "FUNCTION": kVK_Function,
    "VOLUMEUP": kVK_VolumeUp, "VOLUMEDOWN": kVK_VolumeDown, "MUTE": kVK_Mute, "HELP": kVK_Help,
    "HOME": kVK_Home, "PAGEUP": kVK_PageUp, "FORWARDDELETE": kVK_ForwardDelete, "END": kVK_End,
    "PAGEDOWN": kVK_PageDown, "LEFT": kVK_LeftArrow, "RIGHT": kVK_RightArrow,
    "DOWN": kVK_DownArrow, "UP": kVK_UpArrow,
  ]

  private static let namedKeyNames: [Int: String] = Dictionary(
    uniqueKeysWithValues: namedKeyCodes.map { ($0.value, $0.key) })
}
