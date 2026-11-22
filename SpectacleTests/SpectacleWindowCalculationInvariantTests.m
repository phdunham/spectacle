#import "SpectacleTestSupport.h"

#import "SpectacleWindowPositionCalculationResult.h"
#import "SpectacleWindowPositionCalculator.h"

// Property-style checks of every JavaScript window calculation across many screen geometries
// (odd sizes, negative origins, portrait displays, Retina "looks like" resolutions).
@interface SpectacleWindowCalculationInvariantTests : XCTestCase
@end

@implementation SpectacleWindowCalculationInvariantTests
{
  SpectacleWindowPositionCalculator *_calculator;
}

- (void)setUp
{
  [super setUp];
  _calculator = [[SpectacleWindowPositionCalculator alloc] initWithErrorHandler:^(NSString *message) {
    XCTFail(@"JavaScript error: %@", message);
  }];
}

static NSArray<NSValue *> *visibleFrames(void)
{
  return @[
    [NSValue valueWithRect:NSMakeRect(0, 4, 1440, 873)],
    [NSValue valueWithRect:NSMakeRect(0, 0, 1512, 944)],
    [NSValue valueWithRect:NSMakeRect(0, 70, 1440, 805)],
    [NSValue valueWithRect:NSMakeRect(64, 0, 1856, 1055)],
    [NSValue valueWithRect:NSMakeRect(2560, 180, 1920, 1055)],
    [NSValue valueWithRect:NSMakeRect(-1920, -500, 1920, 1055)],
    [NSValue valueWithRect:NSMakeRect(-204, 982, 1920, 1043)],
    [NSValue valueWithRect:NSMakeRect(2560, -400, 1080, 1895)],
    [NSValue valueWithRect:NSMakeRect(0, 0, 3008, 1667)],
    [NSValue valueWithRect:NSMakeRect(0, 0, 1729, 1079)],
  ];
}

static NSArray<SpectacleWindowAction *> *allCalculatedActions(void)
{
  return @[
    kSpectacleWindowActionCenter, kSpectacleWindowActionFullscreen,
    kSpectacleWindowActionLeftHalf, kSpectacleWindowActionRightHalf,
    kSpectacleWindowActionTopHalf, kSpectacleWindowActionBottomHalf,
    kSpectacleWindowActionUpperLeft, kSpectacleWindowActionUpperRight,
    kSpectacleWindowActionLowerLeft, kSpectacleWindowActionLowerRight,
    kSpectacleWindowActionNextThird, kSpectacleWindowActionPreviousThird,
    kSpectacleWindowActionLarger, kSpectacleWindowActionSmaller,
    kSpectacleWindowActionNextDisplay, kSpectacleWindowActionPreviousDisplay,
  ];
}

- (CGRect)calculate:(SpectacleWindowAction *)action window:(CGRect)window visibleFrame:(CGRect)visibleFrame
{
  SpectacleWindowPositionCalculationResult *result = [_calculator calculateWindowRect:window
                                                           visibleFrameOfSourceScreen:visibleFrame
                                                      visibleFrameOfDestinationScreen:visibleFrame
                                                                               action:action];
  XCTAssertNotNil(result, @"no calculation registered for %@", action);
  XCTAssertEqualObjects(result.action, action);
  return result.windowRect;
}

static CGRect windowInside(CGRect v)
{
  return CGRectMake(v.origin.x + 101, v.origin.y + 87, floor(v.size.width * 0.4), floor(v.size.height * 0.45));
}

- (void)testEveryActionHasARegisteredCalculation
{
  for (SpectacleWindowAction *action in allCalculatedActions()) {
    XCTAssertNotNil([_calculator calculateWindowRect:CGRectMake(10, 10, 500, 400)
                          visibleFrameOfSourceScreen:CGRectMake(0, 0, 1440, 875)
                     visibleFrameOfDestinationScreen:CGRectMake(0, 0, 1440, 875)
                                              action:action], @"%@", action);
  }
  XCTAssertNil([_calculator calculateWindowRect:CGRectMake(10, 10, 500, 400)
                     visibleFrameOfSourceScreen:CGRectMake(0, 0, 1440, 875)
                visibleFrameOfDestinationScreen:CGRectMake(0, 0, 1440, 875)
                                         action:@"SpectacleWindowActionDoesNotExist"]);
}

