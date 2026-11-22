#import "SpectacleTestSupport.h"
#import "SpectacleTestDoubles.h"

#import "SpectacleScreenDetector.h"
#import "SpectacleWindowPositionCalculator.h"
#import "SpectacleWindowPositionManager.h"

// End-to-end tests of the window placement pipeline used by every shortcut:
//
//   accessibility rect -> screen detection -> coordinate flip -> JavaScript calculation
//   -> coordinate flip back -> standard / quantized / best-effort window movers
//
// Only the accessibility element, the screens and the workspace are faked; everything else is
// the production code. The expectations are written in Cocoa coordinates (the coordinate space
// of NSScreen.visibleFrame) and converted to accessibility coordinates (top-left origin of the
// primary screen) before comparing with where the fake window ended up.

typedef struct {
  CGRect frame;
  CGRect visibleFrame;
} SPTScreenSpec;

@interface SpectacleWindowPositionManagerTests : XCTestCase
@end

@implementation SpectacleWindowPositionManagerTests
{
  SpectacleWindowPositionCalculator *_calculator;
  SpectacleFakeWorkspace *_workspace;
  SpectacleWindowPositionManager *_manager;
  NSUInteger _failureCount;
  NSArray<SpectacleFakeScreen *> *_screens;
  CGFloat _primaryScreenHeight;
}

- (void)setUp
{
  [super setUp];
  _calculator = [[SpectacleWindowPositionCalculator alloc] initWithErrorHandler:^(NSString *message) {
    XCTFail(@"JavaScript error: %@", message);
  }];
  _workspace = [SpectacleFakeWorkspace workspaceWithBundleIdentifier:@"com.example.TestApplication"];
  _failureCount = 0;
  __weak typeof(self) weakSelf = self;
  _manager = [[SpectacleWindowPositionManager alloc] initWithScreenDetector:[SpectacleScreenDetector new]
                                                   windowPositionCalculator:_calculator
                                                            sharedWorkspace:_workspace
                                                            failureFeedback:^{
                                                              typeof(self) strongSelf = weakSelf;
                                                              if (strongSelf) {
                                                                strongSelf->_failureCount++;
                                                              }
                                                            }
                                                                windowMover:[SpectacleWindowPositionManager defaultWindowMover]];
}

- (void)tearDown
{
  [SpectacleAccessibilityElement setPrimaryScreenFrameOverride:CGRectNull];
  [super tearDown];
}

#pragma mark - Display layouts

- (void)useScreens:(NSArray<NSValue *> *)specs
{
  NSMutableArray<SpectacleFakeScreen *> *screens = [NSMutableArray new];
  [specs enumerateObjectsUsingBlock:^(NSValue *value, NSUInteger index, BOOL *stop) {
    SPTScreenSpec spec;
    [value getValue:&spec size:sizeof(spec)];
    [screens addObject:[SpectacleFakeScreen screenWithFrame:spec.frame
                                               visibleFrame:spec.visibleFrame
                                                       name:[NSString stringWithFormat:@"screen %lu", (unsigned long)index]]];
  }];
  _screens = screens;
  CGRect primaryFrame = NSRectToCGRect(screens[0].frame);
  _primaryScreenHeight = CGRectGetMaxY(primaryFrame);
  [SpectacleAccessibilityElement setPrimaryScreenFrameOverride:primaryFrame];
}

static NSValue *screenSpec(CGRect frame, CGRect visibleFrame)
{
  SPTScreenSpec spec = {frame, visibleFrame};
  return [NSValue valueWithBytes:&spec objCType:@encode(SPTScreenSpec)];
}

