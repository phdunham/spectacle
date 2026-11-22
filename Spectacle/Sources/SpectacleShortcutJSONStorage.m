#import "SpectacleShortcutJSONStorage.h"

static NSURL *findShortcutsFileURL(NSError **error);

@implementation SpectacleShortcutJSONStorage
{
  NSURL *_fileURL;
}

- (instancetype)init
{
  return [self initWithFileURL:nil];
}

- (instancetype)initWithFileURL:(NSURL *)fileURL
{
  if (self = [super init]) {
    _fileURL = fileURL;
  }
  return self;
}

- (NSURL *)shortcutsFileURLWithError:(NSError **)error
{
  return _fileURL ?: findShortcutsFileURL(error);
}

- (NSArray<SpectacleShortcut *> *)loadShortcutsWithAction:(SpectacleShortcutAction)action
{
  NSError *error;
  NSURL *shortcutsFileURL = [self shortcutsFileURLWithError:&error];
  if (!shortcutsFileURL) {
    NSLog(@"Unable to locate the shortcuts file: %@", error.localizedDescription);
    return nil;
  }
  NSData *content = [NSData dataWithContentsOfURL:shortcutsFileURL];
  if (!content) {
    return nil;
  }
  NSArray<NSDictionary *> *jsonArray = [NSJSONSerialization JSONObjectWithData:content
                                                                       options:0
                                                                         error:&error];
  if (![jsonArray isKindOfClass:[NSArray class]]) {
    NSLog(@"Deserializing shortcuts failed: %@", error.localizedDescription);
    return nil;
  }
  return shortcutsFromJsonObject(jsonArray, action);
}

- (void)storeShortcuts:(NSArray<SpectacleShortcut *> *)shortcuts
{
  NSError *error;
  NSURL *shortcutsFileURL = [self shortcutsFileURLWithError:&error];
  if (!shortcutsFileURL) {
    NSLog(@"Unable to locate the shortcuts file: %@", error.localizedDescription);
    return;
  }
  NSData *contents = [NSJSONSerialization dataWithJSONObject:jsonObjectFromShortcuts(shortcuts)
                                                     options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                       error:&error];
  if (!contents || ![contents writeToURL:shortcutsFileURL atomically:YES]) {
    NSLog(@"Unable to store shortcuts at location: %@", [shortcutsFileURL path]);
  }
}

- (BOOL)isMigrationNeeded
{
  NSError *error;
  NSURL *shortcutsFileURL = [self shortcutsFileURLWithError:&error];
  if (!shortcutsFileURL) {
    NSLog(@"Unable to locate the shortcuts file: %@", error.localizedDescription);
    return YES;
  }
  return ![[NSFileManager defaultManager] fileExistsAtPath:[shortcutsFileURL path]];
}

static NSURL *findShortcutsFileURL(NSError **error)
{
  NSURL *shortcutsFileURL = [findOrCreateSpectacleDirectory(error) URLByAppendingPathComponent:@"Shortcuts.json"];
  return shortcutsFileURL.URLByResolvingSymlinksInPath;
}

static NSURL *findOrCreateSpectacleDirectory(NSError **error)
{
  NSURL *applicationSupportDirectory = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                                              inDomain:NSUserDomainMask
                                                                     appropriateForURL:nil
                                                                                create:YES
                                                                                 error:error];
  if (!applicationSupportDirectory) {
    return nil;
  }
  NSURL *spectacleDirectory = [applicationSupportDirectory URLByAppendingPathComponent:@"Spectacle"];
  BOOL success = [[NSFileManager defaultManager] createDirectoryAtURL:spectacleDirectory
                                          withIntermediateDirectories:YES
                                                           attributes:nil
                                                                error:error];
  if (!success) {
    return nil;
  }
  return spectacleDirectory;
}

static NSArray<NSDictionary *> *jsonObjectFromShortcuts(NSArray<SpectacleShortcut *> *shortcuts)
{
  NSMutableArray<NSDictionary *> *jsonArray = [NSMutableArray new];
  for (SpectacleShortcut *shortcut in shortcuts) {
    if (!shortcut.shortcutName) {
      continue;
    }
    [jsonArray addObject:@{
                           @"shortcut_name" : shortcut.shortcutName,
                           @"shortcut_key_binding" : shortcut.shortcutKeyBinding ?: [NSNull null],
                           }];
  }
  return jsonArray;
}

static NSArray<SpectacleShortcut *> *shortcutsFromJsonObject(NSArray<NSDictionary *> *jsonArray, SpectacleShortcutAction action)
{
  NSMutableArray<SpectacleShortcut *> *shortcuts = [NSMutableArray new];
  for (NSDictionary *jsonObject in jsonArray) {
    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    NSString *shortcutName = jsonObject[@"shortcut_name"];
    NSString *shortcutKeyBinding = jsonObject[@"shortcut_key_binding"];
    if (![shortcutName isKindOfClass:[NSString class]]) {
      continue;
    }
    if (![shortcutKeyBinding isKindOfClass:[NSString class]]) {
      shortcutKeyBinding = nil;
    }
    [shortcuts addObject:[[SpectacleShortcut alloc] initWithShortcutName:shortcutName
                                                      shortcutKeyBinding:shortcutKeyBinding
                                                          shortcutAction:action]];
  }
  return shortcuts;
}

@end
