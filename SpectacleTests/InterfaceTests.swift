import AppKit
import Carbon.HIToolbox
import SwiftUI
import Testing

@testable import Spectacle

// Tests of Spectacle's interface: the permission dialog, the System Settings illustration, the
// shortcut recorder, Preferences and the status menu, in Light and Dark Mode where it matters.

let appearances: [NSAppearance.Name] = [.aqua, .darkAqua]

// MARK: - Permission dialog

@MainActor
@Suite("Permission dialog")
struct PermissionDialogTests {
  /// Renders the dialog (without the AppKit illustration, which ImageRenderer can't draw) over
  /// the window background.
  func render(_ appearance: NSAppearance.Name) throws -> NSBitmapImageRep {
    let scheme: ColorScheme = appearance == .darkAqua ? .dark : .light
    let view = AccessibilityPermissionView(showsIllustration: false, openSystemSettings: {}, quit: {})
      .background(Color(nsColor: resolve(.windowBackgroundColor, appearance)))
      .environment(\.colorScheme, scheme)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    let image = try #require(renderer.cgImage)
    return NSBitmapImageRep(cgImage: image)
  }

  /// The button row's vertical center and the fills along it, left to right.
  func buttonFills(_ bitmap: NSBitmapImageRep) -> [(x: Int, color: NSColor)] {
    let background = color(bitmap, 2, 2)
    // Find the row through the buttons: the first row (below the text) with long runs that
    // differ strongly from the background.
    for y in 60..<140 {
      var runs: [(x: Int, color: NSColor)] = []
      var runStart: Int?
      for x in 0..<bitmap.pixelsWide {
        let differs = contrastRatio(color(bitmap, x, y), background) > 1.4
        if differs && runStart == nil {
          runStart = x
        } else if !differs, let start = runStart {
          if x - start > 80 {
            runs.append((start + 4, color(bitmap, start + 4, y)))
          }
          runStart = nil
        }
      }
      if runs.count == 2 {
        return runs
      }
    }
    return []
  }

  @Test("Both buttons have a fill that stands out from the background", arguments: appearances)
  func buttonsStandOut(appearance: NSAppearance.Name) throws {
    let bitmap = try render(appearance)
    let background = resolve(.windowBackgroundColor, appearance)
    let fills = buttonFills(bitmap)
    #expect(fills.count == 2, "expected two filled buttons in \(appearance.rawValue)")
    for fill in fills {
      #expect(contrastRatio(fill.color, background) >= 1.5, "fill \(fill.color) in \(appearance.rawValue)")
      #expect(contrastRatio(fill.color, .white) >= 2.0, "white title on \(fill.color) in \(appearance.rawValue)")
    }
    if fills.count == 2 {
      #expect(contrastRatio(fills[0].color, fills[1].color) > 1.05, "Open and Quit should look different")
    }
  }

  @Test("The texts use readable system colors", arguments: appearances)
  func textContrast(appearance: NSAppearance.Name) {
    #expect(contrastRatio(resolve(.labelColor, appearance), resolve(.windowBackgroundColor, appearance)) >= 4.5)
  }

  @Test("The dialog has its fixed size and the illustration below the buttons")
  func layout() {
    #expect(AccessibilityPermissionView.size == CGSize(width: 780, height: 360))
    let hosting = NSHostingView(rootView: AccessibilityPermissionView(openSystemSettings: {}, quit: {}))
    hosting.frame = NSRect(origin: .zero, size: AccessibilityPermissionView.size)
    hosting.layoutSubtreeIfNeeded()
    func find(_ view: NSView) -> AccessibilitySettingsIllustration? {
      if let found = view as? AccessibilitySettingsIllustration { return found }
      for subview in view.subviews { if let found = find(subview) { return found } }
      return nil
    }
    let illustration = find(hosting)
    #expect(illustration != nil)
    if let illustration {
      let frame = illustration.convert(illustration.bounds, to: hosting)
      #expect(frame.width == 590 && frame.height == 232)
      // NSHostingView is flipped: the illustration sits in the lower part of the dialog.
      #expect(frame.minY > 90)
    }
  }

