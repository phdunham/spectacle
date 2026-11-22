#import "SpectacleTestSupport.h"

#import "SpectaclePreferencesController.h"
#import "SpectacleShortcut.h"
#import "SpectacleShortcutRecorder.h"

// Tests of the Preferences window as loaded from SpectaclePreferencesWindow.xib, in Light and
// Dark Mode, including the macOS 14+ drawing bug where a shortcut recorder painted a huge rounded
// shape over the whole window.
@interface SpectaclePreferencesWindowTests : XCTestCase
@end

@implementation SpectaclePreferencesWindowTests
{
  SpectaclePreferencesController *_controller;
  NSWindow *_window;
}

- (void)setUp
{
  [super setUp];
  _controller = [[SpectaclePreferencesController alloc] initWithShortcutManager:nil
                                                          windowPositionManager:nil
                                                                shortcutStorage:nil];
  _window = _controller.window;
  XCTAssertNotNil(_window);
}

- (void)tearDown
{
  [_window close];
  [super tearDown];
}

static NSArray<NSView *> *allSubviews(NSView *view)
{
  NSMutableArray *views = [NSMutableArray new];
  for (NSView *subview in view.subviews) {
    [views addObject:subview];
    [views addObjectsFromArray:allSubviews(subview)];
  }
  return views;
}

- (NSArray<SpectacleShortcutRecorder *> *)recorders
{
  NSMutableArray *recorders = [NSMutableArray new];
  for (NSView *view in allSubviews(_window.contentView)) {
    if ([view isKindOfClass:[SpectacleShortcutRecorder class]]) {
      [recorders addObject:view];
    }
  }
  return recorders;
}

static CGFloat relativeLuminance(NSColor *color)
{
  NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
  CGFloat c[3] = {rgb.redComponent, rgb.greenComponent, rgb.blueComponent};
  for (int i = 0; i < 3; i++) {
    c[i] = c[i] <= 0.03928 ? c[i] / 12.92 : pow((c[i] + 0.055) / 1.055, 2.4);
  }
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

static NSColor *resolve(NSColor *color, NSAppearanceName name)
{
  __block NSColor *resolved = nil;
  [[NSAppearance appearanceNamed:name] performAsCurrentDrawingAppearance:^{
    resolved = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
  }];
  return resolved;
}

/// Draws a recorder into a bitmap much larger than the recorder, passing that whole area as the
/// dirty rect and *without* clipping, the way AppKit can on macOS 14 and later.
static NSBitmapImageRep *drawRecorderUnclipped(SpectacleShortcutRecorder *recorder, NSSize canvasSize, NSPoint origin)
{
  NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                     pixelsWide:(NSInteger)canvasSize.width
                                                                     pixelsHigh:(NSInteger)canvasSize.height
                                                                  bitsPerSample:8
                                                                samplesPerPixel:4
                                                                       hasAlpha:YES
                                                                       isPlanar:NO
                                                                 colorSpaceName:NSDeviceRGBColorSpace
                                                                    bytesPerRow:0
                                                                   bitsPerPixel:0];
  NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
  [NSGraphicsContext saveGraphicsState];
  NSGraphicsContext.currentContext = context;
  NSAffineTransform *transform = [NSAffineTransform transform];
  [transform translateXBy:origin.x yBy:origin.y];
  [transform concat];
  [recorder drawRect:NSMakeRect(-origin.x, -origin.y, canvasSize.width, canvasSize.height)];
  [context flushGraphics];
  [NSGraphicsContext restoreGraphicsState];
  return bitmap;
}

#pragma mark - Drawing regression

- (void)testTheWindowHasAllEighteenShortcutRecorders
{
  XCTAssertEqual([self recorders].count, 18u);
}

- (void)testRecordersClipToTheirBounds
{
  for (SpectacleShortcutRecorder *recorder in [self recorders]) {
    XCTAssertTrue(recorder.clipsToBounds, @"%@", recorder);
  }
  XCTAssertTrue([[SpectacleShortcutRecorder alloc] initWithFrame:NSMakeRect(0, 0, 160, 19)].clipsToBounds);
}

