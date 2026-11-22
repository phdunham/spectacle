#import "SpectacleTestSupport.h"

#import "SpectacleFilledButton.h"

// Checks that the accessibility-permission dialog (in Spectacle.xib) is legible in both Light and
// Dark Mode. The dialog is loaded from the real nib, rendered off screen with each appearance and
// measured, so a change that makes a control blend into the background fails here.

@interface SpectacleNibOwner : NSObject
@property (nonatomic, strong) id delegate;
- (void)terminate:(id)sender;
@end

@implementation SpectacleNibOwner
- (void)terminate:(id)sender {}
@end

@interface SpectacleAppearanceTests : XCTestCase
@end

@implementation SpectacleAppearanceTests
{
  NSArray *_topLevelObjects;
  NSWindow *_dialog;
}

- (void)setUp
{
  [super setUp];
  NSBundle *appBundle = [NSBundle bundleForClass:NSClassFromString(@"SpectacleAppDelegate")];
  NSNib *nib = [[NSNib alloc] initWithNibNamed:@"Spectacle" bundle:appBundle];
  XCTAssertNotNil(nib);
  NSArray *topLevelObjects = nil;
  XCTAssertTrue([nib instantiateWithOwner:[SpectacleNibOwner new] topLevelObjects:&topLevelObjects]);
  _topLevelObjects = topLevelObjects;
  for (id object in topLevelObjects) {
    if ([object isKindOfClass:[NSWindow class]] && [self button:@"Open System Settings" inView:[object contentView]]) {
      _dialog = object;
    }
  }
  XCTAssertNotNil(_dialog, @"the accessibility dialog was not found in Spectacle.xib");
}

#pragma mark - Helpers

- (NSButton *)button:(NSString *)title inView:(NSView *)view
{
  for (NSView *subview in view.subviews) {
    if ([subview isKindOfClass:[NSButton class]] && [((NSButton *)subview).title isEqualToString:title]) {
      return (NSButton *)subview;
    }
    NSButton *found = [self button:title inView:subview];
    if (found) {
      return found;
    }
  }
  return nil;
}

- (NSArray<NSTextField *> *)labels
{
  NSMutableArray *labels = [NSMutableArray new];
  for (NSView *subview in _dialog.contentView.subviews) {
    if ([subview isKindOfClass:[NSTextField class]] && ((NSTextField *)subview).stringValue.length > 0) {
      [labels addObject:subview];
    }
  }
  return labels;
}

static NSAppearance *appearance(NSAppearanceName name)
{
  return [NSAppearance appearanceNamed:name];
}

static CGFloat relativeLuminance(NSColor *color)
{
  NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
  CGFloat components[3] = {rgb.redComponent, rgb.greenComponent, rgb.blueComponent};
  for (int i = 0; i < 3; i++) {
    CGFloat c = components[i];
    components[i] = c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
  }
  return 0.2126 * components[0] + 0.7152 * components[1] + 0.0722 * components[2];
}

/// WCAG contrast ratio, 1 (none) ... 21 (black on white).
static CGFloat contrastRatio(NSColor *a, NSColor *b)
{
  CGFloat la = relativeLuminance(a);
  CGFloat lb = relativeLuminance(b);
  return (MAX(la, lb) + 0.05) / (MIN(la, lb) + 0.05);
}

/// Resolves a (dynamic) color for an appearance, as AppKit would when drawing.
static NSColor *resolve(NSColor *color, NSAppearance *appearance)
{
  __block NSColor *resolved = nil;
  [appearance performAsCurrentDrawingAppearance:^{
    resolved = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
  }];
  return resolved;
}

#pragma mark - Structure

- (void)testOpenSystemSettingsIsTheDefaultButton
{
  // The default button is drawn in the accent color, which stands out in both appearances,
  // and Return triggers it.
  NSButton *open = [self button:@"Open System Settings" inView:_dialog.contentView];
  XCTAssertEqualObjects(open.keyEquivalent, @"\r");
}

- (void)testEscapeQuits
{
  NSButton *quit = [self button:@"Quit Spectacle" inView:_dialog.contentView];
  XCTAssertNotNil(quit);
  XCTAssertEqualObjects(quit.keyEquivalent, @"\e");
  XCTAssertEqual(quit.action, @selector(terminate:));
}