  @Test("The buttons are wired: Return opens Settings, Escape quits")
  func buttons() {
    var opened = 0
    var quit = 0
    let view = AccessibilityPermissionView(showsIllustration: false, openSystemSettings: { opened += 1 }, quit: { quit += 1 })
    view.openSystemSettings()
    view.quit()
    #expect(opened == 1 && quit == 1)
  }
}

// MARK: - Illustration

@MainActor
@Suite("System Settings illustration")
struct IllustrationTests {
  let illustration = AccessibilitySettingsIllustration(frame: NSRect(x: 0, y: 0, width: 590, height: 232))

  func render(_ appearance: NSAppearance.Name) -> NSBitmapImageRep {
    illustration.appearance = NSAppearance(named: appearance)
    let bitmap = illustration.bitmapImageRepForCachingDisplay(in: illustration.bounds)!
    illustration.cacheDisplay(in: illustration.bounds, to: bitmap)
    return bitmap
  }

  /// The view is flipped, so view points map straight onto bitmap rows (times the scale).
  func colorAt(_ bitmap: NSBitmapImageRep, _ point: NSPoint) -> NSColor {
    let scale = CGFloat(bitmap.pixelsWide) / illustration.bounds.width
    return color(bitmap, Int(point.x * scale), Int(point.y * scale))
  }

  func averageLuminance(_ bitmap: NSBitmapImageRep, _ rect: NSRect) -> CGFloat {
    var total: CGFloat = 0
    var count = 0
    for y in stride(from: rect.minY, to: rect.maxY, by: 2) {
      for x in stride(from: rect.minX, to: rect.maxX, by: 2) {
        total += relativeLuminance(colorAt(bitmap, NSPoint(x: x, y: y)))
        count += 1
      }
    }
    return count > 0 ? total / CGFloat(count) : 0
  }

  var visibleWindowArea: NSRect {
    illustration.windowRect.insetBy(dx: 20, dy: 20).intersection(illustration.bounds)
  }

  @Test("Light in Light Mode")
  func light() {
    let bitmap = render(.aqua)
    #expect(averageLuminance(bitmap, visibleWindowArea) > 0.6)
    #expect(averageLuminance(bitmap, illustration.sidebarRect.insetBy(dx: 10, dy: 70)) > 0.5)
  }

  @Test("Dark in Dark Mode")
  func dark() {
    let bitmap = render(.darkAqua)
    #expect(averageLuminance(bitmap, visibleWindowArea) < 0.12)
    #expect(averageLuminance(bitmap, illustration.sidebarRect.insetBy(dx: 10, dy: 70)) < 0.15)
  }

  @Test("The same view switches between Light and Dark")
  func switches() {
    let light = averageLuminance(render(.aqua), visibleWindowArea)
    let dark = averageLuminance(render(.darkAqua), visibleWindowArea)
    let lightAgain = averageLuminance(render(.aqua), visibleWindowArea)
    #expect(light - dark > 0.4)
    #expect(abs(light - lightAgain) < 0.001)
  }

  @Test("The selected row and the switch use the accent color", arguments: appearances)
  func accent(appearance: NSAppearance.Name) {
    let bitmap = render(appearance)
    let accent = resolve(.controlAccentColor, appearance)
    let row = illustration.selectedSidebarRowRect
    let toggle = illustration.switchRect
    for point in [NSPoint(x: row.maxX - 6, y: row.midY), NSPoint(x: toggle.minX + 5, y: toggle.midY)] {
      let c = colorAt(bitmap, point)
      #expect(abs(c.redComponent - accent.redComponent) < 0.06, "\(point)")
      #expect(abs(c.greenComponent - accent.greenComponent) < 0.06, "\(point)")
      #expect(abs(c.blueComponent - accent.blueComponent) < 0.06, "\(point)")
    }
  }

  @Test("The Spectacle row shows an icon and a name", arguments: appearances)
  func spectacleRow(appearance: NSAppearance.Name) {
    let bitmap = render(appearance)
    let row = illustration.spectacleRowRect
    let background = relativeLuminance(colorAt(bitmap, NSPoint(x: row.maxX - 80, y: row.midY)))
    var contrasting = 0
    for y in stride(from: row.minY + 8, to: row.maxY - 8, by: 1) {
      for x in stride(from: row.minX + 12, to: row.minX + 120, by: 1) where abs(relativeLuminance(colorAt(bitmap, NSPoint(x: x, y: y))) - background) > 0.25 {
        contrasting += 1
      }
    }
    #expect(contrasting > 150)
  }

