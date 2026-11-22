#import "SpectacleTestSupport.h"
#import "SpectacleTestDoubles.h"

#import "SpectacleScreenDetectionResult.h"
#import "SpectacleScreenDetector.h"

@interface SpectacleScreenDetectorTests : XCTestCase
@end

@implementation SpectacleScreenDetectorTests
{
  SpectacleScreenDetector *_detector;
  SpectacleFakeScreen *_primary;
  SpectacleFakeScreen *_right;
  SpectacleFakeScreen *_left;
  SpectacleFakeScreen *_above;
}

- (void)setUp
{
  [super setUp];
  _detector = [SpectacleScreenDetector new];
  _primary = [SpectacleFakeScreen screenWithFrame:CGRectMake(0, 0, 1440, 900) visibleFrame:CGRectMake(0, 0, 1440, 875) name:@"primary"];
  _right = [SpectacleFakeScreen screenWithFrame:CGRectMake(1440, 0, 1920, 1080) visibleFrame:CGRectMake(1440, 0, 1920, 1055) name:@"right"];
  _left = [SpectacleFakeScreen screenWithFrame:CGRectMake(-1280, 100, 1280, 800) visibleFrame:CGRectMake(-1280, 100, 1280, 775) name:@"left"];
  _above = [SpectacleFakeScreen screenWithFrame:CGRectMake(0, 900, 1440, 900) visibleFrame:CGRectMake(0, 900, 1440, 875) name:@"above"];
  [SpectacleAccessibilityElement setPrimaryScreenFrameOverride:CGRectMake(0, 0, 1440, 900)];
}

- (void)tearDown
{
  [SpectacleAccessibilityElement setPrimaryScreenFrameOverride:CGRectNull];
  [super tearDown];
}

- (SpectacleFakeWindowElement *)windowAtCocoaRect:(CGRect)rect
{
  return [[SpectacleFakeWindowElement alloc] initWithRect:SPTAccessibilityRect(rect, 900)];
}

- (SpectacleScreenDetectionResult *)detect:(SpectacleWindowAction *)action rect:(CGRect)rect screens:(NSArray *)screens
{
  return [_detector screenWithAction:action frontmostWindowElement:[self windowAtCocoaRect:rect] screens:screens mainScreen:_primary];
}

- (void)testFindsTheScreenThatContainsTheWindow
{
  NSArray *screens = @[_primary, _right, _left, _above];
  XCTAssertEqual([self detect:kSpectacleWindowActionCenter rect:CGRectMake(100, 100, 300, 300) screens:screens].sourceScreen, _primary);
  XCTAssertEqual([self detect:kSpectacleWindowActionCenter rect:CGRectMake(1600, 100, 300, 300) screens:screens].sourceScreen, _right);
  XCTAssertEqual([self detect:kSpectacleWindowActionCenter rect:CGRectMake(-1000, 200, 300, 300) screens:screens].sourceScreen, _left);
  XCTAssertEqual([self detect:kSpectacleWindowActionCenter rect:CGRectMake(100, 1000, 300, 300) screens:screens].sourceScreen, _above);
}

- (void)testDestinationIsTheSourceScreenForPlacementActions
{
  NSArray *screens = @[_primary, _right];
  SpectacleScreenDetectionResult *result = [self detect:kSpectacleWindowActionLeftHalf rect:CGRectMake(1600, 100, 300, 300) screens:screens];
  XCTAssertEqual(result.sourceScreen, _right);
  XCTAssertEqual(result.destinationScreen, _right);
}

- (void)testPicksTheScreenContainingTheLargestPartOfAStraddlingWindow
{
  NSArray *screens = @[_primary, _right];
  XCTAssertEqual([self detect:kSpectacleWindowActionCenter rect:CGRectMake(1340, 100, 400, 300) screens:screens].sourceScreen, _right);
  XCTAssertEqual([self detect:kSpectacleWindowActionCenter rect:CGRectMake(1140, 100, 400, 300) screens:screens].sourceScreen, _primary);
}

- (void)testFallsBackToTheMainScreenForWindowsOffScreen
{
  NSArray *screens = @[_right, _primary];
  XCTAssertEqual([self detect:kSpectacleWindowActionCenter rect:CGRectMake(9000, 9000, 300, 300) screens:screens].sourceScreen, _primary);
}

- (void)testNextAndPreviousDisplayWrapAround
{
  NSArray *screens = @[_primary, _right, _left];
  NSMutableArray *sequence = [NSMutableArray new];
  CGRect rect = CGRectMake(100, 100, 300, 300);
  for (int i = 0; i < 3; i++) {
    NSScreen *next = [self detect:kSpectacleWindowActionNextDisplay rect:rect screens:screens].destinationScreen;
    XCTAssertNotNil(next, @"no next display for %@", NSStringFromRect(rect));
    if (!next) {
      return;
    }
    [sequence addObject:next];
    CGRect frame = NSRectToCGRect(next.frame);
    rect = CGRectMake(frame.origin.x + 10, frame.origin.y + 10, 300, 300);
  }
  XCTAssertEqual(sequence.lastObject, _primary, @"three next-display moves on three displays return to the start");
  // NSScreen's -hash needs a real display, so compare the fake screens by name.
  XCTAssertEqual([NSSet setWithArray:[sequence valueForKey:@"fakeName"]].count, 3u);

  NSScreen *next = [self detect:kSpectacleWindowActionNextDisplay rect:CGRectMake(100, 100, 300, 300) screens:screens].destinationScreen;
  CGRect nextFrame = NSRectToCGRect(next.frame);
  NSScreen *back = [self detect:kSpectacleWindowActionPreviousDisplay
                           rect:CGRectMake(nextFrame.origin.x + 10, nextFrame.origin.y + 10, 300, 300)
                        screens:screens].destinationScreen;
  XCTAssertEqual(back, _primary);
}

- (void)testDisplayOrderDoesNotDependOnTheOrderNSScreenReportsThemIn
{
  CGRect rect = CGRectMake(100, 100, 300, 300);
  NSScreen *a = [self detect:kSpectacleWindowActionNextDisplay rect:rect screens:@[_primary, _right, _left, _above]].destinationScreen;
  NSScreen *b = [self detect:kSpectacleWindowActionNextDisplay rect:rect screens:@[_above, _left, _right, _primary]].destinationScreen;
  XCTAssertEqual(a, b);
}

- (void)testThereIsNoNextDisplayWithASingleDisplay
{
  NSArray *screens = @[_primary];
  XCTAssertNil([self detect:kSpectacleWindowActionNextDisplay rect:CGRectMake(100, 100, 300, 300) screens:screens].destinationScreen);
  XCTAssertNil([self detect:kSpectacleWindowActionPreviousDisplay rect:CGRectMake(100, 100, 300, 300) screens:screens].destinationScreen);
}

- (void)testZeroSizedWindowsDoNotCrash
{
  NSArray *screens = @[_primary, _right];
  XCTAssertEqual([self detect:kSpectacleWindowActionCenter rect:CGRectMake(5000, 5000, 0, 0) screens:screens].sourceScreen, _primary);
}

@end
