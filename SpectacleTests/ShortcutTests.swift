import AppKit
import Carbon.HIToolbox
import Foundation
import Testing

@testable import Spectacle

// MARK: - Shortcut

@MainActor
@Suite("Shortcut")
struct ShortcutModelTests {
  @Test("Created from a key binding")
  func fromKeyBinding() {
    let shortcut = Shortcut(name: "MoveToCenter", keyBinding: "option+command+c")
    #expect(shortcut.keyCode == kVK_ANSI_C)
    #expect(shortcut.modifiers == carbonOption | carbonCommand)
    #expect(shortcut.keyBinding == "alt+cmd+c")
  }

  @Test("Cocoa modifiers are stored as Carbon modifiers")
  func cocoaModifiers() {
    let shortcut = Shortcut(name: "MoveToCenter", keyCode: kVK_ANSI_C, modifiers: cocoaOption | cocoaCommand)
    #expect(shortcut.modifiers == carbonOption | carbonCommand)
    #expect(shortcut.displayString == "⌥⌘C")
  }

  @Test("Copied with a new action, which runs when triggered")
  func action() {
    var triggered: Shortcut?
    let plain = Shortcut(name: "MoveToCenter", keyBinding: "alt+cmd+c")
    #expect(plain.action == nil)
    let withAction = plain.with { triggered = $0 }
    #expect(withAction.action != nil)
    #expect(withAction == plain)
    withAction.trigger()
    #expect(triggered === withAction)
    plain.trigger() // no action: nothing happens
  }

  @Test("Cleared shortcuts")
  func cleared() {
    let shortcuts = [
      Shortcut(name: nil, keyBinding: nil),
      Shortcut(name: nil, keyBinding: ""),
      Shortcut(name: nil, keyCode: -1, modifiers: 0),
      Shortcut(name: "MoveToCenter", keyCode: -1, modifiers: 0),
      Shortcut(name: "MoveToCenter", keyCode: 0, modifiers: 0),
    ]
    for shortcut in shortcuts {
      #expect(shortcut.isCleared, "\(shortcut)")
      #expect(shortcut.keyBinding == nil, "\(shortcut)")
    }
  }

  @Test("⌘A (key code 0) is not cleared")
  func keyCodeZero() {
    #expect(!Shortcut(name: nil, keyBinding: "cmd+a").isCleared)
  }

  @Test("Equal when key and modifiers match, whatever the name")
  func equality() {
    let a = Shortcut(name: "MoveToCenter", keyCode: kVK_ANSI_C, modifiers: cocoaOption | cocoaCommand)
    let b = Shortcut(name: "MoveToCenter", keyCode: kVK_ANSI_C, modifiers: cocoaOption | cocoaCommand)
    let c = Shortcut(name: nil, keyCode: kVK_ANSI_C, modifiers: cocoaOption | cocoaCommand)
    #expect(a == b)
    #expect(a == c)
    #expect(a.hash == c.hash)
    #expect(a != Shortcut(name: nil, keyCode: -1, modifiers: 0))
    #expect(!a.isEqual("not a shortcut"))
  }

  @Test("containsModifiers requires the exact modifier set")
  func containsModifiers() {
    // Used to detect clashes with system shortcuts: ⌥⌘Space does not clash with ⌘Space.
    let shortcut = Shortcut(name: "MoveToCenter", keyCode: kVK_ANSI_C, modifiers: cocoaOption | cocoaCommand)
    #expect(shortcut.contains(modifiers: cocoaOption | cocoaCommand))
    #expect(shortcut.contains(modifiers: carbonOption | carbonCommand))
    #expect(!shortcut.contains(modifiers: cocoaOption))
    #expect(!shortcut.contains(modifiers: cocoaControl))
    #expect(!shortcut.contains(modifiers: cocoaOption | cocoaCommand | cocoaShift))
  }

  @Test("Valid Cocoa modifiers")
  func validCocoaModifiers() {
    #expect(Shortcut.isValidCocoaModifiers(cocoaCommand))
    #expect(Shortcut.isValidCocoaModifiers(cocoaShift | cocoaOption))
    #expect(!Shortcut.isValidCocoaModifiers(0))
    #expect(!Shortcut.isValidCocoaModifiers(carbonCommand))
    #expect(!Shortcut.isValidCocoaModifiers(NSEvent.ModifierFlags.function.rawValue))
  }