- (void)testARecorderNeverPaintsOutsideItsBoundsEvenWithAHugeDirtyRect
{
  SpectacleShortcutRecorder *recorder = [[SpectacleShortcutRecorder alloc] initWithFrame:NSMakeRect(0, 0, 160, 19)];
  recorder.shortcut = [[SpectacleShortcut alloc] initWithShortcutName:@"MoveToLeftHalf" shortcutKeyBinding:@"alt+cmd+left"];
  NSSize canvas = NSMakeSize(600, 400);
  NSPoint origin = NSMakePoint(220, 190);
  NSBitmapImageRep *bitmap = drawRecorderUnclipped(recorder, canvas, origin);

  NSRect recorderRectInBitmap = NSMakeRect(origin.x, canvas.height - origin.y - 19, 160, 19);
  NSUInteger paintedOutside = 0;
  NSUInteger paintedInside = 0;
  for (NSInteger y = 0; y < bitmap.pixelsHigh; y++) {
    for (NSInteger x = 0; x < bitmap.pixelsWide; x++) {
      NSUInteger pixel[4];
      [bitmap getPixel:pixel atX:x y:y];
      if (pixel[3] == 0) {
        continue;
      }
      if (NSPointInRect(NSMakePoint(x + 0.5, y + 0.5), NSInsetRect(recorderRectInBitmap, -1, -1))) {
        paintedInside++;
      } else {
        paintedOutside++;
      }
    }
  }
  XCTAssertGreaterThan(paintedInside, 160u * 19u / 2, @"the recorder should paint itself");
  XCTAssertEqual(paintedOutside, 0u, @"the recorder painted %lu pixels outside its bounds", (unsigned long)paintedOutside);
}

#pragma mark - Light and Dark Mode

- (void)testWindowDoesNotForceAnAppearance
{
  XCTAssertNil(_window.appearance);
  for (NSView *view in allSubviews(_window.contentView)) {
    XCTAssertNil(view.appearance, @"%@ forces an appearance", view);
  }
}

- (void)testLabelsAreReadableInLightAndDarkMode
{
  NSUInteger checked = 0;
  for (NSView *view in allSubviews(_window.contentView)) {
    if (![view isKindOfClass:[NSTextField class]] || view.isHidden) {
      continue;
    }
    NSTextField *label = (NSTextField *)view;
    if (label.stringValue.length == 0 || label.isEditable || label.drawsBackground) {
      continue;
    }
    for (NSAppearanceName name in @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]) {
      CGFloat text = relativeLuminance(resolve(label.textColor, name));
      CGFloat background = relativeLuminance(resolve(NSColor.windowBackgroundColor, name));
      CGFloat ratio = (MAX(text, background) + 0.05) / (MIN(text, background) + 0.05);
      // Secondary labels (e.g. the modifier legend) may be dimmer, but still clearly readable.
      XCTAssertGreaterThanOrEqual(ratio, 3.0, @"\"%@\" in %@ has contrast %.2f", label.stringValue, name, ratio);
    }
    checked++;
  }
  XCTAssertGreaterThanOrEqual(checked, 18u, @"every shortcut has a label");
}

- (void)testRecorderTextIsReadableOnItsOwnBackgroundInBothModes
{
  // The recorder draws its own light field with dark text regardless of the appearance; make
  // sure that stays readable when drawn under Dark Mode.
  for (NSAppearanceName name in @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]) {
    __block NSBitmapImageRep *bitmap = nil;
    [[NSAppearance appearanceNamed:name] performAsCurrentDrawingAppearance:^{
      SpectacleShortcutRecorder *recorder = [[SpectacleShortcutRecorder alloc] initWithFrame:NSMakeRect(0, 0, 160, 19)];
      recorder.shortcut = [[SpectacleShortcut alloc] initWithShortcutName:@"MoveToLeftHalf" shortcutKeyBinding:@"alt+cmd+left"];
      bitmap = drawRecorderUnclipped(recorder, NSMakeSize(160, 19), NSZeroPoint);
    }];
    CGFloat minL = 1, maxL = 0;
    for (NSInteger y = 4; y < 15; y++) {
      for (NSInteger x = 40; x < 120; x++) {
        CGFloat l = relativeLuminance([bitmap colorAtX:x y:y]);
        minL = MIN(minL, l);
        maxL = MAX(maxL, l);
      }
    }
    CGFloat ratio = (maxL + 0.05) / (minL + 0.05);
    XCTAssertGreaterThanOrEqual(ratio, 4.5, @"recorder text contrast in %@ is %.2f", name, ratio);
  }
}

@end
