#import <Cocoa/Cocoa.h>

#import "SpectacleMacros.h"
#import "SpectacleWindowAction.h"

typedef void (^SpectacleFailureFeedback)(void);

@class SpectacleAccessibilityElement;
@class SpectacleScreenDetector;
@class SpectacleShortcut;
@class SpectacleWindowPositionCalculator;

@protocol SpectacleWindowMover;

@interface SpectacleWindowPositionManager : NSObject

- (instancetype)initWithScreenDetector:(SpectacleScreenDetector *)screenDetector
              windowPositionCalculator:(SpectacleWindowPositionCalculator *)windowPositionCalculator
                       sharedWorkspace:(NSWorkspace *)sharedWorkspace
                       failureFeedback:(SpectacleFailureFeedback)failureFeedback
                           windowMover:(id<SpectacleWindowMover>)windowMover NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithScreenDetector:(SpectacleScreenDetector *)screenDetector
              windowPositionCalculator:(SpectacleWindowPositionCalculator *)windowPositionCalculator
                       sharedWorkspace:(NSWorkspace *)sharedWorkspace;

SPECTACLE_INIT_AND_NEW_UNAVAILABLE

/// The window mover chain used by the application: standard -> quantized -> best effort.
+ (id<SpectacleWindowMover>)defaultWindowMover;

- (void)moveFrontmostWindowElement:(SpectacleAccessibilityElement *)frontmostWindowElement
                            action:(SpectacleWindowAction *)action
                           screens:(NSArray<NSScreen *> *)screens
                        mainScreen:(NSScreen *)mainScreen;

- (void)moveFrontmostWindowElement:(SpectacleAccessibilityElement *)frontmostWindowElement
                            action:(SpectacleWindowAction *)action;

- (void)undoLastWindowAction;
- (void)redoLastWindowAction;

- (void)undoLastWindowActionWithScreens:(NSArray<NSScreen *> *)screens mainScreen:(NSScreen *)mainScreen;
- (void)redoLastWindowActionWithScreens:(NSArray<NSScreen *> *)screens mainScreen:(NSScreen *)mainScreen;

@end
