#import "SpectacleTestSupport.h"
#import "SpectacleTestDoubles.h"

#import "SpectacleBestEffortWindowMover.h"
#import "SpectacleQuantizedWindowMover.h"
#import "SpectacleStandardWindowMover.h"
#import "SpectacleWindowPositionManager.h"

@interface SpectacleWindowMoverTests : XCTestCase
@end

@implementation SpectacleWindowMoverTests

- (void)setUp
{
  [super setUp];
  [SpectacleAccessibilityElement setPrimaryScreenFrameOverride:CGRectMake(0, 0, 1440, 900)];
}

- (void)tearDown
{
  [SpectacleAccessibilityElement setPrimaryScreenFrameOverride:CGRectNull];
  [super tearDown];
}

static const CGRect kFrame = {{0, 0}, {1440, 900}};
static const CGRect kVisibleFrame = {{0, 0}, {1440, 875}};

- (void)testStandardMoverSetsTheRectAndCallsTheInnerMover
{
  SpectacleRecordingWindowMover *recorder = [SpectacleRecordingWindowMover new];
  SpectacleStandardWindowMover *mover = [SpectacleStandardWindowMover newWithInnerWindowMover:recorder];
  SpectacleFakeWindowElement *window = [[SpectacleFakeWindowElement alloc] initWithRect:CGRectMake(10, 10, 100, 100)];
  [mover moveWindowRect:CGRectMake(0, 25, 720, 875) frameOfScreen:kFrame visibleFrameOfScreen:kVisibleFrame
 frontmostWindowElement:window action:kSpectacleWindowActionLeftHalf];
  SPTAssertRectEqual(window.rect, CGRectMake(0, 25, 720, 875));
  XCTAssertEqual(recorder.movedRects.count, 1u);
  XCTAssertEqualObjects(recorder.actions.firstObject, kSpectacleWindowActionLeftHalf);
}

- (void)testStandardMoverDoesNothingForWindowsWithoutAFrame
{
  SpectacleRecordingWindowMover *recorder = [SpectacleRecordingWindowMover new];
  SpectacleStandardWindowMover *mover = [SpectacleStandardWindowMover newWithInnerWindowMover:recorder];
  SpectacleFakeWindowElement *window = [[SpectacleFakeWindowElement alloc] initWithRect:CGRectNull];
  [mover moveWindowRect:CGRectMake(0, 25, 720, 875) frameOfScreen:kFrame visibleFrameOfScreen:kVisibleFrame
 frontmostWindowElement:window action:kSpectacleWindowActionLeftHalf];
  XCTAssertEqual(window.setRectCount, 0u);
  XCTAssertEqual(recorder.movedRects.count, 0u);
}

- (void)testQuantizedMoverLeavesExactFitsAlone
{
  SpectacleQuantizedWindowMover *mover = [SpectacleQuantizedWindowMover newWithInnerWindowMover:nil];
  SpectacleFakeWindowElement *window = [[SpectacleFakeWindowElement alloc] initWithRect:CGRectMake(0, 25, 720, 875)];
  [mover moveWindowRect:CGRectMake(0, 25, 720, 875) frameOfScreen:kFrame visibleFrameOfScreen:kVisibleFrame
 frontmostWindowElement:window action:kSpectacleWindowActionLeftHalf];
  XCTAssertEqual(window.setRectCount, 0u);
}

- (void)testQuantizedMoverShrinksWindowsThatRoundTheirSizeUp
{
  SpectacleQuantizedWindowMover *mover = [SpectacleQuantizedWindowMover newWithInnerWindowMover:nil];
  SpectacleFakeWindowElement *window = [[SpectacleFakeWindowElement alloc] initWithRect:CGRectMake(0, 0, 10, 10)];
  window.sizeIncrement = CGSizeMake(9, 19);
  CGRect target = CGRectMake(720, 25, 720, 875);
  [window setRectOfElement:target]; // what the standard mover does first
  [mover moveWindowRect:target frameOfScreen:kFrame visibleFrameOfScreen:kVisibleFrame
 frontmostWindowElement:window action:kSpectacleWindowActionRightHalf];
  XCTAssertTrue(CGRectContainsRect(target, window.rect), @"%@ in %@", NSStringFromRect(window.rect), NSStringFromRect(target));
  XCTAssertEqualWithAccuracy(CGRectGetMidX(window.rect), CGRectGetMidX(target), 1.0);
  XCTAssertEqualWithAccuracy(CGRectGetMidY(window.rect), CGRectGetMidY(target), 1.0);
}

- (void)testQuantizedMoverGivesUpOnWindowsThatCannotShrink
{
  SpectacleQuantizedWindowMover *mover = [SpectacleQuantizedWindowMover newWithInnerWindowMover:nil];
  SpectacleFakeWindowElement *window = [[SpectacleFakeWindowElement alloc] initWithRect:CGRectMake(0, 0, 10, 10)];
  window.minimumSize = CGSizeMake(1000, 100);
  CGRect target = CGRectMake(720, 25, 720, 875);
  [window setRectOfElement:target];
  [mover moveWindowRect:target frameOfScreen:kFrame visibleFrameOfScreen:kVisibleFrame
 frontmostWindowElement:window action:kSpectacleWindowActionRightHalf];
  XCTAssertLessThan(window.setRectCount, 100u, @"the shrinking loop must terminate quickly");
  XCTAssertEqual(window.rect.size.width, 1000);
}

