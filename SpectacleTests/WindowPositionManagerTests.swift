import AppKit
import Testing

@testable import Spectacle

// End-to-end tests of what a shortcut does: screen detection → coordinate conversion → layout →
// window movers, with fake screens and windows. Expectations are written in Cocoa coordinates
// (like NSScreen.visibleFrame) and converted to accessibility coordinates for comparison.

/// A display arrangement; the first screen is the primary one.
struct DisplayLayout: CustomTestStringConvertible, Sendable {
  let name: String
  let screens: [(frame: CGRect, visible: CGRect)]

  var testDescription: String { name }

  static let all: [DisplayLayout] = [
    DisplayLayout(name: "MacBook (notch, Dock hidden)", screens: [
      (CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: 0, y: 0, width: 1512, height: 944)),
    ]),
    DisplayLayout(name: "Single display, Dock at the bottom", screens: [
      (CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 0, y: 70, width: 1440, height: 805)),
    ]),
    DisplayLayout(name: "Single display, Dock on the left", screens: [
      (CGRect(x: 0, y: 0, width: 1920, height: 1080), CGRect(x: 64, y: 0, width: 1856, height: 1055)),
    ]),
    DisplayLayout(name: "External display to the right", screens: [
      (CGRect(x: 0, y: 0, width: 2560, height: 1440), CGRect(x: 0, y: 0, width: 2560, height: 1415)),
      (CGRect(x: 2560, y: 180, width: 1920, height: 1080), CGRect(x: 2560, y: 180, width: 1920, height: 1055)),
    ]),
    DisplayLayout(name: "External display above", screens: [
      (CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: 0, y: 0, width: 1512, height: 944)),
      (CGRect(x: -204, y: 982, width: 1920, height: 1080), CGRect(x: -204, y: 982, width: 1920, height: 1043)),
    ]),
    DisplayLayout(name: "External display to the left, lower", screens: [
      (CGRect(x: 0, y: 0, width: 1728, height: 1117), CGRect(x: 0, y: 0, width: 1728, height: 1079)),
      (CGRect(x: -1920, y: -500, width: 1920, height: 1080), CGRect(x: -1920, y: -500, width: 1920, height: 1055)),
    ]),
    DisplayLayout(name: "Three displays incl. portrait", screens: [
      (CGRect(x: 0, y: 0, width: 2560, height: 1440), CGRect(x: 0, y: 0, width: 2560, height: 1415)),
      (CGRect(x: 2560, y: -400, width: 1080, height: 1920), CGRect(x: 2560, y: -400, width: 1080, height: 1895)),
      (CGRect(x: -1920, y: 0, width: 1920, height: 1200), CGRect(x: -1920, y: 0, width: 1920, height: 1175)),
    ]),
  ]

  static func named(_ name: String) -> DisplayLayout {
    all.first { $0.name == name }!
  }
}

/// A manager wired to fake screens and a fake workspace, counting failure beeps.
@MainActor
final class ManagerHarness {
  let screens: [FakeScreen]
  let primaryHeight: CGFloat
  let workspace = FakeWorkspace(bundleIdentifier: "com.example.App")
  var failures = 0
  private(set) var manager: WindowPositionManager!

  init(_ layout: DisplayLayout) {
    screens = layout.screens.enumerated().map { FakeScreen("screen \($0.offset)", frame: $0.element.frame, visibleFrame: $0.element.visible) }
    primaryHeight = layout.screens[0].frame.maxY
    manager = WindowPositionManager(screenDetector: ScreenDetector(), workspace: workspace, failureFeedback: { [unowned self] in self.failures += 1 })
  }

  func perform(_ action: WindowAction, _ window: AccessibilityElement?) {
    withPrimaryScreen(screens[0].frame) {
      manager.move(window, action: action, screens: screens, mainScreen: screens[0])
    }
  }

  func undo() {
    withPrimaryScreen(screens[0].frame) { manager.undo(screens: screens, mainScreen: screens[0]) }
  }

  func redo() {
    withPrimaryScreen(screens[0].frame) { manager.redo(screens: screens, mainScreen: screens[0]) }
  }

  func ax(_ cocoa: CGRect) -> CGRect {
    accessibilityRect(cocoa, primaryHeight: primaryHeight)
  }

  /// A window in the middle of a screen, not lined up with any Spectacle position.
  func window(on screen: NSScreen) -> FakeWindow {
    let v = screen.visibleFrame
    return FakeWindow(ax(CGRect(x: v.minX + 137, y: v.minY + 91, width: floor(v.width * 0.37), height: floor(v.height * 0.41))))
  }
}