- (void)testEveryResultIsAnIntegralRectInsideTheVisibleFrame
{
  for (NSValue *value in visibleFrames()) {
    CGRect v = NSRectToCGRect(value.rectValue);
    for (SpectacleWindowAction *action in allCalculatedActions()) {
      CGRect result = [self calculate:action window:windowInside(v) visibleFrame:v];
      XCTAssertFalse(CGRectIsNull(result) || CGRectIsEmpty(result), @"%@ on %@", action, NSStringFromRect(value.rectValue));
      XCTAssertTrue(CGRectContainsRect(v, result), @"%@ on %@ gave %@", action, NSStringFromRect(value.rectValue), NSStringFromRect(result));
      XCTAssertTrue(CGRectEqualToRect(result, CGRectIntegral(result)), @"%@ on %@ gave a fractional rect %@", action,
                    NSStringFromRect(value.rectValue), NSStringFromRect(result));
    }
  }
}

- (void)testHalvesTileTheScreenWithoutGapsOrOverlap
{
  for (NSValue *value in visibleFrames()) {
    CGRect v = NSRectToCGRect(value.rectValue);
    CGRect left = [self calculate:kSpectacleWindowActionLeftHalf window:windowInside(v) visibleFrame:v];
    CGRect right = [self calculate:kSpectacleWindowActionRightHalf window:windowInside(v) visibleFrame:v];
    CGRect top = [self calculate:kSpectacleWindowActionTopHalf window:windowInside(v) visibleFrame:v];
    CGRect bottom = [self calculate:kSpectacleWindowActionBottomHalf window:windowInside(v) visibleFrame:v];
    XCTAssertEqual(CGRectGetMaxX(left), CGRectGetMinX(right), @"%@", NSStringFromRect(value.rectValue));
    XCTAssertEqual(left.origin.x, v.origin.x);
    XCTAssertEqual(left.size.height, v.size.height);
    XCTAssertEqual(right.size.height, v.size.height);
    XCTAssertLessThanOrEqual(CGRectGetMaxY(bottom), CGRectGetMinY(top));
    XCTAssertEqual(CGRectGetMaxY(top), CGRectGetMaxY(v), @"top half must touch the menu bar on %@", NSStringFromRect(value.rectValue));
    XCTAssertEqual(bottom.origin.y, v.origin.y);
  }
}

- (void)testQuartersAreInTheCorners
{
  for (NSValue *value in visibleFrames()) {
    CGRect v = NSRectToCGRect(value.rectValue);
    CGRect ul = [self calculate:kSpectacleWindowActionUpperLeft window:windowInside(v) visibleFrame:v];
    CGRect ur = [self calculate:kSpectacleWindowActionUpperRight window:windowInside(v) visibleFrame:v];
    CGRect ll = [self calculate:kSpectacleWindowActionLowerLeft window:windowInside(v) visibleFrame:v];
    CGRect lr = [self calculate:kSpectacleWindowActionLowerRight window:windowInside(v) visibleFrame:v];
    XCTAssertEqual(ul.origin.x, v.origin.x);
    XCTAssertEqual(CGRectGetMaxY(ul), CGRectGetMaxY(v));
    XCTAssertEqual(CGRectGetMaxY(ur), CGRectGetMaxY(v));
    XCTAssertEqual(ll.origin.y, v.origin.y);
    XCTAssertEqual(lr.origin.y, v.origin.y);
    XCTAssertEqual(ll.origin.x, v.origin.x);
    XCTAssertEqual(CGRectGetMinX(ur), CGRectGetMaxX(ul));
    XCTAssertEqual(CGRectGetMinX(lr), CGRectGetMaxX(ll));
  }
}

- (void)testFullscreenIsTheVisibleFrame
{
  for (NSValue *value in visibleFrames()) {
    CGRect v = NSRectToCGRect(value.rectValue);
    SPTAssertRectEqual([self calculate:kSpectacleWindowActionFullscreen window:windowInside(v) visibleFrame:v], v);
    SPTAssertRectEqual([self calculate:kSpectacleWindowActionFullscreen window:v visibleFrame:v], v);
  }
}

