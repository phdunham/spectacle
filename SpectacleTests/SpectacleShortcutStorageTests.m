#import "SpectacleTestSupport.h"

#import <Carbon/Carbon.h>

#import "SpectacleDefaultShortcutHelpers.h"
#import "SpectacleMigratingShortcutStorage.h"
#import "SpectacleShortcut.h"
#import "SpectacleShortcutJSONStorage.h"
#import "SpectacleShortcutStorageMigrationDestination.h"
#import "SpectacleShortcutUserDefaultsStorage.h"

@interface SpectacleShortcutUserDefaultsStorage (Testing)
- (NSArray<SpectacleShortcut *> *)shortcutsFromDictionary:(NSDictionary<NSString *, NSData *> *)dictionary
                                                   action:(SpectacleShortcutAction)action;
@end

@interface SpectacleInMemoryShortcutStorage : NSObject <SpectacleShortcutStorageMigrationDestination>
@property (nonatomic, copy) NSArray<SpectacleShortcut *> *storedShortcuts;
@property (nonatomic, assign, getter=isMigrationNeeded) BOOL migrationNeeded;
@property (nonatomic, assign) NSUInteger storeCount;
@end

@implementation SpectacleInMemoryShortcutStorage
- (NSArray<SpectacleShortcut *> *)loadShortcutsWithAction:(SpectacleShortcutAction)action
{
  NSMutableArray *shortcuts = [NSMutableArray new];
  for (SpectacleShortcut *shortcut in self.storedShortcuts) {
    [shortcuts addObject:[shortcut copyWithShortcutAction:action]];
  }
  return shortcuts;
}
- (void)storeShortcuts:(NSArray<SpectacleShortcut *> *)shortcuts
{
  self.storedShortcuts = shortcuts;
  self.storeCount++;
}
@end

@interface SpectacleShortcutStorageTests : XCTestCase
@end

@implementation SpectacleShortcutStorageTests
{
  NSURL *_directory;
}

- (void)setUp
{
  [super setUp];
  _directory = [NSFileManager.defaultManager.temporaryDirectory URLByAppendingPathComponent:NSUUID.UUID.UUIDString];
  [NSFileManager.defaultManager createDirectoryAtURL:_directory withIntermediateDirectories:YES attributes:nil error:nil];
}

- (void)tearDown
{
  [NSFileManager.defaultManager removeItemAtURL:_directory error:nil];
  [super tearDown];
}

- (NSURL *)fileURL
{
  return [_directory URLByAppendingPathComponent:@"Shortcuts.json"];
}

- (void)testJSONStorageNeedsMigrationUntilSomethingIsStored
{
  SpectacleShortcutJSONStorage *storage = [[SpectacleShortcutJSONStorage alloc] initWithFileURL:[self fileURL]];
  XCTAssertTrue(storage.isMigrationNeeded);
  XCTAssertNil([storage loadShortcutsWithAction:nil], @"a missing file must not crash");
  [storage storeShortcuts:SpectacleDefaultShortcutsWithAction(nil)];
  XCTAssertFalse(storage.isMigrationNeeded);
}

- (void)testJSONStorageRoundTripsShortcutsIncludingClearedOnes
{
  SpectacleShortcutJSONStorage *storage = [[SpectacleShortcutJSONStorage alloc] initWithFileURL:[self fileURL]];
  NSArray<SpectacleShortcut *> *shortcuts = @[
    [[SpectacleShortcut alloc] initWithShortcutName:@"MoveToLeftHalf" shortcutKeyBinding:@"alt+cmd+left"],
    [[SpectacleShortcut alloc] initWithShortcutName:@"MoveToFullscreen" shortcutKeyBinding:@"ctrl+alt+shift+cmd+f"],
    [[SpectacleShortcut alloc] initWithShortcutName:@"MoveToCenter" shortcutKeyBinding:nil],
  ];
  [storage storeShortcuts:shortcuts];
  __block NSUInteger triggered = 0;
  NSArray<SpectacleShortcut *> *loaded = [storage loadShortcutsWithAction:^(SpectacleShortcut *shortcut) { triggered++; }];
  XCTAssertEqual(loaded.count, 3u);
  NSMutableDictionary<NSString *, SpectacleShortcut *> *byName = [NSMutableDictionary new];
  for (SpectacleShortcut *shortcut in loaded) {
    byName[shortcut.shortcutName] = shortcut;
  }
  XCTAssertEqualObjects(byName[@"MoveToLeftHalf"].shortcutKeyBinding, @"alt+cmd+left");
  XCTAssertEqual(byName[@"MoveToLeftHalf"].shortcutKeyCode, kVK_LeftArrow);
  XCTAssertEqualObjects(byName[@"MoveToFullscreen"].shortcutKeyBinding, @"ctrl+alt+shift+cmd+f");
  XCTAssertTrue(byName[@"MoveToCenter"].isClearedShortcut);
  [byName[@"MoveToLeftHalf"] triggerShortcutAction];
  XCTAssertEqual(triggered, 1u);
}

