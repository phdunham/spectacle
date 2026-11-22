#import "SpectacleTestSupport.h"
#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

#import "SpectacleShortcut.h"

@interface SpectacleShortcutTests : XCTestCase
@end

@implementation SpectacleShortcutTests

- (void)testBeInitializedWithAKeyBinding
{
  SpectacleShortcut *shortcut = [[SpectacleShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                                             shortcutKeyBinding:@"option+command+c"];
  SPTAssertEqual(shortcut.shortcutKeyCode, kVK_ANSI_C);
  SPTAssertEqual(shortcut.shortcutModifiers, optionKey | cmdKey);
}

- (void)testBeCopiedWithANewShortcutAction
{
  SpectacleShortcut *shortcut = [[SpectacleShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                                                shortcutKeyCode:kVK_ANSI_C
                                                              shortcutModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand];
  XCTAssertNil(shortcut.shortcutAction);
  XCTAssertNotNil([shortcut copyWithShortcutAction:^(SpectacleShortcut *shortcut) {}].shortcutAction);
}

- (void)testTriggerShortcutActions
{
  __block BOOL shortcutActionTriggered;
  SpectacleShortcut *shortcut = [[SpectacleShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                                                shortcutKeyCode:kVK_ANSI_C
                                                              shortcutModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand
                                                                 shortcutAction:^(SpectacleShortcut *shortcut) {
                                                                   shortcutActionTriggered = YES;
                                                                 }];
  [shortcut triggerShortcutAction];
  XCTAssertTrue(shortcutActionTriggered);
}

- (void)testDetermineIfTheShortcutIsCleared
{
  XCTAssertTrue([[[SpectacleShortcut alloc] initWithShortcutName:nil shortcutKeyBinding:nil] isClearedShortcut]);
  XCTAssertTrue([[[SpectacleShortcut alloc] initWithShortcutName:nil shortcutKeyBinding:@""] isClearedShortcut]);
  XCTAssertTrue([[[SpectacleShortcut alloc] initWithShortcutName:nil
                                          shortcutKeyCode:-1
                                        shortcutModifiers:0] isClearedShortcut]);
  XCTAssertTrue([[[SpectacleShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                          shortcutKeyCode:-1
                                        shortcutModifiers:0] isClearedShortcut]);
}

- (void)testProvideADisplayString
{
  SPTAssertEqual([[[SpectacleShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                          shortcutKeyCode:kVK_ANSI_C
                                        shortcutModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand] displayString], @"⌥⌘C");
}

- (void)testProvideAKeyBinding
{
  SpectacleShortcut *shortcut = [[SpectacleShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                                             shortcutKeyBinding:@"alt+cmd+c"];
  SPTAssertEqual(shortcut.shortcutKeyBinding, @"alt+cmd+c");
}

- (void)testSupportEquality
{
  SpectacleShortcut *shortcut1 = [[SpectacleShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                                                 shortcutKeyCode:kVK_ANSI_C
                                                               shortcutModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand];
  SpectacleShortcut *shortcut2 = [[SpectacleShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                                                 shortcutKeyCode:kVK_ANSI_C
                                                               shortcutModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand];
  SpectacleShortcut *shortcut3 = [[SpectacleShortcut alloc] initWithShortcutName:nil
                                                                 shortcutKeyCode:kVK_ANSI_C
                                                               shortcutModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand];
  SPTAssertEqual(shortcut1, shortcut2);
  SPTAssertEqual(shortcut1, shortcut3);
  SPTAssertNotEqual(shortcut1, [[SpectacleShortcut alloc] initWithShortcutName:nil
                                                                shortcutKeyCode:-1
                                                              shortcutModifiers:0]);
}

// containsModifiers: is used to detect clashes with system-wide shortcuts, so it must be an
// exact match: ⌥⌘Space does not clash with Spotlight's ⌘Space.
- (void)testContainsModifiersRequiresTheExactModifierSet
{
  SpectacleShortcut *shortcut = [[SpectacleShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                                                shortcutKeyCode:kVK_ANSI_C
                                                              shortcutModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand];
  XCTAssertTrue([shortcut containsModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand]);
  XCTAssertTrue([shortcut containsModifiers:optionKey | cmdKey], @"Carbon modifiers are accepted too");
  XCTAssertFalse([shortcut containsModifiers:NSEventModifierFlagOption]);
  XCTAssertFalse([shortcut containsModifiers:NSEventModifierFlagCommand]);
  XCTAssertFalse([shortcut containsModifiers:NSEventModifierFlagControl]);
  XCTAssertFalse([shortcut containsModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand | NSEventModifierFlagShift]);
}

@end

