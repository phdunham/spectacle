import Foundation
import os

private let storageLog = Logger(subsystem: "com.divisiblebyzero.Spectacle", category: "Shortcuts")

/// The shortcut names in the order they appear in Preferences and the menu.
enum ShortcutNames {
  static let all = [
    "MoveToCenter", "MoveToFullscreen",
    "MoveToLeftHalf", "MoveToRightHalf", "MoveToTopHalf", "MoveToBottomHalf",
    "MoveToUpperLeft", "MoveToLowerLeft", "MoveToUpperRight", "MoveToLowerRight",
    "MoveToNextDisplay", "MoveToPreviousDisplay",
    "MoveToNextThird", "MoveToPreviousThird",
    "MakeLarger", "MakeSmaller",
    "UndoLastMove", "RedoLastMove",
  ]
}

/// The shortcuts Spectacle starts with, and "Restore Defaults" brings back.
enum DefaultShortcuts {
  static let keyBindings: [(name: String, keyBinding: String)] = [
    ("MoveToCenter", "alt+cmd+c"),
    ("MoveToFullscreen", "alt+cmd+f"),
    ("MoveToLeftHalf", "alt+cmd+left"),
    ("MoveToRightHalf", "alt+cmd+right"),
    ("MoveToTopHalf", "alt+cmd+up"),
    ("MoveToBottomHalf", "alt+cmd+down"),
    ("MoveToUpperLeft", "ctrl+cmd+left"),
    ("MoveToLowerLeft", "ctrl+shift+cmd+left"),
    ("MoveToUpperRight", "ctrl+cmd+right"),
    ("MoveToLowerRight", "ctrl+shift+cmd+right"),
    ("MoveToNextDisplay", "ctrl+alt+cmd+right"),
    ("MoveToPreviousDisplay", "ctrl+alt+cmd+left"),
    ("MoveToNextThird", "ctrl+alt+right"),
    ("MoveToPreviousThird", "ctrl+alt+left"),
    ("MakeLarger", "ctrl+alt+shift+right"),
    ("MakeSmaller", "ctrl+alt+shift+left"),
    ("UndoLastMove", "alt+cmd+z"),
    ("RedoLastMove", "alt+shift+cmd+z"),
  ]

  static func shortcuts(action: Shortcut.Action?) -> [Shortcut] {
    keyBindings.map { Shortcut(name: $0.name, keyBinding: $0.keyBinding, action: action) }
  }
}

// MARK: - Storage

protocol ShortcutStorage: AnyObject {
  /// The stored shortcuts with `action` attached, or nil if there are none (or they can't be read).
  func loadShortcuts(action: Shortcut.Action?) -> [Shortcut]?
  func store(_ shortcuts: [Shortcut])
}

/// A storage that replaces an older one; until something has been stored in it, the older
/// storage is read instead.
protocol ShortcutStorageMigrationDestination: ShortcutStorage {
  var isMigrationNeeded: Bool { get }
}

/// Stores shortcuts as JSON in ~/Library/Application Support/Spectacle/Shortcuts.json:
/// `[{"shortcut_name": "MoveToCenter", "shortcut_key_binding": "alt+cmd+c"}, …]`, with `null`
/// for a cleared shortcut.
final class JSONShortcutStorage: ShortcutStorageMigrationDestination {
  private let explicitFileURL: URL?

  /// - Parameter fileURL: The file to use (for tests); nil uses the standard location.
  init(fileURL: URL? = nil) {
    explicitFileURL = fileURL
  }

  var fileURL: URL? {
    if let explicitFileURL {
      return explicitFileURL
    }
    do {
      let directory = try FileManager.default
        .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        .appendingPathComponent("Spectacle", isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      return directory.appendingPathComponent("Shortcuts.json").resolvingSymlinksInPath()
    } catch {
      storageLog.error("Unable to locate the shortcuts file: \(error.localizedDescription, privacy: .public)")
      return nil
    }
  }

  var isMigrationNeeded: Bool {
    guard let fileURL else {
      return true
    }
    return !FileManager.default.fileExists(atPath: fileURL.path)
  }

  func loadShortcuts(action: Shortcut.Action?) -> [Shortcut]? {
    guard let fileURL, let data = try? Data(contentsOf: fileURL) else {
      return nil
    }
    guard let entries = (try? JSONSerialization.jsonObject(with: data)) as? [Any] else {
      storageLog.error("Deserializing shortcuts failed")
      return nil
    }
    return entries.compactMap { entry in
      guard let entry = entry as? [String: Any], let name = entry["shortcut_name"] as? String else {
        return nil
      }
      return Shortcut(name: name, keyBinding: entry["shortcut_key_binding"] as? String, action: action)
    }
  }

  func store(_ shortcuts: [Shortcut]) {
    guard let fileURL else {
      return
    }
    let entries: [[String: Any]] = shortcuts.compactMap { shortcut in
      guard let name = shortcut.name else {
        return nil
      }
      return ["shortcut_name": name, "shortcut_key_binding": shortcut.keyBinding ?? NSNull()]
    }
    do {
      let data = try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
      try data.write(to: fileURL, options: .atomic)
    } catch {
      storageLog.error("Unable to store shortcuts at \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }
  }
}

/// Reads shortcuts the way releases before 1.0 stored them: archived objects in user defaults,
/// one per shortcut name. Only used to migrate to `JSONShortcutStorage`.
final class UserDefaultsShortcutStorage: ShortcutStorage {
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    // Class names used for shortcuts by earlier releases.
    for legacyName in ["SpectacleShortcut", "SpectacleHotKey", "ZeroKitHotKey", "ZKHotKey"] {
      NSKeyedUnarchiver.setClass(Shortcut.self, forClassName: legacyName)
    }
  }

  func loadShortcuts(action: Shortcut.Action?) -> [Shortcut]? {
    let dictionary = Dictionary(uniqueKeysWithValues: ShortcutNames.all.compactMap { name in
      defaults.data(forKey: name).map { (name, $0) }
    })
    return Self.shortcuts(from: dictionary, action: action)
  }

  func store(_ shortcuts: [Shortcut]) {
    for shortcut in shortcuts {
      guard let name = shortcut.name,
            let data = try? NSKeyedArchiver.archivedData(withRootObject: shortcut, requiringSecureCoding: false),
            data != defaults.data(forKey: name)
      else {
        continue
      }
      defaults.set(data, forKey: name)
    }
  }

  /// Decodes archived shortcuts, skipping data that can't be decoded.
  static func shortcuts(from dictionary: [String: Data], action: Shortcut.Action?) -> [Shortcut] {
    dictionary.values.compactMap { data in
      guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else {
        return nil
      }
      // Shortcuts written by old releases use plain NSCoding, so secure coding can't be required.
      unarchiver.requiresSecureCoding = false
      defer { unarchiver.finishDecoding() }
      let shortcut = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? Shortcut
      return shortcut?.with(action: action)
    }
  }
}

/// Reads from `legacy` until `destination` has been written to; always writes to `destination`.
final class MigratingShortcutStorage: ShortcutStorage {
  private let legacy: ShortcutStorage
  private let destination: ShortcutStorageMigrationDestination

  init(legacy: ShortcutStorage, destination: ShortcutStorageMigrationDestination) {
    self.legacy = legacy
    self.destination = destination
  }

  func loadShortcuts(action: Shortcut.Action?) -> [Shortcut]? {
    destination.isMigrationNeeded ? legacy.loadShortcuts(action: action) : destination.loadShortcuts(action: action)
  }

  func store(_ shortcuts: [Shortcut]) {
    destination.store(shortcuts)
  }
}
