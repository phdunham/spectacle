#import "SpectacleTestSupport.h"
#import "SpectacleTestDoubles.h"

@interface SpectacleCoordinateConversionTests : XCTestCase
@end

@implementation SpectacleCoordinateConversionTests

- (void)tearDown
{
  [SpectacleAccessibilityElement setPrimaryScreenFrameOverride:CGRectNull];
  [super tearDown];
}

- (void)testConvertsBetweenCocoaAndAccessibilityCoordinatesOnThePrimaryScreen
{
  [SpectacleAccessibilityElement setPrimaryScreenFrameOverride:CGRectMake(0, 0, 1440, 900)];
  CGRect cocoa = CGRectMake(0, 70, 720, 805);
  CGRect ax = [SpectacleAccessibilityElement normalizeCoordinatesOfRect:cocoa frameOfScreen:CGRectMake(0, 0, 1440, 900)];
  SPTAssertRectEqual(ax, CGRectMake(0, 25, 720, 805));
}

- (void)testConversionIsItsOwnInverse
{
  [SpectacleAccessibilityElement setPrimaryScreenFrameOverride:CGRectMake(0, 0, 1512, 982)];
  NSArray<NSValue *> *rects = @[
    [NSValue valueWithRect:NSMakeRect(0, 0, 1512, 944)],
    [NSValue valueWithRect:NSMakeRect(-204, 982, 1920, 1043)],
    [NSValue valueWithRect:NSMakeRect(-1920, -500, 1920, 1055)],
    [NSValue valueWithRect:NSMakeRect(10.5, 20.25, 333.5, 444.75)],
  ];
  for (NSValue *value in rects) {
    CGRect rect = NSRectToCGRect(value.rectValue);
    CGRect once = [SpectacleAccessibilityElement normalizeCoordinatesOfRect:rect frameOfScreen:CGRectMake(5, 6, 7, 8)];
    CGRect twice = [SpectacleAccessibilityElement normalizeCoordinatesOfRect:once frameOfScreen:CGRectMake(5, 6, 7, 8)];
    SPTAssertRectEqual(twice, rect);
  }
}

- (void)testConversionOnlyDependsOnThePrimaryScreen
{
  // Earlier versions took the frame of the destination screen into account; the result must be
  // identical whichever screen frame is passed (including CGRectNull, used by undo/redo).
  [SpectacleAccessibilityElement setPrimaryScreenFrameOverride:CGRectMake(0, 0, 2560, 1440)];
  CGRect rect = CGRectMake(2560, 180, 960, 1055);
  CGRect expected = CGRectMake(2560, 1440 - 1235, 960, 1055);
  for (NSValue *screen in @[[NSValue valueWithRect:NSMakeRect(0, 0, 2560, 1440)],
                            [NSValue valueWithRect:NSMakeRect(2560, 180, 1920, 1080)],
                            [NSValue valueWithRect:NSRectFromCGRect(CGRectNull)]]) {
    SPTAssertRectEqual([SpectacleAccessibilityElement normalizeCoordinatesOfRect:rect
                                                                   frameOfScreen:NSRectToCGRect(screen.rectValue)], expected);
  }
}

- (void)testDisplaysAboveThePrimaryDisplayHaveNegativeAccessibilityCoordinates
{
  [SpectacleAccessibilityElement setPrimaryScreenFrameOverride:CGRectMake(0, 0, 1512, 982)];
  CGRect ax = [SpectacleAccessibilityElement normalizeCoordinatesOfRect:CGRectMake(-204, 982, 1920, 1080)
                                                          frameOfScreen:CGRectNull];
  SPTAssertRectEqual(ax, CGRectMake(-204, -1080, 1920, 1080));
}

- (void)testNullRectsAreLeftAlone
{
  [SpectacleAccessibilityElement setPrimaryScreenFrameOverride:CGRectMake(0, 0, 1440, 900)];
  XCTAssertTrue(CGRectIsNull([SpectacleAccessibilityElement normalizeCoordinatesOfRect:CGRectNull frameOfScreen:CGRectNull]));
}

- (void)testUsesTheRealPrimaryScreenWithoutAnOverride
{
  NSScreen *primary = NSScreen.screens.firstObject;
  if (!primary) {
    XCTSkip(@"No screens are attached");
  }
  XCTAssertTrue(CGRectEqualToRect([SpectacleAccessibilityElement frameOfPrimaryScreen], NSRectToCGRect(primary.frame)));
}

@end