  @Test("Each shortcut name maps to its window action")
  func windowActions() {
    #expect(Shortcut(name: "MoveToLeftHalf", keyBinding: nil).windowAction == .leftHalf)
    #expect(Shortcut(name: "UndoLastMove", keyBinding: nil).windowAction == .undo)
    #expect(Shortcut(name: "Unknown", keyBinding: nil).windowAction == .none)
    #expect(Shortcut(name: nil, keyBinding: nil).windowAction == .none)
    #expect(Set(Shortcut.windowActions.keys) == Set(ShortcutNames.all))
  }
}

// MARK: - Defaults

@MainActor
@Suite("Default shortcuts")
struct DefaultShortcutTests {
  var defaults: [String: Shortcut] {
    Dictionary(uniqueKeysWithValues: DefaultShortcuts.shortcuts(action: { _ in }).map { ($0.name!, $0) })
  }

  @Test("There is a default for every action, in the documented order")
  func everyAction() {
    #expect(DefaultShortcuts.keyBindings.map(\.name) == ShortcutNames.all)
    for (name, shortcut) in defaults {
      #expect(!shortcut.isCleared, "\(name)")
      #expect(shortcut.action != nil, "\(name)")
      #expect(shortcut.windowAction != .none, "\(name)")
    }
  }

  @Test("The documented default key combinations")
  func documented() {
    #expect(defaults["MoveToFullscreen"]?.displayString == "⌥⌘F")
    #expect(defaults["MoveToLeftHalf"]?.displayString == "⌥⌘←")
    #expect(defaults["MoveToRightHalf"]?.displayString == "⌥⌘→")
    #expect(defaults["MoveToCenter"]?.keyBinding == "alt+cmd+c")
    #expect(defaults["RedoLastMove"]?.keyBinding == "alt+shift+cmd+z")
  }

  @Test("No two defaults share a key combination")
  func unique() {
    let shortcuts = Array(defaults.values)
    #expect(Set(shortcuts).count == shortcuts.count)
  }
}

// MARK: - Storage

/// A storage kept in memory.
final class MemoryShortcutStorage: ShortcutStorageMigrationDestination, @unchecked Sendable {
  var stored: [Shortcut]?
  var isMigrationNeeded = false
  var storeCount = 0

  func loadShortcuts(action: Shortcut.Action?) -> [Shortcut]? {
    stored?.map { $0.with(action: action) }
  }

  func store(_ shortcuts: [Shortcut]) {
    stored = shortcuts
    storeCount += 1
  }
}

@MainActor
@Suite("Shortcut storage")
struct ShortcutStorageTests {
  let directory: URL
  var fileURL: URL { directory.appendingPathComponent("Shortcuts.json") }

  init() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  @Test("JSON storage needs migration until something is stored")
  func migrationNeeded() {
    let storage = JSONShortcutStorage(fileURL: fileURL)
    #expect(storage.isMigrationNeeded)
    #expect(storage.loadShortcuts(action: nil) == nil)
    storage.store(DefaultShortcuts.shortcuts(action: nil))
    #expect(!storage.isMigrationNeeded)
  }

  @Test("JSON storage round-trips shortcuts, including cleared ones")
  func roundTrip() throws {
    let storage = JSONShortcutStorage(fileURL: fileURL)
    storage.store([
      Shortcut(name: "MoveToLeftHalf", keyBinding: "alt+cmd+left"),
      Shortcut(name: "MoveToFullscreen", keyBinding: "ctrl+alt+shift+cmd+f"),
      Shortcut(name: "MoveToCenter", keyBinding: nil),
    ])
    var triggered = 0
    let loaded = try #require(storage.loadShortcuts { _ in triggered += 1 })
    let byName = Dictionary(uniqueKeysWithValues: loaded.map { ($0.name!, $0) })
    #expect(loaded.count == 3)
    #expect(byName["MoveToLeftHalf"]?.keyBinding == "alt+cmd+left")
    #expect(byName["MoveToLeftHalf"]?.keyCode == kVK_LeftArrow)
    #expect(byName["MoveToFullscreen"]?.keyBinding == "ctrl+alt+shift+cmd+f")
    #expect(byName["MoveToCenter"]?.isCleared == true)
    byName["MoveToLeftHalf"]?.trigger()
    #expect(triggered == 1)
  }

