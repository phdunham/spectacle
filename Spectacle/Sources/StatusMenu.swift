import AppKit

/// The Spectacle menu in the menu bar.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
  /// Shortcut names and their menu titles, in groups separated by lines (the order of earlier
  /// releases).
  static let actionGroups: [[(name: String, title: String)]] = [
    [("MoveToCenter", "Center"), ("MoveToFullscreen", "Fullscreen")],
    [("MoveToLeftHalf", "Left Half"), ("MoveToRightHalf", "Right Half"), ("MoveToTopHalf", "Top Half"), ("MoveToBottomHalf", "Bottom Half")],
    [("MoveToUpperLeft", "Upper Left"), ("MoveToLowerLeft", "Lower Left"), ("MoveToUpperRight", "Upper Right"), ("MoveToLowerRight", "Lower Right")],
    [("MoveToNextDisplay", "Next Display"), ("MoveToPreviousDisplay", "Previous Display")],
    [("MoveToNextThird", "Next Third"), ("MoveToPreviousThird", "Previous Third")],
    [("MakeLarger", "Make Larger"), ("MakeSmaller", "Make Smaller")],
    [("UndoLastMove", "Undo"), ("RedoLastMove", "Redo")],
  ]

  let menu = NSMenu(title: "Spectacle")
  private(set) var statusItem: NSStatusItem?
  private var shortcutItems: [String: NSMenuItem] = [:]
  let disableForAnHourItem = NSMenuItem()
  let disableForApplicationItem = NSMenuItem()

  /// What the menu does; set by the app delegate.
  var performAction: (WindowAction) -> Void = { _ in }
  var showPreferences: () -> Void = {}
  var toggleDisabledForAnHour: () -> Void = {}
  var toggleDisabledForFrontmostApplication: () -> Void = {}
  /// The frontmost application's name, and whether it is blacklisted / disabled.
  var frontmostApplicationState: () -> (name: String?, blacklisted: Bool, disabled: Bool) = { (nil, false, false) }

  override init() {
    super.init()
    build()
  }

  private func build() {
    menu.delegate = self
    menu.addItem(item(NSLocalizedString("About Spectacle", comment: "Menu item"), #selector(showAbout)))
    menu.addItem(.separator())

    let disable = NSMenuItem(title: NSLocalizedString("Disable", comment: "Menu item"), action: nil, keyEquivalent: "")
    let disableMenu = NSMenu(title: disable.title)
    disableForAnHourItem.title = NSLocalizedString("for an hour", comment: "Menu item: disable shortcuts for an hour")
    disableForAnHourItem.action = #selector(disableForAnHour)
    disableForAnHourItem.target = self
    disableForApplicationItem.title = NSLocalizedString("for APPLICATION", comment: "Menu item placeholder")
    disableForApplicationItem.action = #selector(disableForApplication)
    disableForApplicationItem.target = self
    disableMenu.addItem(disableForAnHourItem)
    disableMenu.addItem(disableForApplicationItem)
    disable.submenu = disableMenu
    menu.addItem(disable)
    menu.addItem(.separator())

    menu.addItem(item(NSLocalizedString("Preferences...", comment: "Menu item"), #selector(openPreferences)))
    for group in Self.actionGroups {
      menu.addItem(.separator())
      for (name, title) in group {
        let item = item(NSLocalizedString(title, comment: "Menu item for a window action"), #selector(performShortcutAction(_:)))
        item.representedObject = name
        shortcutItems[name] = item
        menu.addItem(item)
      }
    }
    menu.addItem(.separator())
    menu.addItem(item(NSLocalizedString("Quit Spectacle", comment: "Menu item"), #selector(quit)))
  }

  private func item(_ title: String, _ action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
  }

  func shortcutItem(named name: String) -> NSMenuItem? {
    shortcutItems[name]
  }

  /// Shows each action's shortcut next to it.
  func updateKeyEquivalents(_ shortcutFor: (String) -> Shortcut?) {
    for (name, item) in shortcutItems {
      if let shortcut = shortcutFor(name) {
        item.keyEquivalent = KeyTranslation.string(forKeyCode: shortcut.keyCode).lowercased()
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: KeyTranslation.cocoaModifiersIfNecessary(shortcut.modifiers))
      } else {
        item.keyEquivalent = ""
        item.keyEquivalentModifierMask = []
      }
    }
  }

  // MARK: - Status item

  func setStatusItemVisible(_ visible: Bool) {
    if visible, statusItem == nil {
      let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
      let image = Bundle.main.image(forResource: "Spectacle Status Item")
      image?.isTemplate = true
      item.button?.image = image
      item.button?.toolTip = "Spectacle \(AppInfo.version)"
      item.menu = menu
      statusItem = item
    } else if !visible, let statusItem {
      NSStatusBar.system.removeStatusItem(statusItem)
      self.statusItem = nil
    }
  }

  // MARK: - NSMenuDelegate

  func menuWillOpen(_ menu: NSMenu) {
    refreshDisableItems()
  }

  func refreshDisableItems() {
    let state = frontmostApplicationState()
    disableForApplicationItem.isHidden = state.blacklisted
    disableForApplicationItem.title = String(
      format: NSLocalizedString("MenuItemTitleDisableShortcutsForApplication", comment: "The menu item title that displays the application to disable shortcuts for"),
      state.name ?? "")
    disableForApplicationItem.state = state.disabled ? .on : .off
  }

  // MARK: - Actions

  @objc private func showAbout() {
    NSApp.activate()
    NSApp.orderFrontStandardAboutPanel(nil)
  }

  @objc private func openPreferences() {
    showPreferences()
  }

  @objc private func disableForAnHour() {
    toggleDisabledForAnHour()
  }

  @objc private func disableForApplication() {
    toggleDisabledForFrontmostApplication()
  }

  @objc func performShortcutAction(_ sender: NSMenuItem) {
    guard let name = sender.representedObject as? String, let action = Shortcut.windowActions[name] else {
      return
    }
    performAction(action)
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }
}
