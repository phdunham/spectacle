#import "SpectacleTestSupport.h"

#import <Carbon/Carbon.h>

#import "SpectacleRegisteredShortcutValidator.h"
#import "SpectacleShortcut.h"
#import "SpectacleShortcutManager.h"
#import "SpectacleShortcutStorage.h"

@interface SpectacleRecordingShortcutStorage : NSObject <SpectacleShortcutStorage>
@property (nonatomic, copy) NSArray<SpectacleShortcut *> *storedShortcuts;
@end

@implementation SpectacleRecordingShortcutStorage
- (NSArray<SpectacleShortcut *> *)loadShortcutsWithAction:(SpectacleShortcutAction)action
{
  return self.storedShortcuts;
}
- (void)storeShortcuts:(NSArray<SpectacleShortcut *> *)shortcuts
{
  self.storedShortcuts = shortcuts;
}
@end

// These tests register real (but deliberately obscure) global hot keys for a moment, because the
// bug they guard against was in the interaction with RegisterEventHotKey/UnregisterEventHotKey.
@interface SpectacleShortcutManagerTests : XCTestCase
@end

@implementation SpectacleShortcutManagerTests
{
  SpectacleRecordingShortcutStorage *_storage;
  SpectacleShortcutManager *_manager;
}

- (void)setUp
{
  [super setUp];
  _storage = [SpectacleRecordingShortcutStorage new];
  _manager = [[SpectacleShortcutManager alloc] initWithShortcutStorage:_storage];
}

- (void)tearDown
{
  [_manager unregisterShortcuts];
  [super tearDown];
}

static SpectacleShortcut *shortcut(NSString *name, NSString *binding)
{
  return [[SpectacleShortcut alloc] initWithShortcutName:name shortcutKeyBinding:binding shortcutAction:^(SpectacleShortcut *s) {}];
}

- (void)testManagedShortcutsCanBeLookedUpAndAreStored
{
  [_manager manageShortcuts:@[shortcut(@"MoveToCenter", @"ctrl+alt+shift+cmd+f19"),
                              shortcut(@"MoveToFullscreen", @"ctrl+alt+shift+cmd+f18")]];
  XCTAssertEqualObjects([_manager shortcutForShortcutName:@"MoveToCenter"].shortcutKeyBinding, @"ctrl+alt+shift+cmd+f19");
  XCTAssertEqual(_storage.storedShortcuts.count, 2u);
  XCTAssertEqual(_manager.shortcuts.count, 2u);
}

- (void)testManagingTheSameShortcutTwiceKeepsTheFirst
{
  [_manager manageShortcuts:@[shortcut(@"MoveToCenter", @"ctrl+alt+shift+cmd+f19")]];
  [_manager manageShortcuts:@[shortcut(@"MoveToCenter", @"ctrl+alt+shift+cmd+f17")]];
  XCTAssertEqualObjects([_manager shortcutForShortcutName:@"MoveToCenter"].shortcutKeyBinding, @"ctrl+alt+shift+cmd+f19");
}

- (void)testUpdatingAShortcutWhileShortcutsAreEnabledTakesEffect
{
  // Regression test: updateShortcut: used to bail out after successfully unregistering the
  // old hot key, so changed shortcuts (and "Restore Defaults") silently stopped working.
  [_manager manageShortcuts:@[shortcut(@"MoveToLeftHalf", @"ctrl+alt+shift+cmd+f19")]];
  XCTAssertTrue(_manager.areShortcutsEnabled);
  [_manager updateShortcut:[[SpectacleShortcut alloc] initWithShortcutName:@"MoveToLeftHalf" shortcutKeyBinding:@"ctrl+alt+shift+cmd+f18"]];
  SpectacleShortcut *updated = [_manager shortcutForShortcutName:@"MoveToLeftHalf"];
  XCTAssertEqualObjects(updated.shortcutKeyBinding, @"ctrl+alt+shift+cmd+f18");
  XCTAssertNotNil(updated.shortcutAction, @"the existing action is kept when the update has none");
  XCTAssertEqualObjects(_storage.storedShortcuts.firstObject.shortcutKeyBinding, @"ctrl+alt+shift+cmd+f18");
}

- (void)testUpdatingAShortcutWhileShortcutsAreDisabled
{
  [_manager unregisterShortcuts];
  [_manager manageShortcuts:@[shortcut(@"MoveToLeftHalf", @"ctrl+alt+shift+cmd+f19")]];
  [_manager updateShortcut:shortcut(@"MoveToLeftHalf", @"ctrl+alt+shift+cmd+f17")];
  XCTAssertEqualObjects([_manager shortcutForShortcutName:@"MoveToLeftHalf"].shortcutKeyBinding, @"ctrl+alt+shift+cmd+f17");
  [_manager registerShortcuts];
  XCTAssertTrue(_manager.areShortcutsEnabled);
  XCTAssertEqualObjects([_manager shortcutForShortcutName:@"MoveToLeftHalf"].shortcutKeyBinding, @"ctrl+alt+shift+cmd+f17");
}

- (void)testUpdatingAnUnknownShortcutDoesNothing
{
  [_manager updateShortcut:shortcut(@"MoveToLeftHalf", @"ctrl+alt+shift+cmd+f19")];
  XCTAssertNil([_manager shortcutForShortcutName:@"MoveToLeftHalf"]);
}

- (void)testClearingAShortcut
{
  [_manager manageShortcuts:@[shortcut(@"MoveToLeftHalf", @"ctrl+alt+shift+cmd+f19")]];
  [_manager clearShortcut:[_manager shortcutForShortcutName:@"MoveToLeftHalf"]];
  XCTAssertNil([_manager shortcutForShortcutName:@"MoveToLeftHalf"]);
  XCTAssertTrue(_storage.storedShortcuts.firstObject.isClearedShortcut);
  [_manager updateShortcut:shortcut(@"MoveToLeftHalf", @"ctrl+alt+shift+cmd+f16")];
  XCTAssertEqualObjects([_manager shortcutForShortcutName:@"MoveToLeftHalf"].shortcutKeyBinding, @"ctrl+alt+shift+cmd+f16");
}

- (void)testDisablingAndReenablingShortcutsIsIdempotent
{
  [_manager manageShortcuts:@[shortcut(@"MoveToLeftHalf", @"ctrl+alt+shift+cmd+f19")]];
  [_manager unregisterShortcuts];
  [_manager unregisterShortcuts];
  XCTAssertFalse(_manager.areShortcutsEnabled);
  [_manager registerShortcuts];
  [_manager registerShortcuts];
  XCTAssertTrue(_manager.areShortcutsEnabled);
  XCTAssertEqualObjects([_manager shortcutForShortcutName:@"MoveToLeftHalf"].shortcutKeyBinding, @"ctrl+alt+shift+cmd+f19");
}

- (void)testRegisteredShortcutValidatorRejectsShortcutsInUse
{
  [_manager manageShortcuts:@[shortcut(@"MoveToLeftHalf", @"ctrl+alt+shift+cmd+f19")]];
  SpectacleRegisteredShortcutValidator *validator = [SpectacleRegisteredShortcutValidator new];
  XCTAssertFalse([validator isShortcutValid:shortcut(@"MoveToRightHalf", @"ctrl+alt+shift+cmd+f19") shortcutManager:_manager]);
  XCTAssertTrue([validator isShortcutValid:shortcut(@"MoveToRightHalf", @"ctrl+alt+shift+cmd+f15") shortcutManager:_manager]);
}

@end
