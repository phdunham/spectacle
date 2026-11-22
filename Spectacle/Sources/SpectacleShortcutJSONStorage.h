#import <Foundation/Foundation.h>

#import "SpectacleShortcutStorageMigrationDestination.h"

@interface SpectacleShortcutJSONStorage : NSObject <SpectacleShortcutStorageMigrationDestination>

/// Stores shortcuts in ~/Library/Application Support/Spectacle/Shortcuts.json.
- (instancetype)init;

/// Stores shortcuts in the given file (used by the unit tests).
- (instancetype)initWithFileURL:(NSURL *)fileURL NS_DESIGNATED_INITIALIZER;

@end
