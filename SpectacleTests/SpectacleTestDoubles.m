#import "SpectacleTestDoubles.h"

CGRect SPTAccessibilityRect(CGRect cocoaRect, CGFloat primaryScreenHeight)
{
  cocoaRect.origin.y = primaryScreenHeight - CGRectGetMaxY(cocoaRect);
  return cocoaRect;
}

@implementation SpectacleFakeScreen
{
  CGRect _frame;
  CGRect _visibleFrame;
}

+ (instancetype)screenWithFrame:(CGRect)frame visibleFrame:(CGRect)visibleFrame name:(NSString *)name
{
  SpectacleFakeScreen *screen = [self new];
  screen->_frame = frame;
  screen->_visibleFrame = visibleFrame;
  screen.fakeName = name;
  return screen;
}

- (NSRect)frame
{
  return NSRectFromCGRect(_frame);
}

- (NSRect)visibleFrame
{
  return NSRectFromCGRect(_visibleFrame);
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<FakeScreen %@ %@>", self.fakeName, NSStringFromRect(self.frame)];
}

@end

@implementation SpectacleFakeWindowElement

- (instancetype)initWithRect:(CGRect)rect
{
  if (self = [super init]) {
    _rect = rect;
    _requestedRects = [NSMutableArray new];
  }
  return self;
}

- (CGRect)rectOfElement
{
  return _rect;
}

static CGFloat roundUpToIncrement(CGFloat value, CGFloat increment)
{
  return increment > 0 ? ceil(value / increment) * increment : value;
}

- (void)setRectOfElement:(CGRect)rect
{
  _setRectCount++;
  [_requestedRects addObject:[NSValue valueWithRect:NSRectFromCGRect(rect)]];
  rect.size.width = MAX(roundUpToIncrement(rect.size.width, _sizeIncrement.width), _minimumSize.width);
  rect.size.height = MAX(roundUpToIncrement(rect.size.height, _sizeIncrement.height), _minimumSize.height);
  if (_constrainsTopEdge && rect.origin.y < _minimumTopEdge) {
    rect.origin.y = _minimumTopEdge;
  }
  _rect = rect;
}

- (BOOL)isSheet
{
  return _sheet;
}

- (BOOL)isSystemDialog
{
  return _systemDialog;
}

@end

@implementation SpectacleRecordingWindowMover
{
  id<SpectacleWindowMover> _innerWindowMover;
}

- (instancetype)initWithInnerWindowMover:(id<SpectacleWindowMover>)innerWindowMover
{
  if (self = [super init]) {
    _innerWindowMover = innerWindowMover;
    _movedRects = [NSMutableArray new];
    _visibleFrames = [NSMutableArray new];
    _actions = [NSMutableArray new];
  }
  return self;
}

- (instancetype)init
{
  return [self initWithInnerWindowMover:nil];
}

+ (instancetype)newWithInnerWindowMover:(id<SpectacleWindowMover>)innerWindowMover
{
  return [[self alloc] initWithInnerWindowMover:innerWindowMover];
}

- (void)moveWindowRect:(CGRect)windowRect
         frameOfScreen:(CGRect)frameOfScreen
  visibleFrameOfScreen:(CGRect)visibleFrameOfScreen
frontmostWindowElement:(SpectacleAccessibilityElement *)frontmostWindowElement
                action:(SpectacleWindowAction *)action
{
  [_movedRects addObject:[NSValue valueWithRect:NSRectFromCGRect(windowRect)]];
  [_visibleFrames addObject:[NSValue valueWithRect:NSRectFromCGRect(visibleFrameOfScreen)]];
  [_actions addObject:action ?: @"(nil)"];
  [_innerWindowMover moveWindowRect:windowRect
                      frameOfScreen:frameOfScreen
               visibleFrameOfScreen:visibleFrameOfScreen
             frontmostWindowElement:frontmostWindowElement
                             action:action];
}

@end

@implementation SpectacleFakeRunningApplication

- (NSString *)bundleIdentifier
{
  return self.fakeBundleIdentifier;
}

@end

@implementation SpectacleFakeWorkspace

+ (instancetype)workspaceWithBundleIdentifier:(NSString *)bundleIdentifier
{
  SpectacleFakeWorkspace *workspace = [self new];
  SpectacleFakeRunningApplication *application = [SpectacleFakeRunningApplication new];
  application.fakeBundleIdentifier = bundleIdentifier;
  workspace.fakeFrontmostApplication = application;
  return workspace;
}

- (NSRunningApplication *)frontmostApplication
{
  return self.fakeFrontmostApplication;
}

@end
