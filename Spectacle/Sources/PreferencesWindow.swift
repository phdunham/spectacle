import AppKit
import SwiftUI

/// The state behind the Preferences window.
@MainActor
final class PreferencesModel: ObservableObject {
  struct Row: Identifiable {
    let name: String
    /// The English label, also the localization key.
    let title: String
    var id: String { name }
  }

  /// The shortcut rows, in two columns of groups, as in earlier releases.
  static let columns: [[[Row]]] = [
    [
      [Row(name: "MoveToCenter", title: "Center:"), Row(name: "MoveToFullscreen", title: "Fullscreen:")],
      [Row(name: "MoveToLeftHalf", title: "Left Half:"), Row(name: "MoveToRightHalf", title: "Right Half:"),
       Row(name: "MoveToTopHalf", title: "Top Half:"), Row(name: "MoveToBottomHalf", title: "Bottom Half:")],
      [Row(name: "MoveToUpperLeft", title: "Upper Left:"), Row(name: "MoveToLowerLeft", title: "Lower Left:"),
       Row(name: "MoveToUpperRight", title: "Upper Right:"), Row(name: "MoveToLowerRight", title: "Lower Right:")],
    ],
    [
      [Row(name: "MoveToNextDisplay", title: "Next Display:"), Row(name: "MoveToPreviousDisplay", title: "Previous Display:")],
      [Row(name: "MoveToNextThird", title: "Next Third:"), Row(name: "MoveToPreviousThird", title: "Previous Third:")],
      [Row(name: "MakeLarger", title: "Make Larger:"), Row(name: "MakeSmaller", title: "Make Smaller:")],
      [Row(name: "UndoLastMove", title: "Undo:"), Row(name: "RedoLastMove", title: "Redo:")],
    ],
  ]

  static var allRows: [Row] { columns.flatMap { $0.flatMap { $0 } } }

  @Published private(set) var shortcuts: [String: Shortcut] = [:]
  @Published private(set) var launchesAtLogin: Bool
  @Published private(set) var showsStatusItem: Bool

  let shortcutManager: ShortcutManager
  let validation: ShortcutValidation
  private let action: Shortcut.Action
  private let defaults: UserDefaults
  private let loginItem: (get: () -> Bool, set: (Bool) -> Void)
  /// Called after any shortcut change (to update the menu).
  var onShortcutsChanged: () -> Void = {}
  /// Called when "Run Spectacle" changes between the status menu and the background.
  var onStatusItemChanged: (Bool) -> Void = { _ in }
  /// Asks before restoring the defaults.
  var confirmRestoreDefaults: () -> Bool = { Alerts.confirmRestoreDefaults() }
  /// Asks before hiding the status menu; returns whether to go ahead and whether to stop asking.
  var confirmRunningInBackground: () -> (confirmed: Bool, suppress: Bool) = { Alerts.confirmRunningInBackground() }

  init(
    shortcutManager: ShortcutManager,
    action: @escaping Shortcut.Action,
    defaults: UserDefaults = .standard,
    loginItem: (get: () -> Bool, set: (Bool) -> Void) = (get: { LoginItem.isEnabled }, set: { LoginItem.setEnabled($0) })
  ) {
    self.shortcutManager = shortcutManager
    self.validation = ShortcutValidation(shortcutManager: shortcutManager)
    self.action = action
    self.defaults = defaults
    self.loginItem = loginItem
    launchesAtLogin = loginItem.get()
    showsStatusItem = defaults.bool(forKey: Preferences.statusItemEnabled)
    reload()
  }

  func reload() {
    var shortcuts: [String: Shortcut] = [:]
    for row in Self.allRows {
      shortcuts[row.name] = shortcutManager.shortcut(named: row.name)
    }
    self.shortcuts = shortcuts
    launchesAtLogin = loginItem.get()
  }

  // MARK: - Shortcuts

  func validate(_ shortcut: Shortcut) throws {
    try validation.validate(shortcut)
  }

  func record(_ shortcut: Shortcut) {
    shortcutManager.update(shortcut.with(action: action))
    reload()
    onShortcutsChanged()
  }

  func clearShortcut(named name: String) {
    if let shortcut = shortcutManager.shortcuts.first(where: { $0.name == name }) {
      shortcutManager.clear(shortcut)
    }
    reload()
    onShortcutsChanged()
  }

  func restoreDefaults() {
    guard confirmRestoreDefaults() else {
      return
    }
    shortcutManager.update(DefaultShortcuts.shortcuts(action: action))
    reload()
    onShortcutsChanged()
  }

  // MARK: - Options

  func setLaunchesAtLogin(_ enabled: Bool) {
    loginItem.set(enabled)
    launchesAtLogin = loginItem.get()
  }