  @Test("JSON storage writes the documented format")
  func format() throws {
    JSONShortcutStorage(fileURL: fileURL).store([
      Shortcut(name: "MoveToCenter", keyBinding: "alt+cmd+c"),
      Shortcut(name: "MoveToFullscreen", keyBinding: nil),
    ])
    let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [[String: Any]])
    #expect(json.count == 2)
    #expect(json[0]["shortcut_name"] as? String == "MoveToCenter")
    #expect(json[0]["shortcut_key_binding"] as? String == "alt+cmd+c")
    #expect(json[1]["shortcut_key_binding"] is NSNull)
  }

  @Test("JSON storage ignores corrupt files and entries")
  func corrupt() throws {
    let storage = JSONShortcutStorage(fileURL: fileURL)
    try "not json".write(to: fileURL, atomically: true, encoding: .utf8)
    #expect(storage.loadShortcuts(action: nil) == nil)
    try #"{"shortcut_name": "MoveToCenter"}"#.write(to: fileURL, atomically: true, encoding: .utf8)
    #expect(storage.loadShortcuts(action: nil) == nil, "the top level must be an array")
    try #"[1, {"shortcut_name": 5}, {"shortcut_name": "MoveToCenter", "shortcut_key_binding": "alt+cmd+c"}]"#
      .write(to: fileURL, atomically: true, encoding: .utf8)
    #expect(storage.loadShortcuts(action: nil)?.count == 1)
  }

  @Test("Shortcuts without a name aren't stored")
  func unnamed() {
    let storage = JSONShortcutStorage(fileURL: fileURL)
    storage.store([Shortcut(name: nil, keyBinding: "alt+cmd+c")])
    #expect(storage.loadShortcuts(action: nil)?.isEmpty == true)
  }

  @Test("The default JSON location is Application Support/Spectacle")
  func defaultLocation() {
    #expect(JSONShortcutStorage().fileURL?.path.hasSuffix("Application Support/Spectacle/Shortcuts.json") == true)
  }

  @Test("The migrating storage reads the old storage until migrated, and only writes the new one")
  func migrating() {
    let legacy = MemoryShortcutStorage()
    legacy.stored = [Shortcut(name: "MoveToCenter", keyBinding: "alt+cmd+c")]
    let destination = MemoryShortcutStorage()
    destination.isMigrationNeeded = true
    let storage = MigratingShortcutStorage(legacy: legacy, destination: destination)
    #expect(storage.loadShortcuts(action: nil)?.first?.keyBinding == "alt+cmd+c")
    storage.store([Shortcut(name: "MoveToCenter", keyBinding: "ctrl+cmd+c")])
    #expect(destination.storeCount == 1)
    #expect(legacy.storeCount == 0)
    destination.isMigrationNeeded = false
    #expect(storage.loadShortcuts(action: nil)?.first?.keyBinding == "ctrl+cmd+c")
  }

  @Test("Shortcuts archived by old releases can still be read")
  func legacyArchives() throws {
    _ = UserDefaultsShortcutStorage(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    let shortcut = Shortcut(name: "MoveToLeftHalf", keyBinding: "alt+cmd+left")
    let data = try NSKeyedArchiver.archivedData(withRootObject: shortcut, requiringSecureCoding: false)
    let decoded = UserDefaultsShortcutStorage.shortcuts(
      from: ["MoveToLeftHalf": data, "Garbage": Data("nope".utf8)], action: nil)
    #expect(decoded.count == 1, "undecodable data is skipped")
    #expect(decoded.first == shortcut)
    #expect(decoded.first?.name == "MoveToLeftHalf")
  }

  @Test("The user defaults storage round-trips through its own defaults")
  func userDefaults() throws {
    let suite = UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let storage = UserDefaultsShortcutStorage(defaults: defaults)
    storage.store([Shortcut(name: "MoveToLeftHalf", keyBinding: "alt+cmd+left"), Shortcut(name: nil, keyBinding: "cmd+a")])
    let loaded = storage.loadShortcuts(action: nil)
    #expect(loaded?.count == 1)
    #expect(loaded?.first?.keyBinding == "alt+cmd+left")
  }
}

