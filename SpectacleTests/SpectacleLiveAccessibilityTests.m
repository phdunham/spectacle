#import "SpectacleTestSupport.h"

#import "SpectacleAccessibilityElement.h"
#import "SpectacleScreenDetector.h"
#import "SpectacleWindowPositionCalculator.h"
#import "SpectacleWindowPositionManager.h"

// Opt-in tests that move a real window of a real application (TextEdit) through the Accessibility
// API, exactly like the keyboard shortcuts do. They are skipped unless:
//
//   1. the test host (build/DerivedData/.../Spectacle.app) has Accessibility access, and
//   2. SPECTACLE_LIVE_TESTS=1 is set, e.g.
//        TEST_RUNNER_SPECTACLE_LIVE_TESTS=1 xcodebuild test -scheme Spectacle ...
//
// They open a new, empty TextEdit document and close it again without saving.
@interface SpectacleLiveAccessibilityTests : XCTestCase
@end

@implementation SpectacleLiveAccessibilityTests
{
  NSRunningApplication *_textEdit;
  SpectacleAccessibilityElement *_window;
  SpectacleWindowPositionManager *_manager;
  NSUInteger _failures;
}

- (void)setUp
{
  [super setUp];
  if (![NSProcessInfo.processInfo.environment[@"SPECTACLE_LIVE_TESTS"] isEqualToString:@"1"]) {
    XCTSkip(@"Set SPECTACLE_LIVE_TESTS=1 to run tests against a real TextEdit window");
  }
  if (!AXIsProcessTrustedWithOptions(NULL)) {
    XCTSkip(@"The test host does not have Accessibility access (System Settings > Privacy & Security > Accessibility)");
  }
  NSURL *textEditURL = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:@"com.apple.TextEdit"];
  if (!textEditURL) {
    XCTSkip(@"TextEdit is not installed");
  }
  XCTestExpectation *launched = [self expectationWithDescription:@"TextEdit launched"];
  NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
  configuration.activates = YES;
  [NSWorkspace.sharedWorkspace openApplicationAtURL:textEditURL configuration:configuration completionHandler:^(NSRunningApplication *app, NSError *error) {
    self->_textEdit = app;
    [launched fulfill];
  }];
  [self waitForExpectations:@[launched] timeout:20];
  XCTAssertNotNil(_textEdit);
  NSAppleScript *script = [[NSAppleScript alloc] initWithSource:@"tell application \"TextEdit\" to make new document"];
  [script executeAndReturnError:nil];
  _window = [self waitForFocusedWindowOfProcess:_textEdit.processIdentifier];
  if (!_window) {
    XCTSkip(@"Could not get TextEdit's focused window (is Automation access for TextEdit granted?)");
  }
  [_window setRectOfElement:CGRectMake(200, 200, 500, 400)];
  __weak typeof(self) weakSelf = self;
  _manager = [[SpectacleWindowPositionManager alloc] initWithScreenDetector:[SpectacleScreenDetector new]
                                                   windowPositionCalculator:[[SpectacleWindowPositionCalculator alloc] initWithErrorHandler:^(NSString *message) {
                                                     XCTFail(@"%@", message);
                                                   }]
                                                            sharedWorkspace:NSWorkspace.sharedWorkspace
                                                            failureFeedback:^{ typeof(self) s = weakSelf; if (s) { s->_failures++; } }
                                                                windowMover:[SpectacleWindowPositionManager defaultWindowMover]];
}

- (void)tearDown
{
  if (_textEdit) {
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:@"tell application \"TextEdit\" to close front document saving no"];
    [script executeAndReturnError:nil];
  }
  [super tearDown];
}

- (SpectacleAccessibilityElement *)waitForFocusedWindowOfProcess:(pid_t)pid
{
  for (int attempt = 0; attempt < 50; attempt++) {
    AXUIElementRef application = AXUIElementCreateApplication(pid);
    CFTypeRef window = NULL;
    AXError error = AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute, &window);
    CFRelease(application);
    if (error == kAXErrorSuccess && window) {
      SpectacleAccessibilityElement *element = [SpectacleAccessibilityElement new];
      [element setValue:(__bridge id)window forKey:@"underlyingElement"];
      CFRelease(window);
      return element;
    }
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }
  return nil;
}

- (NSScreen *)screenOfWindow
{
  CGRect rect = [SpectacleAccessibilityElement normalizeCoordinatesOfRect:[_window rectOfElement] frameOfScreen:CGRectNull];
  for (NSScreen *screen in NSScreen.screens) {
    if (CGRectContainsPoint(NSRectToCGRect(screen.frame), CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect)))) {
      return screen;
    }
  }
  return NSScreen.screens.firstObject;
}

- (void)assertWindowIsAt:(CGRect)cocoaRect action:(NSString *)action
{
  CGRect expected = [SpectacleAccessibilityElement normalizeCoordinatesOfRect:cocoaRect frameOfScreen:CGRectNull];
  CGRect actual = [_window rectOfElement];
  // TextEdit has no size increments, so the window must land within a point of the target.
  XCTAssertEqualWithAccuracy(actual.origin.x, expected.origin.x, 1.0, @"%@: %@ vs %@", action, NSStringFromRect(actual), NSStringFromRect(expected));
  XCTAssertEqualWithAccuracy(actual.origin.y, expected.origin.y, 1.0, @"%@: %@ vs %@", action, NSStringFromRect(actual), NSStringFromRect(expected));
  XCTAssertEqualWithAccuracy(actual.size.width, expected.size.width, 1.0, @"%@: %@ vs %@", action, NSStringFromRect(actual), NSStringFromRect(expected));
  XCTAssertEqualWithAccuracy(actual.size.height, expected.size.height, 1.0, @"%@: %@ vs %@", action, NSStringFromRect(actual), NSStringFromRect(expected));
}

- (void)testFullscreenLeftHalfAndRightHalfOnARealWindow
{
  NSScreen *screen = [self screenOfWindow];
  CGRect v = NSRectToCGRect(screen.visibleFrame);
  CGFloat half = floor(v.size.width / 2.0);

  [_manager moveFrontmostWindowElement:_window action:kSpectacleWindowActionFullscreen screens:NSScreen.screens mainScreen:screen];
  [self assertWindowIsAt:v action:@"fullscreen"];

  [_manager moveFrontmostWindowElement:_window action:kSpectacleWindowActionLeftHalf screens:NSScreen.screens mainScreen:screen];
  [self assertWindowIsAt:CGRectMake(v.origin.x, v.origin.y, half, v.size.height) action:@"left half"];

  [_manager moveFrontmostWindowElement:_window action:kSpectacleWindowActionRightHalf screens:NSScreen.screens mainScreen:screen];
  [self assertWindowIsAt:CGRectMake(v.origin.x + half, v.origin.y, half, v.size.height) action:@"right half"];

  [_manager moveFrontmostWindowElement:_window action:kSpectacleWindowActionTopHalf screens:NSScreen.screens mainScreen:screen];
  CGFloat halfHeight = floor(v.size.height / 2.0);
  [self assertWindowIsAt:CGRectMake(v.origin.x, v.origin.y + halfHeight + fmod(v.size.height, 2.0), v.size.width, halfHeight) action:@"top half"];
  XCTAssertEqual(_failures, 0u);
}

@end