/// Display arrangements people actually use. The first screen is always the primary screen.
+ (NSDictionary<NSString *, NSArray<NSValue *> *> *)layouts
{
  return @{
    // 14" MacBook Pro: notch menu bar (38pt), Dock hidden.
    @"MacBook (notch, dock hidden)": @[
      screenSpec(CGRectMake(0, 0, 1512, 982), CGRectMake(0, 0, 1512, 944)),
    ],
    // Classic 1440x900 with the Dock at the bottom and a 25pt menu bar.
    @"Single display, dock at bottom": @[
      screenSpec(CGRectMake(0, 0, 1440, 900), CGRectMake(0, 70, 1440, 805)),
    ],
    // Dock on the left side and an odd visible height.
    @"Single display, dock on left": @[
      screenSpec(CGRectMake(0, 0, 1920, 1080), CGRectMake(64, 0, 1856, 1055)),
    ],
    // Primary 1440p display with a 1080p display to the right, offset vertically.
    @"External display to the right": @[
      screenSpec(CGRectMake(0, 0, 2560, 1440), CGRectMake(0, 0, 2560, 1415)),
      screenSpec(CGRectMake(2560, 180, 1920, 1080), CGRectMake(2560, 180, 1920, 1055)),
    ],
    // Laptop primary with a larger external monitor placed above it (negative AX y).
    @"External display above": @[
      screenSpec(CGRectMake(0, 0, 1512, 982), CGRectMake(0, 0, 1512, 944)),
      screenSpec(CGRectMake(-204, 982, 1920, 1080), CGRectMake(-204, 982, 1920, 1043)),
    ],
    // External display to the left and lower than the primary (negative x and y).
    @"External display to the left, lower": @[
      screenSpec(CGRectMake(0, 0, 1728, 1117), CGRectMake(0, 0, 1728, 1079)),
      screenSpec(CGRectMake(-1920, -500, 1920, 1080), CGRectMake(-1920, -500, 1920, 1055)),
    ],
    // Primary display that is *not* the one at the origin's left, and a portrait display.
    @"Three displays incl. portrait": @[
      screenSpec(CGRectMake(0, 0, 2560, 1440), CGRectMake(0, 0, 2560, 1415)),
      screenSpec(CGRectMake(2560, -400, 1080, 1920), CGRectMake(2560, -400, 1080, 1895)),
      screenSpec(CGRectMake(-1920, 0, 1920, 1200), CGRectMake(-1920, 0, 1920, 1175)),
    ],
  };
}

#pragma mark - Helpers

/// A window roughly in the middle of the screen, not aligned with any Spectacle position.
- (SpectacleFakeWindowElement *)windowOnScreen:(NSScreen *)screen
{
  CGRect visible = NSRectToCGRect(screen.visibleFrame);
  CGRect cocoaRect = CGRectMake(visible.origin.x + 137, visible.origin.y + 91,
                                floor(visible.size.width * 0.37), floor(visible.size.height * 0.41));
  return [[SpectacleFakeWindowElement alloc] initWithRect:SPTAccessibilityRect(cocoaRect, _primaryScreenHeight)];
}

- (void)perform:(SpectacleWindowAction *)action on:(SpectacleFakeWindowElement *)window
{
  [_manager moveFrontmostWindowElement:window action:action screens:_screens mainScreen:_screens[0]];
}

- (CGRect)ax:(CGRect)cocoaRect
{
  return SPTAccessibilityRect(cocoaRect, _primaryScreenHeight);
}

