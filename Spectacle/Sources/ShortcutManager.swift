import Carbon.HIToolbox
import Foundation
import os

/// Registers Spectacle's shortcuts as global hot keys (Carbon `RegisterEventHotKey`, still the
/// way to get system-wide shortcuts without extra permissions) and runs their actions.
///
/// Every change is written to the shortcut storage.
@MainActor
final class ShortcutManager {
  private struct Registration {
    let id: UInt32
    var shortcut: Shortcut
    var hotKey: EventHotKeyRef?
  }

  private static let log = Logger(subsystem: "com.divisiblebyzero.Spectacle", category: "Shortcuts")
  /// 'ZERO', the hot key signature Spectacle has always used.
  private static let signature: OSType = 0x5A45_524F
  private static var lastID: UInt32 = 0

  private let storage: ShortcutStorage?
  private var registrations: [String: Registration] = [:]
  private var eventHandler: EventHandlerRef?
  private(set) var areShortcutsEnabled = true

  init(storage: ShortcutStorage?) {
    self.storage = storage
    installEventHandler()
  }

  isolated deinit {
    for registration in registrations.values {
      if let hotKey = registration.hotKey {
        UnregisterEventHotKey(hotKey)
      }
    }
    if let eventHandler {
      RemoveEventHandler(eventHandler)
    }
  }

  // MARK: - Managing shortcuts

  /// Adds shortcuts (and registers them if shortcuts are enabled). A name that is already
  /// managed keeps its existing shortcut.
  func manage(_ shortcuts: [Shortcut]) {
    for shortcut in shortcuts {
      guard let name = shortcut.name else {
        continue
      }
      guard registrations[name] == nil else {
        Self.log.notice("Unable to add shortcut \(name, privacy: .public) as it already exists.")
        continue
      }
      Self.lastID += 1
      var registration = Registration(id: Self.lastID, shortcut: shortcut, hotKey: nil)
      if areShortcutsEnabled {
        register(&registration)
      }
      registrations[name] = registration
    }
    store()
  }

  /// Replaces the key combination of a managed shortcut, keeping its action if the new one has
  /// none.
  func update(_ shortcut: Shortcut) {
    guard let name = shortcut.name, var registration = registrations[name] else {
      Self.log.notice("Unable to update shortcut \(shortcut.name ?? "-", privacy: .public) as it does not exist.")
      return
    }
    if areShortcutsEnabled && !unregister(&registration) {
      Self.log.error("Unable to unregister event hot key for shortcut: \(name, privacy: .public)")
      return
    }
    registration.shortcut = shortcut.with(action: shortcut.action ?? registration.shortcut.action)
    if areShortcutsEnabled {
      register(&registration)
    }
    registrations[name] = registration
    store()
  }

  func update(_ shortcuts: [Shortcut]) {
    for shortcut in shortcuts {
      update(shortcut)
    }
  }

  /// Removes the key combination of a managed shortcut (the name stays, as a cleared shortcut).
  func clear(_ shortcut: Shortcut) {
    guard let name = shortcut.name, var registration = registrations[name] else {
      Self.log.notice("Unable to clear shortcut \(shortcut.name ?? "-", privacy: .public) as it does not exist.")
      return
    }
    if areShortcutsEnabled && !unregister(&registration) {
      return
    }
    registration.shortcut = Shortcut(name: name, keyCode: -1, modifiers: 0, action: registration.shortcut.action)
    registrations[name] = registration
    store()
  }

  var shortcuts: [Shortcut] {
    registrations.values.map(\.shortcut)
  }

  /// The managed shortcut with this name, or nil if there is none or it is cleared.
  func shortcut(named name: String) -> Shortcut? {
    guard let shortcut = registrations[name]?.shortcut, !shortcut.isCleared else {
      return nil
    }
    return shortcut
  }

  /// Whether any managed shortcut uses the same key combination.
  func contains(_ shortcut: Shortcut) -> Bool {
    registrations.values.contains { $0.shortcut == shortcut }
  }

  // MARK: - Enabling and disabling

  func registerShortcuts() {
    guard !areShortcutsEnabled else {
      return
    }
    for name in registrations.keys {
      register(&registrations[name]!)
    }
    areShortcutsEnabled = true
  }

  func unregisterShortcuts() {
    guard areShortcutsEnabled else {
      return
    }
    for name in registrations.keys {
      _ = unregister(&registrations[name]!)
    }
    areShortcutsEnabled = false
  }

  // MARK: - Hot keys

  private func register(_ registration: inout Registration) {
    let shortcut = registration.shortcut
    guard !shortcut.isCleared else {
      return
    }
    var hotKey: EventHotKeyRef?
    let status = RegisterEventHotKey(
      UInt32(truncatingIfNeeded: shortcut.keyCode),
      UInt32(truncatingIfNeeded: shortcut.modifiers),
      EventHotKeyID(signature: Self.signature, id: registration.id),
      GetEventDispatcherTarget(),
      OptionBits(kEventHotKeyNoOptions),
      &hotKey)
    if status == noErr {
      registration.hotKey = hotKey
    } else {
      Self.log.error("There was a problem registering shortcut \(shortcut.name ?? "-", privacy: .public): \(status)")
      registration.shortcut = Shortcut(name: shortcut.name, keyCode: -1, modifiers: 0, action: shortcut.action)
      registration.hotKey = nil
    }
  }

  /// Returns false if the hot key could not be unregistered.
  private func unregister(_ registration: inout Registration) -> Bool {
    guard let hotKey = registration.hotKey else {
      return true
    }
    let status = UnregisterEventHotKey(hotKey)
    guard status == noErr else {
      let name = registration.shortcut.name ?? "-"
      Self.log.error("Error \(status) unregistering shortcut \(name, privacy: .public)")
      return false
    }
    registration.hotKey = nil
    return true
  }

  private func store() {
    storage?.store(shortcuts)
  }

  private func installEventHandler() {
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(
      GetApplicationEventTarget(),
      shortcutManagerHotKeyHandler,
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      &eventHandler)
  }

  fileprivate func handleHotKey(id: EventHotKeyID) {
    guard id.signature == Self.signature,
          let registration = registrations.values.first(where: { $0.id == id.id })
    else {
      return
    }
    registration.shortcut.trigger()
  }
}

/// Carbon calls this on the main thread for each hot key press.
private let shortcutManagerHotKeyHandler: EventHandlerUPP = { _, event, userData in
  guard let event, let userData else {
    return OSStatus(eventNotHandledErr)
  }
  var hotKeyID = EventHotKeyID()
  let status = GetEventParameter(
    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
    MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
  guard status == noErr else {
    return status
  }
  let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
  MainActor.assumeIsolated {
    manager.handleHotKey(id: hotKeyID)
  }
  return noErr
}