- (void)testButtonsDoNotTouch
{
  // The buttons used to share an edge, which made them read as one dark block in Dark Mode.
  NSButton *open = [self button:@"Open System Settings" inView:_dialog.contentView];
  NSButton *quit = [self button:@"Quit Spectacle" inView:_dialog.contentView];
  XCTAssertGreaterThanOrEqual(NSMinX(quit.frame) - NSMaxX(open.frame), 8.0);
}

- (void)testButtonsAreCenteredInTheDialog
{
  NSButton *open = [self button:@"Open System Settings" inView:_dialog.contentView];
  NSButton *quit = [self button:@"Quit Spectacle" inView:_dialog.contentView];
  CGFloat groupMidX = (NSMinX(open.frame) + NSMaxX(quit.frame)) / 2.0;
  XCTAssertEqualWithAccuracy(groupMidX, NSMidX(_dialog.contentView.bounds), 2.0);
}

- (void)testDialogDoesNotForceAnAppearance
{
  // Forcing Aqua or Dark Aqua would ignore the user's system setting.
  XCTAssertNil(_dialog.appearance);
  for (NSView *view in _dialog.contentView.subviews) {
    XCTAssertNil(view.appearance, @"%@ forces an appearance", view);
  }
}

- (void)testLabelsUseDynamicSystemColors
{
  NSArray<NSTextField *> *labels = [self labels];
  XCTAssertGreaterThanOrEqual(labels.count, 2u);
  for (NSTextField *label in labels) {
    XCTAssertEqual(label.textColor.type, NSColorTypeCatalog,
                   @"\"%@\" uses a fixed color instead of a system color", label.stringValue);
  }
}

#pragma mark - Contrast in Light and Dark Mode

- (void)testLabelTextIsReadableInLightAndDarkMode
{
  for (NSAppearanceName name in @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]) {
    NSColor *background = resolve(NSColor.windowBackgroundColor, appearance(name));
    for (NSTextField *label in [self labels]) {
      CGFloat ratio = contrastRatio(resolve(label.textColor, appearance(name)), background);
      XCTAssertGreaterThanOrEqual(ratio, 4.5, @"\"%@\" in %@ has contrast %.2f", label.stringValue, name, ratio);
    }
  }
}

- (void)testTheDefaultButtonAccentColorStandsOutInLightAndDarkMode
{
  // The default button is filled with the accent color; it must be clearly distinguishable from
  // the window background, which is what was missing in the original Dark Mode screenshot.
  for (NSAppearanceName name in @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]) {
    NSColor *background = resolve(NSColor.windowBackgroundColor, appearance(name));
    NSColor *accent = resolve(NSColor.controlAccentColor, appearance(name));
    CGFloat ratio = contrastRatio(accent, background);
    XCTAssertGreaterThanOrEqual(ratio, 2.0, @"accent vs background in %@ has contrast %.2f", name, ratio);
  }
}

/// Draws a button (in its own coordinates) into a bitmap under the given appearance.
static NSBitmapImageRep *renderButton(NSButton *button, NSAppearanceName name)
{
  NSSize size = button.bounds.size;
  NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                     pixelsWide:(NSInteger)size.width
                                                                     pixelsHigh:(NSInteger)size.height
                                                                  bitsPerSample:8
                                                                samplesPerPixel:4
                                                                       hasAlpha:YES
                                                                       isPlanar:NO
                                                                 colorSpaceName:NSDeviceRGBColorSpace
                                                                    bytesPerRow:0
                                                                   bitsPerPixel:0];
  NSAppearance *previous = button.appearance;
  button.appearance = appearance(name);
  [button.appearance performAsCurrentDrawingAppearance:^{
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    // Paint the window background first so the measurements match what the user sees.
    [NSColor.windowBackgroundColor setFill];
    NSRectFill(button.bounds);
    [button drawRect:button.bounds];
    [NSGraphicsContext.currentContext flushGraphics];
    [NSGraphicsContext restoreGraphicsState];
  }];
  button.appearance = previous;
  return bitmap;
}