// MARK: - Hot keys

// These register real (deliberately obscure) global hot keys for a moment, because the bug they
// guard against was in the interaction with RegisterEventHotKey/UnregisterEventHotKey.
@MainActor
@Suite("Shortcut manager")
struct ShortcutManagerTests {
  let storage = MemoryShortcutStorage()
  let manager: ShortcutManager

  init() {
    manager = ShortcutManager(storage: storage)
  }

  func shortcut(_ name: String, _ binding: String) -> Shortcut {
    Shortcut(name: name, keyBinding: binding) { _ in }
  }

  @Test("Managed shortcuts can be looked up and are stored")
  func manage() {
    manager.manage([shortcut("MoveToCenter", "ctrl+alt+shift+cmd+f19"), shortcut("MoveToFullscreen", "ctrl+alt+shift+cmd+f18")])
    #expect(manager.shortcut(named: "MoveToCenter")?.keyBinding == "ctrl+alt+shift+cmd+f19")
    #expect(storage.stored?.count == 2)
    #expect(manager.shortcuts.count == 2)
    manager.unregisterShortcuts()
  }

  @Test("Managing the same name twice keeps the first")
  func manageTwice() {
    manager.manage([shortcut("MoveToCenter", "ctrl+alt+shift+cmd+f19")])
    manager.manage([shortcut("MoveToCenter", "ctrl+alt+shift+cmd+f17")])
    #expect(manager.shortcut(named: "MoveToCenter")?.keyBinding == "ctrl+alt+shift+cmd+f19")
    manager.unregisterShortcuts()
  }

  @Test("Updating a shortcut while enabled takes effect (regression)")
  func updateEnabled() {
    // Spectacle 1.2 bailed out after successfully unregistering the old hot key, so changed
    // shortcuts and "Restore Defaults" silently stopped working.
    manager.manage([shortcut("MoveToLeftHalf", "ctrl+alt+shift+cmd+f19")])
    #expect(manager.areShortcutsEnabled)
    manager.update(Shortcut(name: "MoveToLeftHalf", keyBinding: "ctrl+alt+shift+cmd+f18"))
    let updated = manager.shortcut(named: "MoveToLeftHalf")
    #expect(updated?.keyBinding == "ctrl+alt+shift+cmd+f18")
    #expect(updated?.action != nil, "the existing action is kept")
    #expect(storage.stored?.first?.keyBinding == "ctrl+alt+shift+cmd+f18")
    manager.unregisterShortcuts()
  }

  @Test("Updating while disabled, then re-enabling")
  func updateDisabled() {
    manager.unregisterShortcuts()
    manager.manage([shortcut("MoveToLeftHalf", "ctrl+alt+shift+cmd+f19")])
    manager.update(shortcut("MoveToLeftHalf", "ctrl+alt+shift+cmd+f17"))
    #expect(manager.shortcut(named: "MoveToLeftHalf")?.keyBinding == "ctrl+alt+shift+cmd+f17")
    manager.registerShortcuts()
    #expect(manager.areShortcutsEnabled)
    #expect(manager.shortcut(named: "MoveToLeftHalf")?.keyBinding == "ctrl+alt+shift+cmd+f17")
    manager.unregisterShortcuts()
  }

  @Test("Updating or clearing an unknown shortcut does nothing")
  func unknown() {
    manager.update(shortcut("MoveToLeftHalf", "ctrl+alt+shift+cmd+f19"))
    manager.clear(shortcut("MoveToLeftHalf", "ctrl+alt+shift+cmd+f19"))
    #expect(manager.shortcut(named: "MoveToLeftHalf") == nil)
    #expect(storage.storeCount == 0)
  }

