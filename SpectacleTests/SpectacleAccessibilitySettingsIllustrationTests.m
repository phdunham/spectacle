#import "SpectacleTestSupport.h"

#import "SpectacleAccessibilitySettingsIllustration.h"

@interface SpectacleIllustrationNibOwner : NSObject
@property (nonatomic, strong) id delegate;
- (void)terminate:(id)sender;
@end

@implementation SpectacleIllustrationNibOwner
- (void)terminate:(id)sender {}
- (void)orderFrontStandardAboutPanel:(id)sender {}
@end

// The picture of System Settings in the accessibility dialog is drawn in code so it can follow
// Light and Dark Mode. These tests render it in both appearances and measure the result.
@interface SpectacleAccessibilitySettingsIllustrationTests : XCTestCase
@end

@implementation SpectacleAccessibilitySettingsIllustrationTests
{
  SpectacleAccessibilitySettingsIllustration *_illustration;
}

- (void)setUp
{
  [super setUp];
  _illustration = [[SpectacleAccessibilitySettingsIllustration alloc] initWithFrame:NSMakeRect(0, 0, 590, 232)];
}

static CGFloat luminance(NSColor *color)
{
  NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
  CGFloat c[3] = {rgb.redComponent, rgb.greenComponent, rgb.blueComponent};
  for (int i = 0; i < 3; i++) {
    c[i] = c[i] <= 0.03928 ? c[i] / 12.92 : pow((c[i] + 0.055) / 1.055, 2.4);
  }
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

- (NSBitmapImageRep *)render:(NSAppearanceName)name
{
  _illustration.appearance = [NSAppearance appearanceNamed:name];
  NSBitmapImageRep *bitmap = [_illustration bitmapImageRepForCachingDisplayInRect:_illustration.bounds];
  [_illustration cacheDisplayInRect:_illustration.bounds toBitmapImageRep:bitmap];
  return bitmap;
}

/// The view is flipped, so view coordinates map straight onto bitmap rows (times the scale).
static NSColor *colorAt(NSBitmapImageRep *bitmap, NSView *view, NSPoint point)
{
  CGFloat scale = bitmap.pixelsWide / NSWidth(view.bounds);
  return [[bitmap colorAtX:(NSInteger)(point.x * scale) y:(NSInteger)(point.y * scale)]
          colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
}

/// Average luminance over a rect, ignoring nothing (text and icons included).
static CGFloat averageLuminance(NSBitmapImageRep *bitmap, NSView *view, NSRect rect)
{
  CGFloat total = 0;
  NSInteger count = 0;
  for (CGFloat y = NSMinY(rect); y < NSMaxY(rect); y += 2) {
    for (CGFloat x = NSMinX(rect); x < NSMaxX(rect); x += 2) {
      total += luminance(colorAt(bitmap, view, NSMakePoint(x, y)));
      count++;
    }
  }
  return count ? total / count : 0;
}

- (NSRect)visibleWindowArea
{
  return NSIntersectionRect(NSInsetRect(_illustration.windowRect, 20, 20), _illustration.bounds);
}

#pragma mark - Light and Dark Mode

- (void)testItIsLightInLightMode
{
  NSBitmapImageRep *bitmap = [self render:NSAppearanceNameAqua];
  XCTAssertGreaterThan(averageLuminance(bitmap, _illustration, [self visibleWindowArea]), 0.6);
  XCTAssertGreaterThan(averageLuminance(bitmap, _illustration, NSInsetRect(_illustration.sidebarRect, 10, 70)), 0.5);
}

- (void)testItIsDarkInDarkMode
{
  NSBitmapImageRep *bitmap = [self render:NSAppearanceNameDarkAqua];
  XCTAssertLessThan(averageLuminance(bitmap, _illustration, [self visibleWindowArea]), 0.12);
  XCTAssertLessThan(averageLuminance(bitmap, _illustration, NSInsetRect(_illustration.sidebarRect, 10, 70)), 0.15);
}

- (void)testTheSameViewSwitchesBetweenLightAndDark
{
  // Switching appearance on an existing view (as when the user changes the system setting while
  // the dialog is open) must change what it draws.
  CGFloat light = averageLuminance([self render:NSAppearanceNameAqua], _illustration, [self visibleWindowArea]);
  CGFloat dark = averageLuminance([self render:NSAppearanceNameDarkAqua], _illustration, [self visibleWindowArea]);
  CGFloat lightAgain = averageLuminance([self render:NSAppearanceNameAqua], _illustration, [self visibleWindowArea]);
  XCTAssertGreaterThan(light - dark, 0.4);
  XCTAssertEqualWithAccuracy(light, lightAgain, 0.001);
}

- (void)testTheSelectedRowAndSwitchUseTheAccentColorInBothModes
{
  for (NSAppearanceName name in @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]) {
    NSBitmapImageRep *bitmap = [self render:name];
    __block NSColor *accent = nil;
    [[NSAppearance appearanceNamed:name] performAsCurrentDrawingAppearance:^{
      accent = [NSColor.controlAccentColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    }];
    NSRect row = _illustration.selectedSidebarRowRect;
    NSRect toggle = _illustration.switchRect;
    for (NSValue *value in @[[NSValue valueWithPoint:NSMakePoint(NSMaxX(row) - 6, NSMidY(row))],
                             [NSValue valueWithPoint:NSMakePoint(NSMinX(toggle) + 5, NSMidY(toggle))]]) {
      NSColor *color = colorAt(bitmap, _illustration, value.pointValue);
      XCTAssertEqualWithAccuracy(color.redComponent, accent.redComponent, 0.06, @"%@ at %@", name, NSStringFromPoint(value.pointValue));
      XCTAssertEqualWithAccuracy(color.greenComponent, accent.greenComponent, 0.06, @"%@ at %@", name, NSStringFromPoint(value.pointValue));
      XCTAssertEqualWithAccuracy(color.blueComponent, accent.blueComponent, 0.06, @"%@ at %@", name, NSStringFromPoint(value.pointValue));
    }
  }
}

- (void)testTheSpectacleRowHasTextAndAnIconInBothModes
{
  for (NSAppearanceName name in @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]) {
    NSBitmapImageRep *bitmap = [self render:name];
    NSRect row = _illustration.spectacleRowRect;
    NSColor *background = colorAt(bitmap, _illustration, NSMakePoint(NSMaxX(row) - 80, NSMidY(row)));
    CGFloat backgroundL = luminance(background);
    NSUInteger contrasting = 0;
    // Icon and "Spectacle" label occupy the left part of the row.
    for (CGFloat y = NSMinY(row) + 8; y < NSMaxY(row) - 8; y += 1) {
      for (CGFloat x = NSMinX(row) + 12; x < NSMinX(row) + 120; x += 1) {
        CGFloat l = luminance(colorAt(bitmap, _illustration, NSMakePoint(x, y)));
        if (fabs(l - backgroundL) > 0.25) {
          contrasting++;
        }
      }
    }
    XCTAssertGreaterThan(contrasting, 150u, @"the Spectacle row looks empty in %@", name);
  }
}

- (void)testItStaysInsideItsBounds
{
  XCTAssertTrue(_illustration.clipsToBounds);
  XCTAssertTrue(NSContainsRect(_illustration.bounds, _illustration.sidebarRect) ||
                NSMinY(_illustration.sidebarRect) < NSMaxY(_illustration.bounds));
  XCTAssertTrue(NSContainsRect(_illustration.bounds, _illustration.selectedSidebarRowRect),
                @"the selected 'Privacy & Security' row must be visible");
  XCTAssertTrue(NSContainsRect(_illustration.bounds, _illustration.spectacleRowRect),
                @"the Spectacle row must be visible");
}

- (void)testItDescribesItselfToVoiceOver
{
  XCTAssertEqualObjects(_illustration.accessibilityRole, NSAccessibilityImageRole);
  XCTAssertTrue([_illustration.accessibilityLabel containsString:@"Accessibility"]);
}

- (void)testWritesSnapshotsWhenAsked
{
  // TEST_RUNNER_SPECTACLE_SNAPSHOT_DIR=/some/folder xcodebuild test ... writes PNGs of the
  // illustration in both appearances, for a visual check.
  NSString *directory = NSProcessInfo.processInfo.environment[@"SPECTACLE_SNAPSHOT_DIR"];
  if (directory.length == 0) {
    XCTSkip(@"Set SPECTACLE_SNAPSHOT_DIR to write snapshots");
  }
  for (NSAppearanceName name in @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]) {
    NSData *png = [[self render:name] representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    NSString *file = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"illustration-%@.png", name]];
    XCTAssertTrue([png writeToFile:file atomically:YES], @"%@", file);
  }
}