  @Test("The important parts are visible and VoiceOver gets a description")
  func structure() {
    #expect(illustration.clipsToBounds)
    #expect(illustration.bounds.contains(illustration.selectedSidebarRowRect))
    #expect(illustration.bounds.contains(illustration.spectacleRowRect))
    #expect(illustration.accessibilityRole() == .image)
    #expect(illustration.accessibilityLabel()?.contains("Accessibility") == true)
  }

  @Test("Writes snapshots when SPECTACLE_SNAPSHOT_DIR is set",
        .enabled(if: ProcessInfo.processInfo.environment["SPECTACLE_SNAPSHOT_DIR"] != nil))
  func snapshots() throws {
    let directory = try #require(ProcessInfo.processInfo.environment["SPECTACLE_SNAPSHOT_DIR"])
    for appearance in appearances {
      let png = try #require(render(appearance).representation(using: .png, properties: [:]))
      try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("illustration-\(appearance.rawValue).png"))
    }
  }
}

// MARK: - Shortcut recorder

@MainActor
@Suite("Shortcut recorder")
struct ShortcutRecorderTests {
  let recorder = ShortcutRecorder(frame: NSRect(x: 0, y: 0, width: 160, height: 19))

  /// Draws the recorder into a large canvas without clipping, with the whole canvas as the
  /// dirty rect, as AppKit can on macOS 14 and later.
  func drawUnclipped(canvas: NSSize = NSSize(width: 600, height: 400), origin: NSPoint = NSPoint(x: 220, y: 190), appearance: NSAppearance.Name = .aqua) -> NSBitmapImageRep {
    let bitmap = makeBitmap(width: Int(canvas.width), height: Int(canvas.height))
    draw(into: bitmap, appearance: appearance) {
      let transform = NSAffineTransform()
      transform.translateX(by: origin.x, yBy: origin.y)
      transform.concat()
      recorder.draw(NSRect(x: -origin.x, y: -origin.y, width: canvas.width, height: canvas.height))
    }
    return bitmap
  }