/// Where each placement action should put a window, from the behaviour Spectacle documents.
func expectedRect(_ action: WindowAction, _ v: CGRect) -> CGRect {
  let halfWidth = floor(v.width / 2)
  let halfHeight = floor(v.height / 2)
  let topY = v.minY + halfHeight + v.height.truncatingRemainder(dividingBy: 2)
  switch action {
  case .fullscreen: return v
  case .leftHalf: return CGRect(x: v.minX, y: v.minY, width: halfWidth, height: v.height)
  case .rightHalf: return CGRect(x: v.minX + halfWidth, y: v.minY, width: halfWidth, height: v.height)
  case .topHalf: return CGRect(x: v.minX, y: topY, width: v.width, height: halfHeight)
  case .bottomHalf: return CGRect(x: v.minX, y: v.minY, width: v.width, height: halfHeight)
  case .upperLeft: return CGRect(x: v.minX, y: topY, width: halfWidth, height: halfHeight)
  case .upperRight: return CGRect(x: v.minX + halfWidth, y: topY, width: halfWidth, height: halfHeight)
  case .lowerLeft: return CGRect(x: v.minX, y: v.minY, width: halfWidth, height: halfHeight)
  case .lowerRight: return CGRect(x: v.minX + halfWidth, y: v.minY, width: halfWidth, height: halfHeight)
  default: return .null
  }
}

let placementActions: [WindowAction] = [
  .fullscreen, .leftHalf, .rightHalf, .topHalf, .bottomHalf, .upperLeft, .upperRight, .lowerLeft, .lowerRight,
]

@MainActor
@Suite("Window position manager")
struct WindowPositionManagerTests {
  // MARK: - Every placement on every display

  @Test("Every placement action on every display", arguments: DisplayLayout.all)
  func everyPlacement(layout: DisplayLayout) {
    let harness = ManagerHarness(layout)
    for (index, screen) in harness.screens.enumerated() {
      for action in placementActions {
        let window = harness.window(on: screen)
        harness.perform(action, window)
        #expect(window.frame == harness.ax(expectedRect(action, screen.visibleFrame)), "\(action) on screen \(index)")
      }
    }
    #expect(harness.failures == 0)
  }

  @Test("Center keeps the size and centers on the window's display", arguments: DisplayLayout.all)
  func center(layout: DisplayLayout) {
    let harness = ManagerHarness(layout)
    for screen in harness.screens {
      let window = harness.window(on: screen)
      let before = window.frame
      harness.perform(.center, window)
      let v = screen.visibleFrame
      let expected = CGRect(x: floor((v.width - before.width) / 2 + 0.5) + v.minX,
                            y: floor((v.height - before.height) / 2 + 0.5) + v.minY,
                            width: before.width, height: before.height)
      #expect(window.frame == harness.ax(expected))
    }
  }

  @Test("Fullscreen fills the area below the notch menu bar")
  func fullscreenNotch() {
    let harness = ManagerHarness(.named("MacBook (notch, Dock hidden)"))
    let window = harness.window(on: harness.screens[0])
    harness.perform(.fullscreen, window)
    #expect(window.frame == CGRect(x: 0, y: 38, width: 1512, height: 944))
  }

  @Test("Left half stays between the menu bar and the Dock")
  func leftHalfWithDock() {
    let harness = ManagerHarness(.named("Single display, Dock at the bottom"))
    let window = harness.window(on: harness.screens[0])
    harness.perform(.leftHalf, window)
    #expect(window.frame == CGRect(x: 0, y: 25, width: 720, height: 805))
  }

  @Test("Left half on a display above the main one (negative coordinates)")
  func leftHalfAbove() {
    let harness = ManagerHarness(.named("External display above"))
    let window = harness.window(on: harness.screens[1])
    harness.perform(.leftHalf, window)
    #expect(window.frame == CGRect(x: -204, y: -1043, width: 960, height: 1043))
  }

  // MARK: - Cycling

  @Test("Left half cycles 1/2 → 2/3 → 1/3 → 1/2")
  func leftHalfCycle() {
    let harness = ManagerHarness(.named("Single display, Dock at the bottom"))
    let window = harness.window(on: harness.screens[0])
    for width: CGFloat in [720, 960, 480, 720, 960] {
      harness.perform(.leftHalf, window)
      #expect(window.frame == CGRect(x: 0, y: 25, width: width, height: 805))
    }
  }