- (void)testJSONStorageIgnoresCorruptFilesAndEntries
{
  SpectacleShortcutJSONStorage *storage = [[SpectacleShortcutJSONStorage alloc] initWithFileURL:[self fileURL]];
  [@"not json" writeToURL:[self fileURL] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  XCTAssertNil([storage loadShortcutsWithAction:nil]);
  [@"{\"shortcut_name\": \"MoveToCenter\"}" writeToURL:[self fileURL] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  XCTAssertNil([storage loadShortcutsWithAction:nil], @"top level must be an array");
  [@"[1, {\"shortcut_name\": 5}, {\"shortcut_name\": \"MoveToCenter\", \"shortcut_key_binding\": \"alt+cmd+c\"}]"
   writeToURL:[self fileURL] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  NSArray *loaded = [storage loadShortcutsWithAction:nil];
  XCTAssertEqual(loaded.count, 1u);
}

- (void)testJSONStorageSkipsShortcutsWithoutAName
{
  SpectacleShortcutJSONStorage *storage = [[SpectacleShortcutJSONStorage alloc] initWithFileURL:[self fileURL]];
  [storage storeShortcuts:@[[[SpectacleShortcut alloc] initWithShortcutName:nil shortcutKeyBinding:@"alt+cmd+c"]]];
  XCTAssertEqual([storage loadShortcutsWithAction:nil].count, 0u);
}

- (void)testMigratingStorageReadsTheOldStorageUntilMigrated
{
  SpectacleInMemoryShortcutStorage *oldStorage = [SpectacleInMemoryShortcutStorage new];
  oldStorage.storedShortcuts = @[[[SpectacleShortcut alloc] initWithShortcutName:@"MoveToCenter" shortcutKeyBinding:@"alt+cmd+c"]];
  SpectacleInMemoryShortcutStorage *newStorage = [SpectacleInMemoryShortcutStorage new];
  newStorage.migrationNeeded = YES;
  SpectacleMigratingShortcutStorage *storage = [[SpectacleMigratingShortcutStorage alloc] initWithShortcutStorage:oldStorage
                                                                                               migrationDestination:newStorage];
  XCTAssertEqualObjects([storage loadShortcutsWithAction:nil].firstObject.shortcutKeyBinding, @"alt+cmd+c");
  [storage storeShortcuts:@[[[SpectacleShortcut alloc] initWithShortcutName:@"MoveToCenter" shortcutKeyBinding:@"ctrl+cmd+c"]]];
  XCTAssertEqual(newStorage.storeCount, 1u);
  XCTAssertEqual(oldStorage.storeCount, 0u, @"never writes to the legacy storage");
  newStorage.migrationNeeded = NO;
  XCTAssertEqualObjects([storage loadShortcutsWithAction:nil].firstObject.shortcutKeyBinding, @"ctrl+cmd+c");
}

- (void)testLegacyUserDefaultsShortcutsCanStillBeDecoded
{
  SpectacleShortcut *shortcut = [[SpectacleShortcut alloc] initWithShortcutName:@"MoveToLeftHalf" shortcutKeyBinding:@"alt+cmd+left"];
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:shortcut requiringSecureCoding:NO error:nil];
  XCTAssertNotNil(data);
  SpectacleShortcutUserDefaultsStorage *storage = [SpectacleShortcutUserDefaultsStorage new];
  NSArray<SpectacleShortcut *> *decoded = [storage shortcutsFromDictionary:@{@"MoveToLeftHalf": data,
                                                                             @"Garbage": [@"nope" dataUsingEncoding:NSUTF8StringEncoding]}
                                                                     action:nil];
  XCTAssertEqual(decoded.count, 1u, @"undecodable data is skipped instead of crashing");
  XCTAssertEqualObjects(decoded.firstObject, shortcut);
  XCTAssertEqualObjects(decoded.firstObject.shortcutName, @"MoveToLeftHalf");
}

@end