  func setShowsStatusItem(_ show: Bool) {
    guard show != showsStatusItem else {
      return
    }
    if !show && !defaults.bool(forKey: Preferences.backgroundAlertSuppressed) {
      let answer = confirmRunningInBackground()
      defaults.set(answer.suppress, forKey: Preferences.backgroundAlertSuppressed)
      guard answer.confirmed else {
        // Republish so the picker snaps back.
        showsStatusItem = true
        return
      }
    }
    showsStatusItem = show
    defaults.set(show, forKey: Preferences.statusItemEnabled)
    onStatusItemChanged(show)
  }
}

/// Hosts a `ShortcutRecorder` in SwiftUI.
struct ShortcutRecorderField: NSViewRepresentable {
  let name: String
  @ObservedObject var model: PreferencesModel

  func makeNSView(context: Context) -> ShortcutRecorder {
    let recorder = ShortcutRecorder(frame: NSRect(x: 0, y: 0, width: 160, height: 19))
    recorder.shortcutName = name
    recorder.shortcut = model.shortcuts[name]
    recorder.validate = { [model] shortcut in try model.validate(shortcut) }
    recorder.onNewShortcut = { [model] shortcut in model.record(shortcut) }
    recorder.onClearShortcut = { [model, name] _ in model.clearShortcut(named: name) }
    recorder.setAccessibilityLabel(name)
    return recorder
  }

  func updateNSView(_ recorder: ShortcutRecorder, context: Context) {
    let shortcut = model.shortcuts[name]
    if recorder.shortcut != shortcut || recorder.shortcut?.keyBinding != shortcut?.keyBinding {
      recorder.shortcut = shortcut
    }
  }
}

/// The Preferences window's content.
struct PreferencesView: View {
  @ObservedObject var model: PreferencesModel

  static let width: CGFloat = 616

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 20) {
        ForEach(PreferencesModel.columns.indices, id: \.self) { index in
          column(PreferencesModel.columns[index])
        }
      }
      .padding(.top, 22)
      .padding(.horizontal, 20)

      HStack {
        Toggle("Launch Spectacle at login", isOn: Binding(
          get: { model.launchesAtLogin },
          set: { model.setLaunchesAtLogin($0) }))
          .toggleStyle(.checkbox)
        Spacer()
        Button("Restore Defaults...") { model.restoreDefaults() }
      }
      .padding(.horizontal, 20)
      .padding(.top, 22)

      HStack(spacing: 6) {
        Text("Run Spectacle")
        Picker("Run Spectacle", selection: Binding(
          get: { model.showsStatusItem },
          set: { model.setShowsStatusItem($0) })) {
          Text("in the status menu").tag(true)
          Text("as a background application").tag(false)
        }
        .labelsHidden()
        .fixedSize()
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 10)
      .padding(.bottom, 16)

      Divider()
      ModifierLegend()
        .padding(.vertical, 14)
    }
    .frame(width: Self.width)
  }

  private func column(_ groups: [[PreferencesModel.Row]]) -> some View {
    VStack(alignment: .trailing, spacing: 18) {
      ForEach(groups.indices, id: \.self) { index in
        VStack(alignment: .trailing, spacing: 10) {
          ForEach(groups[index]) { row in
            HStack(spacing: 8) {
              Text(LocalizedStringKey(row.title))
                .frame(width: 112, alignment: .trailing)
              ShortcutRecorderField(name: row.name, model: model)
                .frame(width: 160, height: 19)
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
  }
}

/// The ⌃ ⌥ ⇧ ⌘ legend at the bottom of Preferences.
struct ModifierLegend: View {
  static let modifiers = [("⌃", "Control"), ("⌥", "Option"), ("⇧", "Shift"), ("⌘", "Command")]

  var body: some View {
    HStack(spacing: 34) {
      ForEach(Self.modifiers, id: \.0) { glyph, name in
        VStack(spacing: 2) {
          Text(glyph).font(.system(size: 20))
          Text(LocalizedStringKey(name)).font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
      }
    }
  }
}

/// The Preferences window.
@MainActor
final class PreferencesWindowController {
  let model: PreferencesModel
  private var window: NSWindow?

  init(model: PreferencesModel) {
    self.model = model
  }

  func show() {
    model.reload()
    if window == nil {
      let window = NSWindow(contentViewController: NSHostingController(rootView: PreferencesView(model: model)))
      window.styleMask = [.titled, .closable, .miniaturizable]
      window.title = "Spectacle \(AppInfo.version)"
      window.isReleasedWhenClosed = false
      window.center()
      self.window = window
    }
    NSApp.activate()
    window?.makeKeyAndOrderFront(nil)
  }
}
