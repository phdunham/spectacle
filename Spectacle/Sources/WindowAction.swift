import Foundation

/// Something Spectacle can do to the frontmost window. The raw values are the names earlier
/// releases used, so they can be stored and compared with older data.
struct WindowAction: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  let rawValue: String

  init(rawValue: String) {
    self.rawValue = rawValue
  }

  static let none = WindowAction(rawValue: "SpectacleWindowActionNone")
  static let undo = WindowAction(rawValue: "SpectacleWindowActionUndo")
  static let redo = WindowAction(rawValue: "SpectacleWindowActionRedo")
  static let larger = WindowAction(rawValue: "SpectacleWindowActionLarger")
  static let smaller = WindowAction(rawValue: "SpectacleWindowActionSmaller")
  static let center = WindowAction(rawValue: "SpectacleWindowActionCenter")
  static let fullscreen = WindowAction(rawValue: "SpectacleWindowActionFullscreen")
  static let leftHalf = WindowAction(rawValue: "SpectacleWindowActionLeftHalf")
  static let upperLeft = WindowAction(rawValue: "SpectacleWindowActionUpperLeft")
  static let lowerLeft = WindowAction(rawValue: "SpectacleWindowActionLowerLeft")
  static let rightHalf = WindowAction(rawValue: "SpectacleWindowActionRightHalf")
  static let upperRight = WindowAction(rawValue: "SpectacleWindowActionUpperRight")
  static let lowerRight = WindowAction(rawValue: "SpectacleWindowActionLowerRight")
  static let topHalf = WindowAction(rawValue: "SpectacleWindowActionTopHalf")
  static let bottomHalf = WindowAction(rawValue: "SpectacleWindowActionBottomHalf")
  static let nextDisplay = WindowAction(rawValue: "SpectacleWindowActionNextDisplay")
  static let previousDisplay = WindowAction(rawValue: "SpectacleWindowActionPreviousDisplay")
  static let nextThird = WindowAction(rawValue: "SpectacleWindowActionNextThird")
  static let previousThird = WindowAction(rawValue: "SpectacleWindowActionPreviousThird")

  var isUndo: Bool { self == .undo }
  var isRedo: Bool { self == .redo }
  var isNextDisplay: Bool { self == .nextDisplay }
  var isPreviousDisplay: Bool { self == .previousDisplay }
  var isMovingToDisplay: Bool { isNextDisplay || isPreviousDisplay }

  var description: String { rawValue }
}