  @Test("Clearing and re-recording a shortcut keeps its action")
  func clear() {
    manager.manage([shortcut("MoveToLeftHalf", "ctrl+alt+shift+cmd+f19")])
    manager.clear(manager.shortcut(named: "MoveToLeftHalf")!)
    #expect(manager.shortcut(named: "MoveToLeftHalf") == nil)
    #expect(storage.stored?.first?.isCleared == true)
    manager.update(Shortcut(name: "MoveToLeftHalf", keyBinding: "ctrl+alt+shift+cmd+f16"))
    #expect(manager.shortcut(named: "MoveToLeftHalf")?.keyBinding == "ctrl+alt+shift+cmd+f16")
    #expect(manager.shortcut(named: "MoveToLeftHalf")?.action != nil)
    manager.unregisterShortcuts()
  }

  @Test("Disabling and enabling are idempotent")
  func idempotent() {
    manager.manage([shortcut("MoveToLeftHalf", "ctrl+alt+shift+cmd+f19")])
    manager.unregisterShortcuts()
    manager.unregisterShortcuts()
    #expect(!manager.areShortcutsEnabled)
    manager.registerShortcuts()
    manager.registerShortcuts()
    #expect(manager.areShortcutsEnabled)
    #expect(manager.shortcut(named: "MoveToLeftHalf")?.keyBinding == "ctrl+alt+shift+cmd+f19")
    manager.unregisterShortcuts()
  }

  @Test("A key combination already taken by the system can't be registered")
  func unavailable() {
    // Registering the same combination twice fails the second time; the shortcut ends up cleared.
    let other = ShortcutManager(storage: nil)
    other.manage([shortcut("MoveToCenter", "ctrl+alt+shift+cmd+f15")])
    manager.manage([shortcut("MoveToFullscreen", "ctrl+alt+shift+cmd+f15")])
    #expect(other.shortcut(named: "MoveToCenter") != nil)
    #expect(manager.shortcut(named: "MoveToFullscreen") == nil)
    other.unregisterShortcuts()
    manager.unregisterShortcuts()
  }
}

// MARK: - Validation

@MainActor
@Suite("Shortcut validation")
struct ShortcutValidationTests {
  let manager = ShortcutManager(storage: nil)

  @Test("Shortcuts already used by Spectacle are rejected")
  func registered() {
    manager.unregisterShortcuts()
    manager.manage([Shortcut(name: "MoveToLeftHalf", keyBinding: "ctrl+alt+shift+cmd+f19")])
    let validator = RegisteredShortcutValidator()
    #expect(!validator.isValid(Shortcut(name: "MoveToRightHalf", keyBinding: "ctrl+alt+shift+cmd+f19"), shortcutManager: manager))
    #expect(validator.isValid(Shortcut(name: "MoveToRightHalf", keyBinding: "ctrl+alt+shift+cmd+f15"), shortcutManager: manager))

    let validation = ShortcutValidation(shortcutManager: manager)
    #expect(throws: ShortcutValidation.ValidationError.self) {
      try validation.validate(Shortcut(name: "MoveToRightHalf", keyBinding: "ctrl+alt+shift+cmd+f19"), systemShortcuts: [])
    }
    #expect(throws: Never.self) {
      try validation.validate(Shortcut(name: "MoveToRightHalf", keyBinding: "ctrl+alt+shift+cmd+f15"), systemShortcuts: [])
    }
  }

  @Test("System-wide shortcuts are rejected only with exactly the same modifiers")
  func system() throws {
    manager.unregisterShortcuts()
    let validation = ShortcutValidation(shortcutManager: manager)
    let spotlight = [(keyCode: kVK_Space, modifiers: carbonCommand)]
    do {
      try validation.validate(Shortcut(name: "MoveToCenter", keyBinding: "cmd+space"), systemShortcuts: spotlight)
      Issue.record("⌘Space should be rejected")
    } catch let error as ShortcutValidation.ValidationError {
      #expect(error.errorDescription?.contains("⌘␣") == true)
      #expect(error.recoverySuggestion?.isEmpty == false)
    }
    try validation.validate(Shortcut(name: "MoveToCenter", keyBinding: "alt+cmd+space"), systemShortcuts: spotlight)
  }

  @Test("The enabled system shortcuts can be read")
  func readSystemShortcuts() {
    for shortcut in ShortcutValidation.enabledSystemShortcuts() {
      #expect(shortcut.keyCode >= 0)
    }
  }
}
