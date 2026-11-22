#import "SpectacleTestSupport.h"

#import <Carbon/Carbon.h>

#import "SpectacleDefaultShortcutHelpers.h"
#import "SpectacleShortcut.h"
#import "SpectacleWindowAction.h"

@interface SpectacleDefaultShortcutsTests : XCTestCase
@end

@implementation SpectacleDefaultShortcutsTests

- (NSDictionary<NSString *, SpectacleShortcut *> *)defaults
{
  NSMutableDictionary *byName = [NSMutableDictionary new];
  for (SpectacleShortcut *shortcut in SpectacleDefaultShortcutsWithAction(^(SpectacleShortcut *s) {})) {
    byName[shortcut.shortcutName] = shortcut;
  }
  return byName;
}

- (void)testThereIsADefaultForEveryAction
{
  NSDictionary<NSString *, SpectacleWindowAction *> *expected = @{
    @"MoveToCenter": kSpectacleWindowActionCenter,
    @"MoveToFullscreen": kSpectacleWindowActionFullscreen,
    @"MoveToLeftHalf": kSpectacleWindowActionLeftHalf,
    @"MoveToRightHalf": kSpectacleWindowActionRightHalf,
    @"MoveToTopHalf": kSpectacleWindowActionTopHalf,
    @"MoveToBottomHalf": kSpectacleWindowActionBottomHalf,
    @"MoveToUpperLeft": kSpectacleWindowActionUpperLeft,
    @"MoveToLowerLeft": kSpectacleWindowActionLowerLeft,
    @"MoveToUpperRight": kSpectacleWindowActionUpperRight,
    @"MoveToLowerRight": kSpectacleWindowActionLowerRight,
    @"MoveToNextDisplay": kSpectacleWindowActionNextDisplay,
    @"MoveToPreviousDisplay": kSpectacleWindowActionPreviousDisplay,
    @"MoveToNextThird": kSpectacleWindowActionNextThird,
    @"MoveToPreviousThird": kSpectacleWindowActionPreviousThird,
    @"MakeLarger": kSpectacleWindowActionLarger,
    @"MakeSmaller": kSpectacleWindowActionSmaller,
    @"UndoLastMove": kSpectacleWindowActionUndo,
    @"RedoLastMove": kSpectacleWindowActionRedo,
  };
  NSDictionary<NSString *, SpectacleShortcut *> *defaults = [self defaults];
  XCTAssertEqual(defaults.count, expected.count);
  for (NSString *name in expected) {
    XCTAssertEqualObjects(defaults[name].windowAction, expected[name], @"%@", name);
    XCTAssertNotNil(defaults[name].shortcutAction, @"%@", name);
    XCTAssertFalse(defaults[name].isClearedShortcut, @"%@", name);
  }
}

- (void)testTheDocumentedDefaultKeyBindings
{
  NSDictionary<NSString *, SpectacleShortcut *> *defaults = [self defaults];
  XCTAssertEqualObjects(defaults[@"MoveToFullscreen"].displayString, @"⌥⌘F");
  XCTAssertEqualObjects(defaults[@"MoveToLeftHalf"].displayString, @"⌥⌘←");
  XCTAssertEqualObjects(defaults[@"MoveToRightHalf"].displayString, @"⌥⌘→");
  XCTAssertEqualObjects(defaults[@"MoveToCenter"].shortcutKeyBinding, @"alt+cmd+c");
  XCTAssertEqual(defaults[@"MoveToLeftHalf"].shortcutKeyCode, kVK_LeftArrow);
  XCTAssertEqual(defaults[@"MoveToLeftHalf"].shortcutModifiers, (NSUInteger)(optionKey | cmdKey));
}

- (void)testNoTwoDefaultsShareAKeyCombination
{
  NSArray<SpectacleShortcut *> *shortcuts = [self defaults].allValues;
  for (NSUInteger i = 0; i < shortcuts.count; i++) {
    for (NSUInteger j = i + 1; j < shortcuts.count; j++) {
      XCTAssertFalse([shortcuts[i] isEqualToShortcut:shortcuts[j]], @"%@ and %@", shortcuts[i].shortcutName, shortcuts[j].shortcutName);
    }
  }
}

- (void)testWindowActionPredicates
{
  XCTAssertTrue(SpectacleIsUndoWindowAction(kSpectacleWindowActionUndo));
  XCTAssertTrue(SpectacleIsRedoWindowAction(kSpectacleWindowActionRedo));
  XCTAssertTrue(SpectacleIsNextDisplayWindowAction(kSpectacleWindowActionNextDisplay));
  XCTAssertTrue(SpectacleIsPreviousDisplayWindowAction(kSpectacleWindowActionPreviousDisplay));
  XCTAssertTrue(SpectacleIsMovingToDisplayWindowAction(kSpectacleWindowActionNextDisplay));
  XCTAssertTrue(SpectacleIsMovingToDisplayWindowAction(kSpectacleWindowActionPreviousDisplay));
  XCTAssertFalse(SpectacleIsMovingToDisplayWindowAction(kSpectacleWindowActionFullscreen));
  XCTAssertFalse(SpectacleIsUndoWindowAction(kSpectacleWindowActionRedo));
}

@end