  @Test("Never paints outside its bounds, even with a huge dirty rect (regression)")
  func staysInBounds() {
    recorder.shortcut = Shortcut(name: "MoveToLeftHalf", keyBinding: "alt+cmd+left")
    let bitmap = drawUnclipped()
    let rect = NSRect(x: 220, y: 400 - 190 - 19, width: 160, height: 19).insetBy(dx: -1, dy: -1)
    var inside = 0
    var outside = 0
    for y in 0..<bitmap.pixelsHigh {
      for x in 0..<bitmap.pixelsWide {
        var pixel = [Int](repeating: 0, count: 4)
        bitmap.getPixel(&pixel, atX: x, y: y)
        guard pixel[3] != 0 else { continue }
        if rect.contains(NSPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)) { inside += 1 } else { outside += 1 }
      }
    }
    #expect(inside > 160 * 19 / 2)
    #expect(outside == 0, "painted \(outside) pixels outside its bounds")
    #expect(recorder.clipsToBounds)
  }

  @Test("The label is readable on the field in both modes", arguments: appearances)
  func readable(appearance: NSAppearance.Name) {
    recorder.shortcut = Shortcut(name: "MoveToLeftHalf", keyBinding: "alt+cmd+left")
    let bitmap = drawUnclipped(canvas: NSSize(width: 160, height: 19), origin: .zero, appearance: appearance)
    var minL: CGFloat = 1
    var maxL: CGFloat = 0
    for y in 4..<15 {
      for x in 40..<120 {
        let l = relativeLuminance(color(bitmap, x, y))
        minL = min(minL, l)
        maxL = max(maxL, l)
      }
    }
    #expect((maxL + 0.05) / (minL + 0.05) >= 4.5)
  }

  @Test("Shows the shortcut, or a prompt when there is none")
  func labels() {
    recorder.shortcut = Shortcut(name: "MoveToLeftHalf", keyBinding: "alt+cmd+left")
    #expect(recorder.label == "⌥⌘←")
    recorder.shortcut = nil
    #expect(recorder.label == NSLocalizedString("ShortcutRecorderLabelClickToRecord", comment: ""))
    recorder.startRecording()
    #expect(recorder.label == NSLocalizedString("ShortcutRecorderLabelEnterShortcut", comment: ""))
    recorder.stopRecording()
  }

  @Test("Records a key with modifiers")
  func records() {
    var received: Shortcut?
    recorder.shortcutName = "MoveToLeftHalf"
    recorder.onNewShortcut = { received = $0 }
    #expect(!recorder.record(keyCode: kVK_ANSI_C, modifiers: [.option, .command]), "ignored unless recording")
    recorder.startRecording()
    #expect(recorder.isRecording)
    #expect(recorder.record(keyCode: kVK_ANSI_C, modifiers: [.option, .command]))
    #expect(!recorder.isRecording)
    #expect(received?.keyBinding == "alt+cmd+c")
    #expect(received?.name == "MoveToLeftHalf")
    #expect(recorder.shortcut == received)
  }

  @Test("Function keys work without modifiers; other keys need one")
  func functionKeys() {
    var received: [Shortcut] = []
    recorder.onNewShortcut = { received.append($0) }
    recorder.startRecording()
    #expect(!recorder.record(keyCode: kVK_ANSI_C, modifiers: []))
    #expect(recorder.isRecording)
    #expect(recorder.record(keyCode: kVK_F5, modifiers: []))
    #expect(received.map(\.keyCode) == [kVK_F5])
  }

  @Test("Escape cancels recording")
  func escape() {
    var received = 0
    recorder.onNewShortcut = { _ in received += 1 }
    recorder.startRecording()
    #expect(recorder.record(keyCode: kVK_Escape, modifiers: []))
    #expect(!recorder.isRecording)
    #expect(received == 0)
  }

  @Test("A rejected shortcut is reported and not kept")
  func rejected() {
    struct Rejected: Error {}
    var errors = 0
    var received = 0
    recorder.shortcut = Shortcut(name: "MoveToLeftHalf", keyBinding: "alt+cmd+left")
    recorder.validate = { _ in throw Rejected() }
    recorder.reportRejectedShortcut = { _ in errors += 1 }
    recorder.onNewShortcut = { _ in received += 1 }
    recorder.startRecording()
    recorder.record(keyCode: kVK_ANSI_C, modifiers: [.command])
    #expect(errors == 1)
    #expect(received == 0)
    #expect(recorder.shortcut?.keyBinding == "alt+cmd+left")
  }

  @Test("Clearing reports the old shortcut")
  func clear() {
    var cleared: Shortcut?
    let old = Shortcut(name: "MoveToLeftHalf", keyBinding: "alt+cmd+left")
    recorder.shortcut = old
    recorder.onClearShortcut = { cleared = $0 }
    recorder.clearShortcut()
    #expect(cleared == old)
    #expect(recorder.shortcut == nil)
  }

  @Test("The clear badge sits at the right end")
  func badge() {
    let badge = ShortcutRecorder.badgeRect(in: recorder.bounds)
    #expect(badge.maxX == recorder.bounds.maxX - 4)
    #expect(badge.size == NSSize(width: 13, height: 13))
    #expect(recorder.bounds.contains(badge))
  }
}

// MARK: - Preferences

@MainActor
@Suite("Preferences")
struct PreferencesTests {
  let suiteName = "SpectacleTests.\(UUID().uuidString)"
  let defaults: UserDefaults
  let manager = ShortcutManager(storage: nil)

  init() {
    defaults = UserDefaults(suiteName: suiteName)!
    defaults.set(true, forKey: Preferences.statusItemEnabled)
    manager.unregisterShortcuts() // don't register real hot keys
    manager.manage(DefaultShortcuts.shortcuts { _ in })
  }

  func model() -> PreferencesModel {
    var enabled = false
    return PreferencesModel(shortcutManager: manager, action: { _ in }, defaults: defaults,
                            loginItem: (get: { enabled }, set: { enabled = $0 }))
  }

  @Test("Lists all 18 shortcuts once, in the original two columns")
  func rows() {
    let names = PreferencesModel.allRows.map(\.name)
    #expect(names.count == 18)
    #expect(Set(names) == Set(ShortcutNames.all))
    #expect(PreferencesModel.columns.count == 2)
    #expect(PreferencesModel.columns[0].flatMap { $0 }.first?.title == "Center:")
    #expect(PreferencesModel.columns[1].flatMap { $0 }.last?.title == "Redo:")
    #expect(PreferencesModel.allRows.allSatisfy { $0.title.hasSuffix(":") })
  }