static NSColor *pixel(NSBitmapImageRep *bitmap, NSInteger x, NSInteger y)
{
  return [[bitmap colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
}

- (void)testButtonsAreFilledButtonsWithDistinctColors
{
  SpectacleFilledButton *open = (SpectacleFilledButton *)[self button:@"Open System Settings" inView:_dialog.contentView];
  SpectacleFilledButton *quit = (SpectacleFilledButton *)[self button:@"Quit Spectacle" inView:_dialog.contentView];
  XCTAssertTrue([open isKindOfClass:[SpectacleFilledButton class]]);
  XCTAssertTrue([quit isKindOfClass:[SpectacleFilledButton class]]);
  XCTAssertEqualObjects(open.fillColor, NSColor.controlAccentColor);
  XCTAssertEqualObjects(quit.fillColor, NSColor.systemGrayColor);
}

- (void)testButtonFillsStandOutFromTheBackgroundInLightAndDarkMode
{
  for (NSString *title in @[@"Open System Settings", @"Quit Spectacle"]) {
    SpectacleFilledButton *button = (SpectacleFilledButton *)[self button:title inView:_dialog.contentView];
    for (NSAppearanceName name in @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]) {
      NSBitmapImageRep *bitmap = renderButton(button, name);
      // Bitmap rows run top to bottom: sample just inside the left end of the fill, away from the
      // title, and the window background in the top-left corner outside the fill.
      NSRect fill = [button fillRect];
      NSInteger midRow = (NSInteger)(bitmap.pixelsHigh / 2);
      NSColor *inside = pixel(bitmap, (NSInteger)NSMinX(fill) + 6, midRow);
      NSColor *outside = pixel(bitmap, 0, 0);
      CGFloat ratio = contrastRatio(inside, outside);
      XCTAssertGreaterThanOrEqual(ratio, 2.0, @"%@ in %@: fill %@ vs background %@ (contrast %.2f)",
                                  title, name, inside, outside, ratio);
    }
  }
}

- (void)testButtonTitlesAreReadableInLightAndDarkMode
{
  for (NSString *title in @[@"Open System Settings", @"Quit Spectacle"]) {
    SpectacleFilledButton *button = (SpectacleFilledButton *)[self button:title inView:_dialog.contentView];
    for (NSAppearanceName name in @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]) {
      NSBitmapImageRep *bitmap = renderButton(button, name);
      NSRect fill = [button fillRect];
      CGFloat fillL = relativeLuminance(pixel(bitmap, (NSInteger)NSMinX(fill) + 6, bitmap.pixelsHigh / 2));
      CGFloat brightest = 0;
      NSInteger textPixels = 0;
      for (NSInteger y = (NSInteger)(bitmap.pixelsHigh / 2) - 6; y <= (NSInteger)(bitmap.pixelsHigh / 2) + 6; y++) {
        for (NSInteger x = (NSInteger)NSMinX(fill) + 16; x < (NSInteger)NSMaxX(fill) - 16; x++) {
          CGFloat l = relativeLuminance(pixel(bitmap, x, y));
          brightest = MAX(brightest, l);
          if (l > fillL + 0.3) {
            textPixels++;
          }
        }
      }
      CGFloat ratio = (brightest + 0.05) / (fillL + 0.05);
      XCTAssertGreaterThan(textPixels, 30, @"%@ in %@: no title drawn", title, name);
      XCTAssertGreaterThanOrEqual(ratio, 2.5, @"%@ title contrast in %@ is %.2f", title, name, ratio);
    }
  }
}

- (void)testPressedButtonsLookPressed
{
  SpectacleFilledButton *open = (SpectacleFilledButton *)[self button:@"Open System Settings" inView:_dialog.contentView];
  NSInteger x = (NSInteger)NSMinX([open fillRect]) + 6;
  NSColor *normal = pixel(renderButton(open, NSAppearanceNameDarkAqua), x, (NSInteger)(NSHeight(open.bounds) / 2));
  open.highlighted = YES;
  NSColor *pressed = pixel(renderButton(open, NSAppearanceNameDarkAqua), x, (NSInteger)(NSHeight(open.bounds) / 2));
  open.highlighted = NO;
  XCTAssertLessThan(relativeLuminance(pressed), relativeLuminance(normal));
}

@end