- (void)testSideActionsCycleBackToTheHalf
{
  NSArray<SpectacleWindowAction *> *cyclingActions = @[
    kSpectacleWindowActionLeftHalf, kSpectacleWindowActionRightHalf,
    kSpectacleWindowActionTopHalf, kSpectacleWindowActionBottomHalf,
    kSpectacleWindowActionUpperLeft, kSpectacleWindowActionUpperRight,
    kSpectacleWindowActionLowerLeft, kSpectacleWindowActionLowerRight,
  ];
  for (NSValue *value in visibleFrames()) {
    CGRect v = NSRectToCGRect(value.rectValue);
    for (SpectacleWindowAction *action in cyclingActions) {
      CGRect half = [self calculate:action window:windowInside(v) visibleFrame:v];
      CGRect twoThirds = [self calculate:action window:half visibleFrame:v];
      CGRect oneThird = [self calculate:action window:twoThirds visibleFrame:v];
      CGRect again = [self calculate:action window:oneThird visibleFrame:v];
      XCTAssertFalse(CGRectEqualToRect(half, twoThirds), @"%@ on %@", action, NSStringFromRect(value.rectValue));
      XCTAssertFalse(CGRectEqualToRect(twoThirds, oneThird), @"%@ on %@", action, NSStringFromRect(value.rectValue));
      SPTAssertRectEqual(again, half, @"%@ on %@ should cycle back to the half", action, NSStringFromRect(value.rectValue));
    }
  }
}

- (void)testNextAndPreviousThirdAreInverses
{
  for (NSValue *value in visibleFrames()) {
    CGRect v = NSRectToCGRect(value.rectValue);
    CGRect third = [self calculate:kSpectacleWindowActionNextThird window:windowInside(v) visibleFrame:v];
    for (int i = 0; i < 6; i++) {
      CGRect next = [self calculate:kSpectacleWindowActionNextThird window:third visibleFrame:v];
      SPTAssertRectEqual([self calculate:kSpectacleWindowActionPreviousThird window:next visibleFrame:v], third);
      third = next;
    }
  }
}

- (void)testLargerThenSmallerRoughlyRestoresTheSize
{
  for (NSValue *value in visibleFrames()) {
    CGRect v = NSRectToCGRect(value.rectValue);
    CGRect start = windowInside(v);
    CGRect larger = [self calculate:kSpectacleWindowActionLarger window:start visibleFrame:v];
    XCTAssertEqual(larger.size.width, start.size.width + 30);
    XCTAssertEqual(larger.size.height, start.size.height + 30);
    CGRect smaller = [self calculate:kSpectacleWindowActionSmaller window:larger visibleFrame:v];
    SPTAssertRectEqual(smaller, start);
  }
}

- (void)testSmallerStopsAtAQuarterOfTheScreen
{
  CGRect v = CGRectMake(0, 0, 1440, 875);
  CGRect window = CGRectMake(500, 300, 380, 240);
  for (int i = 0; i < 20; i++) {
    window = [self calculate:kSpectacleWindowActionSmaller window:window visibleFrame:v];
  }
  XCTAssertGreaterThan(window.size.width, floor(v.size.width / 4.0));
  XCTAssertGreaterThan(window.size.height, floor(v.size.height / 4.0));
}

- (void)testMovingToADisplayCentersTheWindowOnTheDestination
{
  CGRect source = CGRectMake(0, 0, 1440, 875);
  CGRect destination = CGRectMake(1440, -100, 1920, 1055);
  SpectacleWindowPositionCalculationResult *result = [_calculator calculateWindowRect:CGRectMake(100, 100, 800, 600)
                                                           visibleFrameOfSourceScreen:source
                                                      visibleFrameOfDestinationScreen:destination
                                                                               action:kSpectacleWindowActionNextDisplay];
  SPTAssertRectEqual(result.windowRect, CGRectMake(1440 + 560, -100 + 228, 800, 600));
}

@end