  @Test("Right half cycles against the right edge of an external display")
  func rightHalfCycle() {
    let harness = ManagerHarness(.named("External display to the right"))
    let screen = harness.screens[1]
    let v = screen.visibleFrame
    let window = harness.window(on: screen)
    for width: CGFloat in [960, 1280, 640, 960] {
      harness.perform(.rightHalf, window)
      #expect(window.frame == harness.ax(CGRect(x: v.maxX - width, y: v.minY, width: width, height: v.height)))
    }
  }

  @Test("Top half cycles against the top edge")
  func topHalfCycle() {
    let harness = ManagerHarness(.named("Single display, Dock on the left"))
    let v = harness.screens[0].visibleFrame
    let window = harness.window(on: harness.screens[0])
    let heights = [floor(v.height / 2), floor(v.height * 2 / 3), floor(v.height / 3)]
    harness.perform(.topHalf, window)
    #expect(window.frame == harness.ax(CGRect(x: v.minX, y: v.minY + heights[0] + 1, width: v.width, height: heights[0])))
    harness.perform(.topHalf, window)
    #expect(window.frame == harness.ax(CGRect(x: v.minX, y: v.maxY - heights[1], width: v.width, height: heights[1])))
    harness.perform(.topHalf, window)
    #expect(window.frame == harness.ax(CGRect(x: v.minX, y: v.maxY - heights[2], width: v.width, height: heights[2])))
  }

  @Test("Next third visits all six thirds and wraps")
  func nextThird() {
    let harness = ManagerHarness(.named("Single display, Dock at the bottom"))
    let window = harness.window(on: harness.screens[0])
    let thirds = WindowLayout.thirds(of: harness.screens[0].visibleFrame)
    for expected in thirds + [thirds[0]] {
      harness.perform(.nextThird, window)
      #expect(window.frame == harness.ax(expected))
    }
  }

  // MARK: - Displays

  @Test("Next and previous display visit every display and wrap around")
  func displays() {
    let harness = ManagerHarness(.named("Three displays incl. portrait"))
    let window = harness.window(on: harness.screens[0])
    var visited = Set<String>()
    for _ in harness.screens {
      harness.perform(.nextDisplay, window)
      let cocoa = harness.ax(window.frame)
      let containing = harness.screens.first { $0.visibleFrame.contains(cocoa) }
      #expect(containing != nil, "window \(window.frame) is not entirely on any display")
      visited.insert(containing?.name ?? "-")
    }
    #expect(visited.count == harness.screens.count)
    let before = window.frame
    harness.perform(.previousDisplay, window)
    harness.perform(.nextDisplay, window)
    #expect(window.frame == before)
  }

  @Test("A window too big for the next display fills it")
  func tooBigForNextDisplay() {
    let harness = ManagerHarness(.named("External display to the right"))
    let window = FakeWindow(harness.ax(harness.screens[0].visibleFrame))
    harness.perform(.nextDisplay, window)
    #expect(window.frame == harness.ax(harness.screens[1].visibleFrame))
  }

  @Test("A window across two displays is placed on the one with more of it")
  func straddling() {
    let harness = ManagerHarness(.named("External display to the right"))
    let window = FakeWindow(harness.ax(CGRect(x: 2560 - 300, y: 400, width: 1000, height: 600)))
    harness.perform(.fullscreen, window)
    #expect(window.frame == harness.ax(harness.screens[1].visibleFrame))
  }

  // MARK: - Failure feedback

  @Test("No window, sheets, dialogs, frameless windows, unknown actions and a single display beep")
  func failures() {
    let harness = ManagerHarness(.named("MacBook (notch, Dock hidden)"))
    harness.perform(.fullscreen, nil)
    #expect(harness.failures == 1)

    let sheet = harness.window(on: harness.screens[0])
    sheet.sheet = true
    harness.perform(.fullscreen, sheet)
    let dialog = harness.window(on: harness.screens[0])
    dialog.systemDialog = true
    harness.perform(.leftHalf, dialog)
    let window = harness.window(on: harness.screens[0])
    harness.perform(WindowAction(rawValue: "SpectacleWindowActionDoesNotExist"), window)
    harness.perform(.nextDisplay, window)
    harness.perform(.leftHalf, FakeWindow(.null))
    #expect(harness.failures == 6)
    #expect(sheet.setCount == 0 && dialog.setCount == 0 && window.setCount == 0)
  }