/// Expected positions, straight from the behaviour Spectacle documents.
static CGRect expectedRect(SpectacleWindowAction *action, CGRect v)
{
  CGFloat halfWidth = floor(v.size.width / 2.0);
  CGFloat halfHeight = floor(v.size.height / 2.0);
  CGFloat topY = v.origin.y + halfHeight + fmod(v.size.height, 2.0);
  if ([action isEqualToString:kSpectacleWindowActionFullscreen]) {
    return v;
  } else if ([action isEqualToString:kSpectacleWindowActionLeftHalf]) {
    return CGRectMake(v.origin.x, v.origin.y, halfWidth, v.size.height);
  } else if ([action isEqualToString:kSpectacleWindowActionRightHalf]) {
    return CGRectMake(v.origin.x + halfWidth, v.origin.y, halfWidth, v.size.height);
  } else if ([action isEqualToString:kSpectacleWindowActionTopHalf]) {
    return CGRectMake(v.origin.x, topY, v.size.width, halfHeight);
  } else if ([action isEqualToString:kSpectacleWindowActionBottomHalf]) {
    return CGRectMake(v.origin.x, v.origin.y, v.size.width, halfHeight);
  } else if ([action isEqualToString:kSpectacleWindowActionUpperLeft]) {
    return CGRectMake(v.origin.x, topY, halfWidth, halfHeight);
  } else if ([action isEqualToString:kSpectacleWindowActionUpperRight]) {
    return CGRectMake(v.origin.x + halfWidth, topY, halfWidth, halfHeight);
  } else if ([action isEqualToString:kSpectacleWindowActionLowerLeft]) {
    return CGRectMake(v.origin.x, v.origin.y, halfWidth, halfHeight);
  } else if ([action isEqualToString:kSpectacleWindowActionLowerRight]) {
    return CGRectMake(v.origin.x + halfWidth, v.origin.y, halfWidth, halfHeight);
  }
  return CGRectNull;
}

static NSArray<SpectacleWindowAction *> *placementActions(void)
{
  return @[
    kSpectacleWindowActionFullscreen,
    kSpectacleWindowActionLeftHalf,
    kSpectacleWindowActionRightHalf,
    kSpectacleWindowActionTopHalf,
    kSpectacleWindowActionBottomHalf,
    kSpectacleWindowActionUpperLeft,
    kSpectacleWindowActionUpperRight,
    kSpectacleWindowActionLowerLeft,
    kSpectacleWindowActionLowerRight,
  ];
}

#pragma mark - Placement on every display of every layout

- (void)testEveryPlacementActionOnEveryDisplayOfEveryLayout
{
  NSDictionary<NSString *, NSArray<NSValue *> *> *layouts = [[self class] layouts];
  for (NSString *layoutName in layouts) {
    [self useScreens:layouts[layoutName]];
    for (NSUInteger screenIndex = 0; screenIndex < _screens.count; screenIndex++) {
      NSScreen *screen = _screens[screenIndex];
      CGRect visible = NSRectToCGRect(screen.visibleFrame);
      for (SpectacleWindowAction *action in placementActions()) {
        SpectacleFakeWindowElement *window = [self windowOnScreen:screen];
        [self perform:action on:window];
        CGRect expected = [self ax:expectedRect(action, visible)];
        SPTAssertRectEqual(window.rect, expected, @"%@ on %@, screen %lu", action, layoutName, (unsigned long)screenIndex);
      }
    }
  }
}