  @Test("Shows the current shortcuts")
  func loads() {
    let model = model()
    #expect(model.shortcuts["MoveToLeftHalf"]?.displayString == "⌥⌘←")
    #expect(model.shortcuts.count == 18)
  }

  @Test("Recording, clearing and restoring defaults update the shortcuts and the menu")
  func editing() {
    let model = model()
    var changes = 0
    model.onShortcutsChanged = { changes += 1 }

    model.record(Shortcut(name: "MoveToLeftHalf", keyBinding: "ctrl+alt+shift+cmd+f19"))
    #expect(model.shortcuts["MoveToLeftHalf"]?.keyBinding == "ctrl+alt+shift+cmd+f19")
    #expect(manager.shortcut(named: "MoveToLeftHalf")?.action != nil)

    model.clearShortcut(named: "MoveToLeftHalf")
    #expect(model.shortcuts["MoveToLeftHalf"] == nil)

    model.confirmRestoreDefaults = { false }
    model.restoreDefaults()
    #expect(model.shortcuts["MoveToLeftHalf"] == nil, "cancelled")

    model.confirmRestoreDefaults = { true }
    model.restoreDefaults()
    #expect(model.shortcuts["MoveToLeftHalf"]?.keyBinding == "alt+cmd+left")
    #expect(changes == 3)
  }

  @Test("New shortcuts already used by another action are rejected")
  func validation() {
    let model = model()
    #expect(throws: ShortcutValidation.ValidationError.self) {
      try model.validate(Shortcut(name: "MoveToRightHalf", keyBinding: "alt+cmd+left"))
    }
  }

  @Test("Hiding the status menu asks first, and can be cancelled")
  func statusItem() {
    let model = model()
    var visible: [Bool] = []
    model.onStatusItemChanged = { visible.append($0) }

    model.confirmRunningInBackground = { (false, false) }
    model.setShowsStatusItem(false)
    #expect(model.showsStatusItem)
    #expect(defaults.bool(forKey: Preferences.statusItemEnabled))
    #expect(visible.isEmpty)

    model.confirmRunningInBackground = { (true, true) }
    model.setShowsStatusItem(false)
    #expect(!model.showsStatusItem)
    #expect(!defaults.bool(forKey: Preferences.statusItemEnabled))
    #expect(defaults.bool(forKey: Preferences.backgroundAlertSuppressed))

    var asked = false
    model.confirmRunningInBackground = { asked = true; return (true, true) }
    model.setShowsStatusItem(true)
    model.setShowsStatusItem(false)
    #expect(!asked, "not asked again once suppressed")
    #expect(visible == [false, true, false])
  }

  @Test("Launch at login")
  func loginItem() {
    let model = model()
    #expect(!model.launchesAtLogin)
    model.setLaunchesAtLogin(true)
    #expect(model.launchesAtLogin)
    model.setLaunchesAtLogin(false)
    #expect(!model.launchesAtLogin)
  }

  @Test("The window shows one recorder per shortcut")
  func window() {
    let hosting = NSHostingView(rootView: PreferencesView(model: model()))
    hosting.frame = NSRect(x: 0, y: 0, width: PreferencesView.width, height: 560)
    hosting.layoutSubtreeIfNeeded()
    func recorders(_ view: NSView) -> [ShortcutRecorder] {
      (view as? ShortcutRecorder).map { [$0] } ?? view.subviews.flatMap(recorders)
    }
    let found = recorders(hosting)
    #expect(found.count == 18)
    #expect(Set(found.compactMap(\.shortcutName)) == Set(ShortcutNames.all))
    #expect(found.allSatisfy { $0.clipsToBounds })
    #expect(hosting.fittingSize.height < 700)
  }

  @Test("The modifier legend lists ⌃ ⌥ ⇧ ⌘")
  func legend() {
    #expect(ModifierLegend.modifiers.map(\.0) == ["⌃", "⌥", "⇧", "⌘"])
  }
}

// MARK: - Status menu

@MainActor
@Suite("Status menu")
struct StatusMenuTests {
  let statusMenu = StatusMenu()