  @Test("Repeating fullscreen beeps instead of moving again")
  func repeatFullscreen() {
    let harness = ManagerHarness(.named("MacBook (notch, Dock hidden)"))
    let window = harness.window(on: harness.screens[0])
    harness.perform(.fullscreen, window)
    let count = window.setCount
    harness.perform(.fullscreen, window)
    #expect(window.setCount == count)
    #expect(harness.failures == 1)
  }

  // MARK: - Real-world windows

  @Test("Windows with size steps stay inside the left half")
  func sizeIncrements() {
    let harness = ManagerHarness(.named("Single display, Dock at the bottom"))
    let window = harness.window(on: harness.screens[0])
    window.sizeIncrement = CGSize(width: 7, height: 17)
    harness.perform(.leftHalf, window)
    let target = harness.ax(expectedRect(.leftHalf, harness.screens[0].visibleFrame))
    #expect(target.contains(window.frame))
    #expect(window.frame.width > target.width - 7)
    #expect(window.frame.height > target.height - 17)
  }

  @Test("A window with a minimum width stays on screen for right half")
  func minimumWidth() {
    let harness = ManagerHarness(.named("Single display, Dock at the bottom"))
    let window = harness.window(on: harness.screens[0])
    window.minimumSize = CGSize(width: 1000, height: 300)
    harness.perform(.rightHalf, window)
    let visible = harness.ax(harness.screens[0].visibleFrame)
    #expect(window.frame.width == 1000)
    #expect(window.frame.maxX == visible.maxX)
    #expect(visible.contains(window.frame))
  }

  @Test("A window with a minimum height stays on screen for bottom half")
  func minimumHeight() {
    let harness = ManagerHarness(.named("External display above"))
    let screen = harness.screens[1]
    let window = harness.window(on: screen)
    window.minimumSize = CGSize(width: 200, height: 700)
    harness.perform(.bottomHalf, window)
    let visible = harness.ax(screen.visibleFrame)
    #expect(visible.contains(window.frame))
    #expect(window.frame.maxY == visible.maxY)
  }

  // MARK: - Undo and redo

  @Test("Undo and redo restore earlier positions")
  func undoRedo() {
    let harness = ManagerHarness(.named("Single display, Dock at the bottom"))
    let window = harness.window(on: harness.screens[0])
    let original = window.frame
    harness.perform(.leftHalf, window)
    let left = window.frame
    harness.perform(.fullscreen, window)
    let full = window.frame

    harness.undo()
    #expect(window.frame == left)
    harness.undo()
    #expect(window.frame == original)
    harness.redo()
    #expect(window.frame == left)
    harness.redo()
    #expect(window.frame == full)
    #expect(harness.failures == 0)
    harness.redo()
    #expect(harness.failures == 1, "nothing left to redo")
  }

  @Test("Undo with no history beeps")
  func undoEmpty() {
    let harness = ManagerHarness(.named("Single display, Dock at the bottom"))
    harness.undo()
    #expect(harness.failures == 1)
  }

  @Test("Each application has its own history")
  func perApplication() {
    let harness = ManagerHarness(.named("Single display, Dock at the bottom"))
    let first = harness.window(on: harness.screens[0])
    let firstOriginal = first.frame
    harness.perform(.leftHalf, first)

    harness.workspace.application.fakeBundleIdentifier = "com.example.Other"
    let second = harness.window(on: harness.screens[0])
    harness.perform(.rightHalf, second)
    let secondPlaced = second.frame

    harness.workspace.application.fakeBundleIdentifier = "com.example.App"
    harness.undo()
    #expect(first.frame == firstOriginal)
    #expect(second.frame == secondPlaced)
  }

  @Test("Apps without a bundle identifier still move but have no undo")
  func noBundleIdentifier() {
    let harness = ManagerHarness(.named("Single display, Dock at the bottom"))
    harness.workspace.application.fakeBundleIdentifier = nil
    let window = harness.window(on: harness.screens[0])
    harness.perform(.leftHalf, window)
    #expect(window.frame == CGRect(x: 0, y: 25, width: 720, height: 805))
    harness.undo()
    #expect(harness.failures == 1)
  }

  @Test("Undo and redo shortcuts go to the history")
  func undoRedoActions() {
    let harness = ManagerHarness(.named("Single display, Dock at the bottom"))
    // perform(_:on:) uses the real screens for undo/redo; with no history both beep.
    harness.manager.perform(.undo, on: FakeWindow(CGRect(x: 0, y: 0, width: 10, height: 10)))
    harness.manager.perform(.redo, on: FakeWindow(CGRect(x: 0, y: 0, width: 10, height: 10)))
    #expect(harness.failures == 2)
  }
}