- (void)testBestEffortMoverPullsWindowsBackFromTheRightEdge
{
  SpectacleBestEffortWindowMover *mover = [SpectacleBestEffortWindowMover new];
  SpectacleFakeWindowElement *window = [[SpectacleFakeWindowElement alloc] initWithRect:CGRectMake(720, 25, 1000, 875)];
  [mover moveWindowRect:CGRectMake(720, 25, 720, 875) frameOfScreen:kFrame visibleFrameOfScreen:kVisibleFrame
 frontmostWindowElement:window action:kSpectacleWindowActionRightHalf];
  SPTAssertRectEqual(window.rect, CGRectMake(440, 25, 1000, 875));
}

- (void)testBestEffortMoverPullsWindowsBackFromTheLeftEdge
{
  SpectacleBestEffortWindowMover *mover = [SpectacleBestEffortWindowMover new];
  SpectacleFakeWindowElement *window = [[SpectacleFakeWindowElement alloc] initWithRect:CGRectMake(-50, 25, 600, 400)];
  [mover moveWindowRect:CGRectMake(0, 25, 600, 400) frameOfScreen:kFrame visibleFrameOfScreen:kVisibleFrame
 frontmostWindowElement:window action:kSpectacleWindowActionLeftHalf];
  SPTAssertRectEqual(window.rect, CGRectMake(0, 25, 600, 400));
}

- (void)testBestEffortMoverKeepsWindowsAboveTheDockAndBelowTheMenuBar
{
  CGRect visibleFrameWithDock = CGRectMake(0, 70, 1440, 805); // AX y range 25 ... 830
  SpectacleBestEffortWindowMover *mover = [SpectacleBestEffortWindowMover new];
  SpectacleFakeWindowElement *tooLow = [[SpectacleFakeWindowElement alloc] initWithRect:CGRectMake(0, 600, 720, 500)];
  [mover moveWindowRect:CGRectMake(0, 600, 720, 500) frameOfScreen:kFrame visibleFrameOfScreen:visibleFrameWithDock
 frontmostWindowElement:tooLow action:kSpectacleWindowActionBottomHalf];
  SPTAssertRectEqual(tooLow.rect, CGRectMake(0, 330, 720, 500));

  SpectacleFakeWindowElement *tooHigh = [[SpectacleFakeWindowElement alloc] initWithRect:CGRectMake(0, 0, 720, 500)];
  [mover moveWindowRect:CGRectMake(0, 0, 720, 500) frameOfScreen:kFrame visibleFrameOfScreen:visibleFrameWithDock
 frontmostWindowElement:tooHigh action:kSpectacleWindowActionTopHalf];
  SPTAssertRectEqual(tooHigh.rect, CGRectMake(0, 25, 720, 500));
}

- (void)testBestEffortMoverDoesNotTouchWindowsThatAreAlreadyOnScreen
{
  SpectacleBestEffortWindowMover *mover = [SpectacleBestEffortWindowMover new];
  SpectacleFakeWindowElement *window = [[SpectacleFakeWindowElement alloc] initWithRect:CGRectMake(0, 25, 720, 875)];
  [mover moveWindowRect:CGRectMake(0, 25, 720, 875) frameOfScreen:kFrame visibleFrameOfScreen:kVisibleFrame
 frontmostWindowElement:window action:kSpectacleWindowActionLeftHalf];
  XCTAssertEqual(window.setRectCount, 0u);
}

- (void)testBestEffortMoverWorksOnSecondaryDisplaysAbove
{
  // Display above the primary: Cocoa (0, 900, 1440, 875) == AX (0, -875, 1440, 875).
  SpectacleBestEffortWindowMover *mover = [SpectacleBestEffortWindowMover new];
  SpectacleFakeWindowElement *window = [[SpectacleFakeWindowElement alloc] initWithRect:CGRectMake(0, -400, 720, 600)];
  [mover moveWindowRect:CGRectMake(0, -400, 720, 600) frameOfScreen:CGRectMake(0, 900, 1440, 900)
   visibleFrameOfScreen:CGRectMake(0, 900, 1440, 875)
 frontmostWindowElement:window action:kSpectacleWindowActionBottomHalf];
  SPTAssertRectEqual(window.rect, CGRectMake(0, -600, 720, 600));
}

- (void)testTheDefaultChainPlacesWindowsExactly
{
  id<SpectacleWindowMover> mover = [SpectacleWindowPositionManager defaultWindowMover];
  SpectacleFakeWindowElement *window = [[SpectacleFakeWindowElement alloc] initWithRect:CGRectMake(300, 300, 400, 300)];
  [mover moveWindowRect:CGRectMake(0, 25, 1440, 875) frameOfScreen:kFrame visibleFrameOfScreen:kVisibleFrame
 frontmostWindowElement:window action:kSpectacleWindowActionFullscreen];
  SPTAssertRectEqual(window.rect, CGRectMake(0, 25, 1440, 875));
}

@end
