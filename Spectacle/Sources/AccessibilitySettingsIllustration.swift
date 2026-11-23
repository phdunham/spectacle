import AppKit
import SwiftUI

/// A drawing of System Settings > Privacy & Security > Accessibility (macOS 26 and later) with
/// Spectacle switched on, shown in the permission dialog.
///
/// It is drawn rather than a screenshot, so it stays sharp, never shows the person's other apps,
/// and follows the appearance: Light Mode colors in Light Mode, Dark Mode colors in Dark Mode,
/// redrawing when the appearance changes.
final class AccessibilitySettingsIllustration: NSView {
  private static let sidebarWidth: CGFloat = 168
  private static let sidebarRowHeight: CGFloat = 24
  private static let groupHeaderHeight: CGFloat = 46
  private static let groupRowHeight: CGFloat = 40
  private static let groupFooterHeight: CGFloat = 30

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    commonInit()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  private func commonInit() {
    clipsToBounds = true
    setAccessibilityElement(true)
    setAccessibilityRole(.image)
    setAccessibilityLabel("System Settings, Privacy & Security, Accessibility, with Spectacle switched on")
  }

  override var isFlipped: Bool { true }

  override var intrinsicContentSize: NSSize { NSSize(width: 590, height: 232) }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }

  // MARK: - Colors

  private static func dynamic(_ light: CGFloat, _ dark: CGFloat) -> NSColor {
    NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
      let white = isDark ? dark : light
      return NSColor(srgbRed: white, green: white, blue: white, alpha: 1)
    }
  }

  static let windowColor = dynamic(0.965, 0.118)
  static let windowBorderColor = dynamic(0.78, 0.32)
  static let sidebarColor = dynamic(0.905, 0.192)
  static let groupColor = dynamic(1.0, 0.165)
  static let fieldColor = dynamic(0.84, 0.26)

  // MARK: - Layout (view coordinates; the view is flipped)

  /// The System Settings window; it runs off the bottom of the view like a cropped screenshot.
  var windowRect: NSRect {
    NSRect(x: bounds.minX + 10, y: bounds.minY + 10, width: bounds.width - 20, height: bounds.height + 40)
  }

  var sidebarRect: NSRect {
    NSRect(x: windowRect.minX + 8, y: windowRect.minY + 8, width: Self.sidebarWidth, height: windowRect.height - 16)
  }

  func sidebarRowRect(at index: Int) -> NSRect {
    NSRect(x: sidebarRect.minX + 8, y: sidebarRect.minY + 66 + CGFloat(index) * Self.sidebarRowHeight,
           width: sidebarRect.width - 16, height: Self.sidebarRowHeight)
  }

  var selectedSidebarRowRect: NSRect {
    sidebarRowRect(at: Self.sidebarItems.count - 1)
  }

  var groupRect: NSRect {
    let x = sidebarRect.maxX + 18
    return NSRect(x: x, y: windowRect.minY + 52, width: windowRect.maxX - 18 - x,
                  height: Self.groupHeaderHeight + Self.groupRowHeight + Self.groupFooterHeight)
  }

  var spectacleRowRect: NSRect {
    NSRect(x: groupRect.minX, y: groupRect.minY + Self.groupHeaderHeight, width: groupRect.width, height: Self.groupRowHeight)
  }

  var switchRect: NSRect {
    NSRect(x: spectacleRowRect.maxX - 14 - 32, y: spectacleRowRect.midY - 9, width: 32, height: 18)
  }

  /// Title, SF Symbol and icon color of the sidebar rows; the last one is selected.
  static let sidebarItems: [(title: String, symbol: String, color: NSColor)] = [
    ("General", "gearshape.fill", .systemGray),
    ("Appearance", "circle.lefthalf.filled", dynamic(0.15, 0.35)),
    ("Accessibility", "accessibility", .systemBlue),
    ("Control Center", "switch.2", .systemGray),
    ("Desktop & Dock", "dock.rectangle", dynamic(0.15, 0.35)),
    ("Privacy & Security", "hand.raised.fill", .systemBlue),
  ]

  // MARK: - Drawing

  override func draw(_ dirtyRect: NSRect) {
    let window = NSBezierPath(roundedRect: windowRect, xRadius: 16, yRadius: 16)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.35)
    shadow.shadowBlurRadius = 8
    shadow.shadowOffset = NSSize(width: 0, height: -2)
    shadow.set()
    Self.windowColor.setFill()
    window.fill()
    NSGraphicsContext.restoreGraphicsState()
    Self.windowBorderColor.setStroke()
    window.lineWidth = 1
    window.stroke()
    drawSidebar()
    drawContent()
  }

  private func drawSidebar() {
    let sidebar = sidebarRect
    Self.sidebarColor.setFill()
    NSBezierPath(roundedRect: sidebar, xRadius: 12, yRadius: 12).fill()

    let lights = [
      NSColor(srgbRed: 1.0, green: 0.37, blue: 0.34, alpha: 1),
      NSColor(srgbRed: 1.0, green: 0.74, blue: 0.18, alpha: 1),
      NSColor(srgbRed: 0.16, green: 0.79, blue: 0.25, alpha: 1),
    ]
    for (index, color) in lights.enumerated() {
      color.setFill()
      NSBezierPath(ovalIn: NSRect(x: sidebar.minX + 12 + CGFloat(index) * 20, y: sidebar.minY + 12, width: 12, height: 12)).fill()
    }

    let search = NSRect(x: sidebar.minX + 10, y: sidebar.minY + 34, width: sidebar.width - 20, height: 24)
    Self.fieldColor.setFill()
    NSBezierPath(roundedRect: search, xRadius: 12, yRadius: 12).fill()
    drawSymbol("magnifyingglass", color: .secondaryLabelColor, in: NSRect(x: search.minX + 8, y: search.midY - 6, width: 12, height: 12))
    drawText("Search", font: .systemFont(ofSize: 12), color: .secondaryLabelColor, at: NSPoint(x: search.minX + 25, y: search.midY - 8))

    for (index, item) in Self.sidebarItems.enumerated() {
      let row = sidebarRowRect(at: index)
      let selected = index == Self.sidebarItems.count - 1
      if selected {
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: row, xRadius: 7, yRadius: 7).fill()
      }
      let icon = NSRect(x: row.minX + 6, y: row.midY - 9, width: 18, height: 18)
      item.color.setFill()
      NSBezierPath(roundedRect: icon, xRadius: 5, yRadius: 5).fill()
      drawSymbol(item.symbol, color: .white, in: icon.insetBy(dx: 3.5, dy: 3.5))
      drawText(item.title, font: .systemFont(ofSize: 13, weight: selected ? .medium : .regular),
               color: selected ? .white : .labelColor, at: NSPoint(x: icon.minX + 26, y: row.midY - 8.5))
    }
  }

  private func drawContent() {
    let window = windowRect
    let x = sidebarRect.maxX + 18
    drawSymbol("chevron.left", color: .labelColor, in: NSRect(x: x, y: window.minY + 20, width: 9, height: 14))
    drawSymbol("chevron.right", color: .tertiaryLabelColor, in: NSRect(x: x + 22, y: window.minY + 20, width: 9, height: 14))
    drawText("Accessibility", font: .systemFont(ofSize: 15, weight: .bold), color: .labelColor, at: NSPoint(x: x + 46, y: window.minY + 17))

    let group = groupRect
    Self.groupColor.setFill()
    NSBezierPath(roundedRect: group, xRadius: 10, yRadius: 10).fill()
    ("Allow the applications below to control your computer." as NSString).draw(
      in: NSRect(x: group.minX + 14, y: group.minY + 8, width: group.width - 28, height: Self.groupHeaderHeight - 10),
      withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor])

    let row = spectacleRowRect
    drawSeparator(y: row.minY, from: row.minX + 14, to: row.maxX - 14)
    NSImage(named: NSImage.applicationIconName)?.draw(
      in: NSRect(x: row.minX + 12, y: row.midY - 12, width: 24, height: 24),
      from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    drawText("Spectacle", font: .systemFont(ofSize: 13), color: .labelColor, at: NSPoint(x: row.minX + 46, y: row.midY - 8.5))

    let toggle = switchRect
    NSColor.controlAccentColor.setFill()
    NSBezierPath(roundedRect: toggle, xRadius: 9, yRadius: 9).fill()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: toggle.maxX - 17, y: toggle.minY + 1, width: 16, height: 16)).fill()

    let footerY = row.maxY
    drawSeparator(y: footerY, from: group.minX + 14, to: group.maxX - 14)
    drawText("+", font: .systemFont(ofSize: 15), color: .secondaryLabelColor, at: NSPoint(x: group.minX + 14, y: footerY + 5))
    drawText("−", font: .systemFont(ofSize: 15), color: .tertiaryLabelColor, at: NSPoint(x: group.minX + 38, y: footerY + 5))
  }

  private func drawSeparator(y: CGFloat, from: CGFloat, to: CGFloat) {
    NSColor.separatorColor.setFill()
    NSRect(x: from, y: y, width: to - from, height: 1).fill(using: .sourceOver)
  }

  private func drawText(_ text: String, font: NSFont, color: NSColor, at point: NSPoint) {
    (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
  }

  private func drawSymbol(_ name: String, color: NSColor, in rect: NSRect) {
    guard var symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
      return
    }
    symbol = symbol.withSymbolConfiguration(.init(paletteColors: [color])) ?? symbol
    let size = symbol.size
    let scale = min(rect.width / max(size.width, 1), rect.height / max(size.height, 1))
    let target = NSRect(x: rect.midX - size.width * scale / 2, y: rect.midY - size.height * scale / 2,
                        width: size.width * scale, height: size.height * scale)
    symbol.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
  }
}

/// SwiftUI wrapper for the illustration.
struct AccessibilitySettingsIllustrationView: NSViewRepresentable {
  func makeNSView(context: Context) -> AccessibilitySettingsIllustration {
    AccessibilitySettingsIllustration(frame: NSRect(x: 0, y: 0, width: 590, height: 232))
  }

  func updateNSView(_ nsView: AccessibilitySettingsIllustration, context: Context) {}
}
