import AppKit
import ApplicationServices
import SwiftUI

/// A button with a solid, rounded fill and a white title.
///
/// Standard buttons are dark grey on a dark window in Dark Mode on recent macOS, and only show
/// the accent color while their window is key; this style looks the same in Light and Dark Mode,
/// focused or not.
struct FilledButtonStyle: ButtonStyle {
  var fill: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(.white)
      .lineLimit(1)
      .padding(.horizontal, 22)
      .frame(height: 32)
      .background {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(fill)
          .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(Color.black.opacity(configuration.isPressed ? 0.25 : 0))
          }
      }
      .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

/// The dialog shown while Spectacle has no Accessibility access.
struct AccessibilityPermissionView: View {
  var showsIllustration = true
  var openSystemSettings: () -> Void
  var quit: () -> Void

  static let size = CGSize(width: 780, height: 360)

  var body: some View {
    VStack(spacing: 0) {
      Text("Spectacle would like to control your windows using accessibility features.")
        .font(.system(size: 13, weight: .bold))
        .padding(.top, 28)
      Text("Grant access to this application in System Settings.")
        .font(.system(size: 11))
        .padding(.top, 8)
      HStack(spacing: 12) {
        Button("Open System Settings", action: openSystemSettings)
          .buttonStyle(FilledButtonStyle(fill: .accentColor))
          .keyboardShortcut(.defaultAction)
        Button("Quit Spectacle", action: quit)
          .buttonStyle(FilledButtonStyle(fill: Color(nsColor: .systemGray)))
          .keyboardShortcut(.cancelAction)
      }
      .padding(.top, 18)
      if showsIllustration {
        AccessibilitySettingsIllustrationView()
          .frame(width: 590, height: 232)
          .padding(.top, 22)
          .accessibilityLabel("System Settings, Privacy & Security, Accessibility, with Spectacle switched on")
      }
      Spacer(minLength: 0)
    }
    .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
  }
}

/// Shows the permission dialog and closes it as soon as access is granted.
@MainActor
final class AccessibilityPermissionWindowController {
  private var window: NSWindow?
  private var timer: Timer?

  /// - Parameter keepOpen: keep the dialog open even after access is granted (for previewing).
  func show(keepOpen: Bool = false) {
    if window == nil {
      let view = AccessibilityPermissionView(
        openSystemSettings: { [weak self] in self?.openSystemSettings() },
        quit: { NSApp.terminate(nil) })
      let window = NSWindow(contentViewController: NSHostingController(rootView: view))
      window.styleMask = [.titled, .closable, .fullSizeContentView]
      window.titlebarAppearsTransparent = true
      window.titleVisibility = .hidden
      window.title = "Spectacle"
      window.isReleasedWhenClosed = false
      window.setContentSize(AccessibilityPermissionView.size)
      self.window = window
    }
    NSApp.activate()
    window?.center()
    window?.makeKeyAndOrderFront(nil)
    timer?.invalidate()
    if !keepOpen {
      timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
        MainActor.assumeIsolated {
          if AXIsProcessTrusted() {
            self?.close()
          }
        }
      }
    }
  }

  func close() {
    timer?.invalidate()
    timer = nil
    window?.close()
  }

  /// Asks macOS to list Spectacle under Accessibility (switched off), then opens that page of
  /// System Settings so the person can switch it on.
  func openSystemSettings() {
    // kAXTrustedCheckOptionPrompt; the global is not concurrency-safe in Swift 6, its value is fixed.
    let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      NSWorkspace.shared.open(url)
    }
  }
}