#pragma mark - In the dialog

- (void)testTheDialogShowsTheIllustrationBelowTheButtons
{
  NSBundle *appBundle = [NSBundle bundleForClass:NSClassFromString(@"SpectacleAppDelegate")];
  NSNib *nib = [[NSNib alloc] initWithNibNamed:@"Spectacle" bundle:appBundle];
  NSArray *topLevelObjects = nil;
  XCTAssertTrue([nib instantiateWithOwner:[SpectacleIllustrationNibOwner new] topLevelObjects:&topLevelObjects]);
  SpectacleAccessibilitySettingsIllustration *illustration = nil;
  NSButton *openButton = nil;
  for (id object in topLevelObjects) {
    if (![object isKindOfClass:[NSWindow class]]) {
      continue;
    }
    for (NSView *view in [[object contentView] subviews]) {
      if ([view isKindOfClass:[SpectacleAccessibilitySettingsIllustration class]]) {
        illustration = (id)view;
      } else if ([view isKindOfClass:[NSButton class]] && [((NSButton *)view).title isEqualToString:@"Open System Settings"]) {
        openButton = (id)view;
      }
    }
  }
  XCTAssertNotNil(illustration, @"the dialog should use the drawn illustration");
  XCTAssertNotNil(openButton);
  XCTAssertLessThanOrEqual(NSMaxY(illustration.frame), NSMinY(openButton.frame), @"the illustration overlaps the buttons");
  XCTAssertNil([NSImage imageNamed:@"Security & Privacy"], @"the old macOS 10.14 screenshot should be gone");
}

@end