- (void)testFullscreenFillsTheVisibleFrameBelowTheMenuBar
{
  [self useScreens:[[self class] layouts][@"MacBook (notch, dock hidden)"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[0]];
  [self perform:kSpectacleWindowActionFullscreen on:window];
  // In accessibility coordinates the window starts right below the 38pt menu bar.
  SPTAssertRectEqual(window.rect, CGRectMake(0, 38, 1512, 944));
  XCTAssertEqual(_failureCount, 0u);
}

- (void)testLeftHalfOnTheMainDisplay
{
  [self useScreens:[[self class] layouts][@"Single display, dock at bottom"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[0]];
  [self perform:kSpectacleWindowActionLeftHalf on:window];
  // Menu bar is 25pt, the Dock 70pt: the left half spans y = 25 ... 830 in AX coordinates.
  SPTAssertRectEqual(window.rect, CGRectMake(0, 25, 720, 805));
}

- (void)testLeftHalfOnADisplayAboveThePrimaryDisplay
{
  [self useScreens:[[self class] layouts][@"External display above"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[1]];
  [self perform:kSpectacleWindowActionLeftHalf on:window];
  SPTAssertRectEqual(window.rect, CGRectMake(-204, -1043, 960, 1043));
}

- (void)testCenterKeepsTheSizeAndCentersOnTheCurrentDisplay
{
  NSDictionary<NSString *, NSArray<NSValue *> *> *layouts = [[self class] layouts];
  for (NSString *layoutName in layouts) {
    [self useScreens:layouts[layoutName]];
    for (NSScreen *screen in _screens) {
      SpectacleFakeWindowElement *window = [self windowOnScreen:screen];
      CGRect before = window.rect;
      [self perform:kSpectacleWindowActionCenter on:window];
      CGRect v = NSRectToCGRect(screen.visibleFrame);
      CGRect expected = CGRectMake(round((v.size.width - before.size.width) / 2.0) + v.origin.x,
                                   round((v.size.height - before.size.height) / 2.0) + v.origin.y,
                                   before.size.width, before.size.height);
      SPTAssertRectEqual(window.rect, [self ax:expected], @"%@ %@", layoutName, screen);
    }
  }
}

#pragma mark - Cycling

- (void)testRepeatingLeftHalfCyclesThroughOneHalfTwoThirdsAndOneThird
{
  [self useScreens:[[self class] layouts][@"Single display, dock at bottom"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[0]];
  CGRect v = NSRectToCGRect(_screens[0].visibleFrame);
  NSArray<NSNumber *> *expectedWidths = @[@720, @960, @480, @720, @960];
  for (NSNumber *width in expectedWidths) {
    [self perform:kSpectacleWindowActionLeftHalf on:window];
    SPTAssertRectEqual(window.rect, [self ax:CGRectMake(v.origin.x, v.origin.y, width.doubleValue, v.size.height)]);
  }
}

- (void)testRepeatingRightHalfCyclesAndStaysAgainstTheRightEdge
{
  [self useScreens:[[self class] layouts][@"External display to the right"]];
  NSScreen *screen = _screens[1];
  SpectacleFakeWindowElement *window = [self windowOnScreen:screen];
  CGRect v = NSRectToCGRect(screen.visibleFrame);
  for (NSNumber *width in @[@960, @1280, @640, @960]) {
    [self perform:kSpectacleWindowActionRightHalf on:window];
    CGRect expected = CGRectMake(CGRectGetMaxX(v) - width.doubleValue, v.origin.y, width.doubleValue, v.size.height);
    SPTAssertRectEqual(window.rect, [self ax:expected]);
  }
}

- (void)testRepeatingTopHalfCyclesAndStaysAgainstTheTopEdge
{
  [self useScreens:[[self class] layouts][@"Single display, dock on left"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[0]];
  CGRect v = NSRectToCGRect(_screens[0].visibleFrame);
  CGFloat half = floor(v.size.height / 2.0);
  CGFloat twoThirds = floor(v.size.height * 2 / 3.0);
  CGFloat oneThird = floor(v.size.height / 3.0);
  [self perform:kSpectacleWindowActionTopHalf on:window];
  SPTAssertRectEqual(window.rect, [self ax:CGRectMake(v.origin.x, v.origin.y + half + 1, v.size.width, half)]);
  [self perform:kSpectacleWindowActionTopHalf on:window];
  SPTAssertRectEqual(window.rect, [self ax:CGRectMake(v.origin.x, CGRectGetMaxY(v) - twoThirds, v.size.width, twoThirds)]);
  [self perform:kSpectacleWindowActionTopHalf on:window];
  SPTAssertRectEqual(window.rect, [self ax:CGRectMake(v.origin.x, CGRectGetMaxY(v) - oneThird, v.size.width, oneThird)]);
}

- (void)testNextThirdCyclesThroughAllSixThirds
{
  [self useScreens:[[self class] layouts][@"Single display, dock at bottom"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[0]];
  CGRect v = NSRectToCGRect(_screens[0].visibleFrame);
  CGFloat w = floor(v.size.width / 3.0);
  CGFloat h = floor(v.size.height / 3.0);
  NSArray<NSValue *> *expected = @[
    [NSValue valueWithRect:NSMakeRect(v.origin.x, v.origin.y, w, v.size.height)],
    [NSValue valueWithRect:NSMakeRect(v.origin.x + w, v.origin.y, w, v.size.height)],
    [NSValue valueWithRect:NSMakeRect(v.origin.x + 2 * w, v.origin.y, w, v.size.height)],
    [NSValue valueWithRect:NSMakeRect(v.origin.x, CGRectGetMaxY(v) - h, v.size.width, h)],
    [NSValue valueWithRect:NSMakeRect(v.origin.x, CGRectGetMaxY(v) - 2 * h, v.size.width, h)],
    [NSValue valueWithRect:NSMakeRect(v.origin.x, CGRectGetMaxY(v) - 3 * h, v.size.width, h)],
    [NSValue valueWithRect:NSMakeRect(v.origin.x, v.origin.y, w, v.size.height)],
  ];
  for (NSValue *value in expected) {
    [self perform:kSpectacleWindowActionNextThird on:window];
    SPTAssertRectEqual(window.rect, [self ax:NSRectToCGRect(value.rectValue)]);
  }
}

#pragma mark - Displays

- (void)testNextAndPreviousDisplayMoveTheWindowAndWrapAround
{
  [self useScreens:[[self class] layouts][@"Three displays incl. portrait"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[0]];
  NSMutableSet<NSString *> *visited = [NSMutableSet new];
  for (NSUInteger i = 0; i < _screens.count; i++) {
    [self perform:kSpectacleWindowActionNextDisplay on:window];
    NSScreen *containing = nil;
    for (NSScreen *screen in _screens) {
      if (CGRectContainsRect(NSRectToCGRect(screen.visibleFrame), [self ax:window.rect])) {
        containing = screen;
      }
    }
    XCTAssertNotNil(containing, @"window %@ is not entirely on any display", NSStringFromRect(window.rect));
    if (containing) {
      [visited addObject:((SpectacleFakeScreen *)containing).fakeName];
    }
  }
  XCTAssertEqual(visited.count, _screens.count, @"next display should visit every display: %@", visited);
  XCTAssertTrue([visited containsObject:@"screen 0"]);
  CGRect beforePrevious = window.rect;
  [self perform:kSpectacleWindowActionPreviousDisplay on:window];
  [self perform:kSpectacleWindowActionNextDisplay on:window];
  SPTAssertRectEqual(window.rect, beforePrevious);
}

- (void)testMovingAWindowThatIsTooBigForTheNextDisplayMakesItFillThatDisplay
{
  [self useScreens:[[self class] layouts][@"External display to the right"]];
  SpectacleFakeWindowElement *window = [[SpectacleFakeWindowElement alloc] initWithRect:[self ax:NSRectToCGRect(_screens[0].visibleFrame)]];
  [self perform:kSpectacleWindowActionNextDisplay on:window];
  SPTAssertRectEqual(window.rect, [self ax:NSRectToCGRect(_screens[1].visibleFrame)]);
}

- (void)testNextDisplayWithASingleDisplayGivesFailureFeedback
{
  [self useScreens:[[self class] layouts][@"MacBook (notch, dock hidden)"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[0]];
  CGRect before = window.rect;
  [self perform:kSpectacleWindowActionNextDisplay on:window];
  SPTAssertRectEqual(window.rect, before);
  XCTAssertEqual(_failureCount, 1u);
  XCTAssertEqual(window.setRectCount, 0u);
}

- (void)testAWindowStraddlingTwoDisplaysIsPlacedOnTheDisplayContainingMostOfIt
{
  [self useScreens:[[self class] layouts][@"External display to the right"]];
  // 70% on the external display, 30% on the primary.
  CGRect cocoaRect = CGRectMake(2560 - 300, 400, 1000, 600);
  SpectacleFakeWindowElement *window = [[SpectacleFakeWindowElement alloc] initWithRect:[self ax:cocoaRect]];
  [self perform:kSpectacleWindowActionFullscreen on:window];
  SPTAssertRectEqual(window.rect, [self ax:NSRectToCGRect(_screens[1].visibleFrame)]);
}

#pragma mark - Failure feedback

- (void)testSheetsAreNotMoved
{
  [self useScreens:[[self class] layouts][@"MacBook (notch, dock hidden)"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[0]];
  window.sheet = YES;
  [self perform:kSpectacleWindowActionFullscreen on:window];
  XCTAssertEqual(window.setRectCount, 0u);
  XCTAssertEqual(_failureCount, 1u);
}

- (void)testSystemDialogsAreNotMoved
{
  [self useScreens:[[self class] layouts][@"MacBook (notch, dock hidden)"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[0]];
  window.systemDialog = YES;
  [self perform:kSpectacleWindowActionLeftHalf on:window];
  XCTAssertEqual(window.setRectCount, 0u);
  XCTAssertEqual(_failureCount, 1u);
}

- (void)testWindowsWithoutAFrameAreNotMoved
{
  [self useScreens:[[self class] layouts][@"MacBook (notch, dock hidden)"]];
  SpectacleFakeWindowElement *window = [[SpectacleFakeWindowElement alloc] initWithRect:CGRectNull];
  [self perform:kSpectacleWindowActionLeftHalf on:window];
  XCTAssertEqual(window.setRectCount, 0u);
  XCTAssertEqual(_failureCount, 1u);
}

- (void)testRepeatingFullscreenGivesFailureFeedbackInsteadOfMovingAgain
{
  [self useScreens:[[self class] layouts][@"MacBook (notch, dock hidden)"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[0]];
  [self perform:kSpectacleWindowActionFullscreen on:window];
  NSUInteger setRectCount = window.setRectCount;
  [self perform:kSpectacleWindowActionFullscreen on:window];
  XCTAssertEqual(window.setRectCount, setRectCount);
  XCTAssertEqual(_failureCount, 1u);
}

- (void)testUnknownActionsGiveFailureFeedback
{
  [self useScreens:[[self class] layouts][@"MacBook (notch, dock hidden)"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[0]];
  [self perform:@"SpectacleWindowActionDoesNotExist" on:window];
  XCTAssertEqual(window.setRectCount, 0u);
  XCTAssertEqual(_failureCount, 1u);
}

#pragma mark - Real-world window behaviour

- (void)testWindowsWithSizeIncrementsStayInsideTheLeftHalf
{
  // Terminal-like windows round their size up to the character grid. The quantized mover has to
  // shrink the request until the window fits, then center it in the requested area.
  [self useScreens:[[self class] layouts][@"Single display, dock at bottom"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[0]];
  window.sizeIncrement = CGSizeMake(7, 17);
  [self perform:kSpectacleWindowActionLeftHalf on:window];
  CGRect target = [self ax:expectedRect(kSpectacleWindowActionLeftHalf, NSRectToCGRect(_screens[0].visibleFrame))];
  XCTAssertTrue(CGRectContainsRect(target, window.rect), @"%@ should fit in %@",
                NSStringFromRect(window.rect), NSStringFromRect(target));
  XCTAssertGreaterThan(window.rect.size.width, target.size.width - 7);
  XCTAssertGreaterThan(window.rect.size.height, target.size.height - 17);
}

- (void)testWindowsWithAMinimumWidthStayOnScreenForRightHalf
{
  // A window that refuses to get narrower than 1000pt cannot be a 720pt half; the best-effort
  // mover must keep it on screen instead of letting it hang off the right edge.
  [self useScreens:[[self class] layouts][@"Single display, dock at bottom"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[0]];
  window.minimumSize = CGSizeMake(1000, 300);
  [self perform:kSpectacleWindowActionRightHalf on:window];
  CGRect visible = [self ax:NSRectToCGRect(_screens[0].visibleFrame)];
  XCTAssertEqual(window.rect.size.width, 1000);
  XCTAssertEqualWithAccuracy(CGRectGetMaxX(window.rect), CGRectGetMaxX(visible), 0.5);
  XCTAssertTrue(CGRectContainsRect(visible, window.rect), @"%@ should be inside %@",
                NSStringFromRect(window.rect), NSStringFromRect(visible));
}

- (void)testWindowsWithAMinimumHeightStayOnScreenForBottomHalf
{
  [self useScreens:[[self class] layouts][@"External display above"]];
  NSScreen *screen = _screens[1];
  SpectacleFakeWindowElement *window = [self windowOnScreen:screen];
  window.minimumSize = CGSizeMake(200, 700);
  [self perform:kSpectacleWindowActionBottomHalf on:window];
  CGRect visible = [self ax:NSRectToCGRect(screen.visibleFrame)];
  XCTAssertTrue(CGRectContainsRect(visible, window.rect), @"%@ should be inside %@",
                NSStringFromRect(window.rect), NSStringFromRect(visible));
  XCTAssertEqualWithAccuracy(CGRectGetMaxY(window.rect), CGRectGetMaxY(visible), 0.5);
}

#pragma mark - Undo / redo

- (void)testUndoAndRedoRestorePreviousPositions
{
  [self useScreens:[[self class] layouts][@"Single display, dock at bottom"]];
  SpectacleFakeWindowElement *window = [self windowOnScreen:_screens[0]];
  CGRect original = window.rect;
  [self perform:kSpectacleWindowActionLeftHalf on:window];
  CGRect leftHalf = window.rect;
  [self perform:kSpectacleWindowActionFullscreen on:window];
  CGRect fullscreen = window.rect;

  [_manager undoLastWindowActionWithScreens:_screens mainScreen:_screens[0]];
  SPTAssertRectEqual(window.rect, leftHalf);
  [_manager undoLastWindowActionWithScreens:_screens mainScreen:_screens[0]];
  SPTAssertRectEqual(window.rect, original);
  [_manager redoLastWindowActionWithScreens:_screens mainScreen:_screens[0]];
  SPTAssertRectEqual(window.rect, leftHalf);
  [_manager redoLastWindowActionWithScreens:_screens mainScreen:_screens[0]];
  SPTAssertRectEqual(window.rect, fullscreen);
  XCTAssertEqual(_failureCount, 0u);

  [_manager redoLastWindowActionWithScreens:_screens mainScreen:_screens[0]];
  XCTAssertEqual(_failureCount, 1u, @"nothing left to redo");
}

- (void)testUndoWithNoHistoryGivesFailureFeedback
{
  [self useScreens:[[self class] layouts][@"Single display, dock at bottom"]];
  [_manager undoLastWindowActionWithScreens:_screens mainScreen:_screens[0]];
  XCTAssertEqual(_failureCount, 1u);
}

- (void)testHistoryIsKeptPerApplication
{
  [self useScreens:[[self class] layouts][@"Single display, dock at bottom"]];
  SpectacleFakeWindowElement *firstWindow = [self windowOnScreen:_screens[0]];
  CGRect firstOriginal = firstWindow.rect;
  [self perform:kSpectacleWindowActionLeftHalf on:firstWindow];

  _workspace.fakeFrontmostApplication.fakeBundleIdentifier = @"com.example.OtherApplication";
  SpectacleFakeWindowElement *secondWindow = [self windowOnScreen:_screens[0]];
  [self perform:kSpectacleWindowActionRightHalf on:secondWindow];

  _workspace.fakeFrontmostApplication.fakeBundleIdentifier = @"com.example.TestApplication";
  [_manager undoLastWindowActionWithScreens:_screens mainScreen:_screens[0]];
  SPTAssertRectEqual(firstWindow.rect, firstOriginal);
  SPTAssertRectEqual(secondWindow.rect, [self ax:expectedRect(kSpectacleWindowActionRightHalf, NSRectToCGRect(_screens[0].visibleFrame))]);
}

@end