  var titles: [String] {
    statusMenu.menu.items.map { $0.isSeparatorItem ? "-" : $0.title }
  }

  @Test("Has the original items in the original order")
  func items() {
    #expect(titles == [
      "About Spectacle", "-", "Disable", "-", "Preferences...", "-",
      "Center", "Fullscreen", "-",
      "Left Half", "Right Half", "Top Half", "Bottom Half", "-",
      "Upper Left", "Lower Left", "Upper Right", "Lower Right", "-",
      "Next Display", "Previous Display", "-",
      "Next Third", "Previous Third", "-",
      "Make Larger", "Make Smaller", "-",
      "Undo", "Redo", "-",
      "Quit Spectacle",
    ])
    #expect(statusMenu.menu.item(withTitle: "Disable")?.submenu?.items.count == 2)
  }

  @Test("Shows each action's shortcut")
  func keyEquivalents() {
    let shortcuts = Dictionary(uniqueKeysWithValues: DefaultShortcuts.shortcuts(action: nil).map { ($0.name!, $0) })
    statusMenu.updateKeyEquivalents { shortcuts[$0] }
    let left = statusMenu.shortcutItem(named: "MoveToLeftHalf")
    #expect(left?.keyEquivalent == "←")
    #expect(left?.keyEquivalentModifierMask == [.option, .command])
    #expect(statusMenu.shortcutItem(named: "MoveToCenter")?.keyEquivalent == "c")
    statusMenu.updateKeyEquivalents { _ in nil }
    #expect(left?.keyEquivalent == "")
  }

  @Test("Choosing an item performs its action")
  func actions() {
    var performed: [WindowAction] = []
    statusMenu.performAction = { performed.append($0) }
    for name in ["MoveToFullscreen", "MoveToLeftHalf", "UndoLastMove"] {
      statusMenu.performShortcutAction(statusMenu.shortcutItem(named: name)!)
    }
    #expect(performed == [.fullscreen, .leftHalf, .undo])
  }

  @Test("'Disable for APPLICATION' names the frontmost app and is hidden for blacklisted apps")
  func disableItem() {
    statusMenu.frontmostApplicationState = { ("Safari", false, true) }
    statusMenu.refreshDisableItems()
    #expect(statusMenu.disableForApplicationItem.title.contains("Safari"))
    #expect(statusMenu.disableForApplicationItem.state == .on)
    #expect(!statusMenu.disableForApplicationItem.isHidden)
    statusMenu.frontmostApplicationState = { ("Photoshop", true, false) }
    statusMenu.refreshDisableItems()
    #expect(statusMenu.disableForApplicationItem.isHidden)
  }
}

// MARK: - When shortcuts are active

@Suite("Shortcut activation")
struct ShortcutActivationTests {
  let rules = ShortcutActivationRules(blacklisted: ["com.adobe.Photoshop"], disabled: ["com.example.Game"])

  @Test("Shortcuts are off for blacklisted and disabled apps, and while disabled for an hour")
  func activation() {
    #expect(rules.shortcutsEnabled(frontmostBundleIdentifier: "com.apple.Safari"))
    #expect(rules.shortcutsEnabled(frontmostBundleIdentifier: nil))
    #expect(!rules.shortcutsEnabled(frontmostBundleIdentifier: "com.adobe.Photoshop"))
    #expect(!rules.shortcutsEnabled(frontmostBundleIdentifier: "com.example.Game"))
    var paused = rules
    paused.disabledForAnHour = true
    #expect(!paused.shortcutsEnabled(frontmostBundleIdentifier: "com.apple.Safari"))
  }

  @Test("The bundled defaults blacklist Spectacle itself, Photoshop and Steam")
  func bundledDefaults() throws {
    let suite = "SpectacleTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    // The tests run inside Spectacle.app, so the main bundle is the app.
    Preferences.registerDefaults(bundle: .main, defaults: defaults)
    let blacklist = defaults.stringArray(forKey: Preferences.blacklistedApplications) ?? []
    #expect(blacklist.contains("com.divisiblebyzero.Spectacle"))
    #expect(blacklist.contains("com.adobe.Photoshop"))
    #expect(defaults.bool(forKey: Preferences.statusItemEnabled))
  }
}

