#import <AppKit/AppKit.h>

#import "SpectacleAccessibilityElement.h"
#import "SpectacleWindowMover.h"

NS_ASSUME_NONNULL_BEGIN

/// An NSScreen with a fixed frame and visible frame (Cocoa coordinates).
@interface SpectacleFakeScreen : NSScreen
+ (instancetype)screenWithFrame:(CGRect)frame visibleFrame:(CGRect)visibleFrame name:(NSString *)name;
@property (nonatomic, copy) NSString *fakeName;
@end

/// A window that lives in accessibility (top-left origin) coordinates and optionally behaves
/// like real applications do: minimum sizes, size increments (e.g. Terminal's character grid)
/// and the window server keeping the title bar below the menu bar.
@interface SpectacleFakeWindowElement : SpectacleAccessibilityElement
- (instancetype)initWithRect:(CGRect)rect;
@property (nonatomic, assign) CGRect rect;
@property (nonatomic, assign) BOOL sheet;
@property (nonatomic, assign) BOOL systemDialog;
@property (nonatomic, assign) CGSize minimumSize;
/// When non-zero, the width/height are rounded *up* to these increments (like a terminal).
@property (nonatomic, assign) CGSize sizeIncrement;
/// When set, the window's top edge can never be above this y (accessibility coordinates).
@property (nonatomic, assign) CGFloat minimumTopEdge;
@property (nonatomic, assign) BOOL constrainsTopEdge;
@property (nonatomic, readonly) NSUInteger setRectCount;
@property (nonatomic, readonly) NSMutableArray<NSValue *> *requestedRects;
@end

/// Records every request it receives; optionally forwards to an inner mover.
@interface SpectacleRecordingWindowMover : NSObject <SpectacleWindowMover>
- (instancetype)initWithInnerWindowMover:(nullable id<SpectacleWindowMover>)innerWindowMover NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly) NSMutableArray<NSValue *> *movedRects;
@property (nonatomic, readonly) NSMutableArray<NSValue *> *visibleFrames;
@property (nonatomic, readonly) NSMutableArray<NSString *> *actions;
@end

@interface SpectacleFakeRunningApplication : NSRunningApplication
@property (nonatomic, copy, nullable) NSString *fakeBundleIdentifier;
@end

@interface SpectacleFakeWorkspace : NSWorkspace
@property (nonatomic, strong, nullable) SpectacleFakeRunningApplication *fakeFrontmostApplication;
+ (instancetype)workspaceWithBundleIdentifier:(nullable NSString *)bundleIdentifier;
@end

/// Converts a Cocoa rect to accessibility coordinates for a primary screen of the given height.
CGRect SPTAccessibilityRect(CGRect cocoaRect, CGFloat primaryScreenHeight);

NS_ASSUME_NONNULL_END
