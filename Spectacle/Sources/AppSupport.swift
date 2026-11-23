import AppKit
import ServiceManagement
import os

/// "Launch Spectacle at login", through `SMAppService` (macOS 13+).
enum LoginItem {
  private static let log = Logger(subsystem: "com.divisiblebyzero.Spectacle", category: "LoginItem")

  static var isEnabled: Bool {
    let status = SMAppService.mainApp.status
    return status == .enabled || status == .requiresApproval
  }

  static func setEnabled(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      log.error("Unable to change the login item: \(error.localizedDescription, privacy: .public)")
    }
  }
}

/// User defaults keys and the bundled defaults (Defaults.plist).
enum Preferences {
  static let statusItemEnabled = "StatusItemEnabled"
  static let backgroundAlertSuppressed = "BackgroundAlertSuppressed"
  static let blacklistedApplications = "BlacklistedApplications"
  static let disabledApplications = "DisabledApplications"
  /// Launch argument (`-SpectacleShowAccessibilityDialog YES`) that shows the permission dialog
  /// even when access is granted, to check how it looks.
  static let showAccessibilityDialog = "SpectacleShowAccessibilityDialog"

  static func registerDefaults(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
    guard let url = bundle.url(forResource: "Defaults", withExtension: "plist"),
          let values = NSDictionary(contentsOf: url) as? [String: Any]
    else {
      return
    }
    defaults.register(defaults: values)
  }
}

enum AppInfo {
  static var version: String {
    let info = Bundle.main.infoDictionary ?? [:]
    return (info["CFBundleShortVersionString"] as? String) ?? (info["CFBundleVersion"] as? String) ?? ""
  }

  static var isRunningTests: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil
  }
}

/// The confirmation alerts Spectacle shows.
@MainActor
enum Alerts {
  /// Asks before hiding the status menu. Returns whether to go ahead and whether the person
  /// asked not to be asked again.
  static func confirmRunningInBackground() -> (confirmed: Bool, suppress: Bool) {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.showsSuppressionButton = true
    alert.messageText = NSLocalizedString("AlertMessageTextRunningInBackground", comment: "")
    alert.informativeText = NSLocalizedString("AlertInformativeTextRunningInBackground", comment: "")
    alert.addButton(withTitle: NSLocalizedString("ButtonLabelAffirmative", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("ButtonLabelNegative", comment: ""))
    let response = alert.runModal()
    return (response == .alertFirstButtonReturn, alert.suppressionButton?.state == .on)
  }

  static func confirmRestoreDefaults() -> Bool {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("AlertMessageTextRestoreDefaults", comment: "")
    alert.informativeText = NSLocalizedString("AlertInformativeTextRestoreDefaults", comment: "")
    alert.addButton(withTitle: NSLocalizedString("ButtonLabelAffirmative", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("ButtonLabelNegative", comment: ""))
    return alert.runModal() == .alertFirstButtonReturn
  }

  static func show(_ error: Error) {
    let alert = NSAlert()
    alert.messageText = error.localizedDescription
    alert.informativeText = (error as? LocalizedError)?.recoverySuggestion ?? ""
    alert.addButton(withTitle: NSLocalizedString("ButtonLabelAffirmative", comment: ""))
    alert.runModal()
  }
}
