import AppKit
import ApplicationServices

/// When shortcuts are active: not while disabled for an hour, and not while a blacklisted
/// application (e.g. Photoshop, which uses the same keys) or one the person disabled them for is
/// frontmost.
struct ShortcutActivationRules {
  var blacklisted: Set<String>
  var disabled: Set<String>
  var disabledForAnHour = false

  func shortcutsEnabled(frontmostBundleIdentifier: String?) -> Bool {
    guard !disabledForAnHour else {
      return false
    }
    guard let frontmostBundleIdentifier else {
      return true
    }
    return !blacklisted.contains(frontmostBundleIdentifier) && !disabled.contains(frontmostBundleIdentifier)
  }
}

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  /// NSApplication only keeps a weak reference to its delegate.
  private static var shared: AppDelegate?

  static func main() {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    shared = delegate
    application.delegate = delegate
    application.run()
  }

  private let defaults = UserDefaults.standard
  private var rules = ShortcutActivationRules(blacklisted: [], disabled: [])
  private var disableTimer: Timer?
  private var shortcutManager: ShortcutManager!
  private var windowPositionManager: WindowPositionManager!
  private var preferences: PreferencesWindowController!
  private let statusMenu = StatusMenu()
  private let permissionWindow = AccessibilityPermissionWindowController()

  func applicationDidFinishLaunching(_ notification: Notification) {
    // When hosting the unit tests, don't register hot keys, add a status item or show dialogs.
    guard !AppInfo.isRunningTests else {
      return
    }
    Preferences.registerDefaults()
    NSApp.mainMenu = Self.makeMainMenu()
    rules.blacklisted = Set(defaults.stringArray(forKey: Preferences.blacklistedApplications) ?? [])
    rules.disabled = Set(defaults.stringArray(forKey: Preferences.disabledApplications) ?? [])

    windowPositionManager = WindowPositionManager()
    let storage = MigratingShortcutStorage(legacy: UserDefaultsShortcutStorage(), destination: JSONShortcutStorage())
    shortcutManager = ShortcutManager(storage: storage)
    let action: Shortcut.Action = { [weak self] shortcut in
      self?.windowPositionManager.perform(shortcut.windowAction)
    }
    let shortcuts = storage.loadShortcuts(action: action) ?? []
    shortcutManager.manage(shortcuts.isEmpty ? DefaultShortcuts.shortcuts(action: action) : shortcuts)

    let model = PreferencesModel(shortcutManager: shortcutManager, action: action)
    model.onShortcutsChanged = { [weak self] in self?.updateMenuShortcuts() }
    model.onStatusItemChanged = { [weak self] visible in self?.statusMenu.setStatusItemVisible(visible) }
    preferences = PreferencesWindowController(model: model)

    configureStatusMenu()
    statusMenu.setStatusItemVisible(defaults.bool(forKey: Preferences.statusItemEnabled))
    updateMenuShortcuts()
    updateShortcutActivation()

    let workspaceCenter = NSWorkspace.shared.notificationCenter
    workspaceCenter.addObserver(self, selector: #selector(frontmostApplicationChanged), name: NSWorkspace.didActivateApplicationNotification, object: nil)
    workspaceCenter.addObserver(self, selector: #selector(frontmostApplicationChanged), name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
    // Key symbols depend on the keyboard layout.
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardLayoutChanged), name: NSTextInputContext.keyboardSelectionDidChangeNotification, object: nil)

    let previewDialog = defaults.bool(forKey: Preferences.showAccessibilityDialog)
    if !AXIsProcessTrusted() || previewDialog {
      permissionWindow.show(keepOpen: previewDialog)
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    preferences?.show()
    return true
  }

  // MARK: - Menu

  private func configureStatusMenu() {
    statusMenu.performAction = { [weak self] action in
      // The menu was used with the mouse; act on the window that was frontmost before.
      self?.windowPositionManager.perform(action)
    }
    statusMenu.showPreferences = { [weak self] in self?.preferences.show() }
    statusMenu.toggleDisabledForAnHour = { [weak self] in self?.toggleDisabledForAnHour() }
    statusMenu.toggleDisabledForFrontmostApplication = { [weak self] in self?.toggleDisabledForFrontmostApplication() }
    statusMenu.frontmostApplicationState = { [weak self] in
      let application = NSWorkspace.shared.frontmostApplication
      let identifier = application?.bundleIdentifier ?? ""
      return (application?.localizedName,
              self?.rules.blacklisted.contains(identifier) ?? false,
              self?.rules.disabled.contains(identifier) ?? false)
    }
  }

  private func updateMenuShortcuts() {
    statusMenu.updateKeyEquivalents { [weak self] name in self?.shortcutManager.shortcut(named: name) }
  }

  /// A minimal main menu so ⌘W and ⌘Q work in Spectacle's own windows.
  private static func makeMainMenu() -> NSMenu {
    let mainMenu = NSMenu()
    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: NSLocalizedString("Quit Spectacle", comment: "Menu item"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appItem.submenu = appMenu
    mainMenu.addItem(appItem)
    let windowItem = NSMenuItem()
    let windowMenu = NSMenu(title: "Window")
    windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    windowItem.submenu = windowMenu
    mainMenu.addItem(windowItem)
    return mainMenu
  }

  // MARK: - Enabling and disabling shortcuts

  private func updateShortcutActivation() {
    if rules.shortcutsEnabled(frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier) {
      shortcutManager.registerShortcuts()
    } else {
      shortcutManager.unregisterShortcuts()
    }
    updateMenuShortcuts()
  }

  @objc private func frontmostApplicationChanged(_ notification: Notification) {
    updateShortcutActivation()
  }

  @objc private func keyboardLayoutChanged(_ notification: Notification) {
    updateMenuShortcuts()
    preferences?.model.reload()
  }

  private func toggleDisabledForAnHour() {
    rules.disabledForAnHour.toggle()
    disableTimer?.invalidate()
    disableTimer = nil
    if rules.disabledForAnHour {
      disableTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: false) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.toggleDisabledForAnHour()
        }
      }
    }
    statusMenu.disableForAnHourItem.state = rules.disabledForAnHour ? .on : .off
    updateShortcutActivation()
  }

  private func toggleDisabledForFrontmostApplication() {
    guard let identifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
      return
    }
    if rules.disabled.contains(identifier) {
      rules.disabled.remove(identifier)
    } else {
      rules.disabled.insert(identifier)
    }
    defaults.set(Array(rules.disabled).sorted(), forKey: Preferences.disabledApplications)
    statusMenu.refreshDisableItems()
    updateShortcutActivation()
  }
}
