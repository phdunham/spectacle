#import "SpectacleAccessibilitySettingsIllustration.h"

static const CGFloat kSidebarWidth = 168.0;
static const CGFloat kSidebarRowHeight = 24.0;
static const CGFloat kGroupHeaderHeight = 46.0;
static const CGFloat kGroupRowHeight = 40.0;
static const CGFloat kGroupFooterHeight = 30.0;

/// A color with separate Light and Dark Mode values, resolved when drawing.
static NSColor *dynamicColor(NSColor *light, NSColor *dark)
{
  return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance *appearance) {
    NSAppearanceName match = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
    return [match isEqualToString:NSAppearanceNameDarkAqua] ? dark : light;
  }];
}

static NSColor *gray(CGFloat white)
{
  return [NSColor colorWithSRGBRed:white green:white blue:white alpha:1.0];
}

@implementation SpectacleAccessibilitySettingsIllustration

- (instancetype)initWithFrame:(NSRect)frameRect
{
  if (self = [super initWithFrame:frameRect]) {
    [self commonInit];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
  if (self = [super initWithCoder:coder]) {
    [self commonInit];
  }
  return self;
}

- (void)commonInit
{
  self.clipsToBounds = YES;
  self.accessibilityElement = YES;
  self.accessibilityRole = NSAccessibilityImageRole;
  self.accessibilityLabel = @"System Settings, Privacy & Security, Accessibility, with Spectacle switched on";
}

- (BOOL)isFlipped
{
  return YES;
}

- (void)viewDidChangeEffectiveAppearance
{
  [super viewDidChangeEffectiveAppearance];
  self.needsDisplay = YES;
}

#pragma mark - Colors

+ (NSColor *)windowColor
{
  return dynamicColor(gray(0.965), gray(0.118));
}

+ (NSColor *)windowBorderColor
{
  return dynamicColor(gray(0.78), gray(0.32));
}

+ (NSColor *)sidebarColor
{
  return dynamicColor(gray(0.905), gray(0.192));
}

+ (NSColor *)groupColor
{
  return dynamicColor(gray(1.0), gray(0.165));
}

+ (NSColor *)fieldColor
{
  return dynamicColor(gray(0.84), gray(0.26));
}

#pragma mark - Layout

- (NSRect)windowRect
{
  NSRect bounds = self.bounds;
  // The window runs off the bottom of the view, like a cropped screenshot.
  return NSMakeRect(NSMinX(bounds) + 10, NSMinY(bounds) + 10, NSWidth(bounds) - 20, NSHeight(bounds) + 40);
}

- (NSRect)sidebarRect
{
  NSRect window = self.windowRect;
  return NSMakeRect(NSMinX(window) + 8, NSMinY(window) + 8, kSidebarWidth, NSHeight(window) - 16);
}

- (NSRect)sidebarRowRectAtIndex:(NSUInteger)index
{
  NSRect sidebar = self.sidebarRect;
  return NSMakeRect(NSMinX(sidebar) + 8, NSMinY(sidebar) + 66 + index * kSidebarRowHeight,
                    NSWidth(sidebar) - 16, kSidebarRowHeight);
}

- (NSRect)selectedSidebarRowRect
{
  return [self sidebarRowRectAtIndex:[self sidebarItems].count - 1];
}

- (NSRect)groupRect
{
  NSRect window = self.windowRect;
  CGFloat x = NSMaxX(self.sidebarRect) + 18;
  return NSMakeRect(x, NSMinY(window) + 52, NSMaxX(window) - 18 - x,
                    kGroupHeaderHeight + kGroupRowHeight + kGroupFooterHeight);
}

- (NSRect)spectacleRowRect
{
  NSRect group = self.groupRect;
  return NSMakeRect(NSMinX(group), NSMinY(group) + kGroupHeaderHeight, NSWidth(group), kGroupRowHeight);
}

- (NSRect)switchRect
{
  NSRect row = self.spectacleRowRect;
  return NSMakeRect(NSMaxX(row) - 14 - 32, NSMidY(row) - 9, 32, 18);
}

/// Title, SF Symbol and icon color of the sidebar rows; the last one is selected.
- (NSArray<NSArray *> *)sidebarItems
{
  return @[
    @[@"General", @"gearshape.fill", NSColor.systemGrayColor],
    @[@"Appearance", @"circle.lefthalf.filled", dynamicColor(gray(0.15), gray(0.35))],
    @[@"Accessibility", @"accessibility", NSColor.systemBlueColor],
    @[@"Control Center", @"switch.2", NSColor.systemGrayColor],
    @[@"Desktop & Dock", @"dock.rectangle", dynamicColor(gray(0.15), gray(0.35))],
    @[@"Privacy & Security", @"hand.raised.fill", NSColor.systemBlueColor],
  ];
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect
{
  NSRect window = self.windowRect;

  // Window with a soft shadow.
  NSBezierPath *windowPath = [NSBezierPath bezierPathWithRoundedRect:window xRadius:16 yRadius:16];
  [NSGraphicsContext saveGraphicsState];
  NSShadow *shadow = [NSShadow new];
  shadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.35];
  shadow.shadowBlurRadius = 8;
  shadow.shadowOffset = NSMakeSize(0, -2);
  [shadow set];
  [[[self class] windowColor] setFill];
  [windowPath fill];
  [NSGraphicsContext restoreGraphicsState];
  [[[self class] windowBorderColor] setStroke];
  windowPath.lineWidth = 1;
  [windowPath stroke];

  [self drawSidebar];
  [self drawContent];
}

- (void)drawSidebar
{
  NSRect sidebar = self.sidebarRect;
  [[[self class] sidebarColor] setFill];
  [[NSBezierPath bezierPathWithRoundedRect:sidebar xRadius:12 yRadius:12] fill];

  // Traffic lights.
  NSArray<NSColor *> *lights = @[
    [NSColor colorWithSRGBRed:1.0 green:0.37 blue:0.34 alpha:1],
    [NSColor colorWithSRGBRed:1.0 green:0.74 blue:0.18 alpha:1],
    [NSColor colorWithSRGBRed:0.16 green:0.79 blue:0.25 alpha:1],
  ];
  for (NSUInteger i = 0; i < lights.count; i++) {
    [lights[i] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(NSMinX(sidebar) + 12 + i * 20, NSMinY(sidebar) + 12, 12, 12)] fill];
  }

  // Search field.
  NSRect search = NSMakeRect(NSMinX(sidebar) + 10, NSMinY(sidebar) + 34, NSWidth(sidebar) - 20, 24);
  [[[self class] fieldColor] setFill];
  [[NSBezierPath bezierPathWithRoundedRect:search xRadius:12 yRadius:12] fill];
  [self drawSymbol:@"magnifyingglass" color:NSColor.secondaryLabelColor
            inRect:NSMakeRect(NSMinX(search) + 8, NSMidY(search) - 6, 12, 12)];
  [self drawText:@"Search" font:[NSFont systemFontOfSize:12] color:NSColor.secondaryLabelColor
         atPoint:NSMakePoint(NSMinX(search) + 25, NSMidY(search) - 8)];

  // Rows.
  NSArray<NSArray *> *items = [self sidebarItems];
  for (NSUInteger i = 0; i < items.count; i++) {
    NSRect row = [self sidebarRowRectAtIndex:i];
    BOOL selected = (i == items.count - 1);
    if (selected) {
      [NSColor.controlAccentColor setFill];
      [[NSBezierPath bezierPathWithRoundedRect:row xRadius:7 yRadius:7] fill];
    }
    NSRect icon = NSMakeRect(NSMinX(row) + 6, NSMidY(row) - 9, 18, 18);
    [(NSColor *)items[i][2] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:icon xRadius:5 yRadius:5] fill];
    [self drawSymbol:items[i][1] color:NSColor.whiteColor inRect:NSInsetRect(icon, 3.5, 3.5)];
    [self drawText:items[i][0]
              font:[NSFont systemFontOfSize:13 weight:selected ? NSFontWeightMedium : NSFontWeightRegular]
             color:selected ? NSColor.whiteColor : NSColor.labelColor
           atPoint:NSMakePoint(NSMinX(icon) + 26, NSMidY(row) - 8.5)];
  }
}

- (void)drawContent
{
  NSRect window = self.windowRect;
  CGFloat x = NSMaxX(self.sidebarRect) + 18;

  // Toolbar: back/forward and the page title.
  [self drawSymbol:@"chevron.left" color:NSColor.labelColor inRect:NSMakeRect(x, NSMinY(window) + 20, 9, 14)];
  [self drawSymbol:@"chevron.right" color:NSColor.tertiaryLabelColor inRect:NSMakeRect(x + 22, NSMinY(window) + 20, 9, 14)];
  [self drawText:@"Accessibility" font:[NSFont systemFontOfSize:15 weight:NSFontWeightBold] color:NSColor.labelColor
         atPoint:NSMakePoint(x + 46, NSMinY(window) + 17)];

  // Grouped list.
  NSRect group = self.groupRect;
  [[[self class] groupColor] setFill];
  [[NSBezierPath bezierPathWithRoundedRect:group xRadius:10 yRadius:10] fill];
  [self drawText:@"Allow the applications below to control your computer."
            font:[NSFont systemFontOfSize:12]
           color:NSColor.secondaryLabelColor
          inRect:NSMakeRect(NSMinX(group) + 14, NSMinY(group) + 8, NSWidth(group) - 28, kGroupHeaderHeight - 10)];

  NSRect row = self.spectacleRowRect;
  [self drawSeparatorAtY:NSMinY(row) fromX:NSMinX(row) + 14 toX:NSMaxX(row) - 14];
  NSImage *icon = [NSImage imageNamed:NSImageNameApplicationIcon];
  [icon drawInRect:NSMakeRect(NSMinX(row) + 12, NSMidY(row) - 12, 24, 24)
          fromRect:NSZeroRect
         operation:NSCompositingOperationSourceOver
          fraction:1.0
    respectFlipped:YES
             hints:nil];
  [self drawText:@"Spectacle" font:[NSFont systemFontOfSize:13] color:NSColor.labelColor
         atPoint:NSMakePoint(NSMinX(row) + 46, NSMidY(row) - 8.5)];

  // Switch, on.
  NSRect toggle = self.switchRect;
  [NSColor.controlAccentColor setFill];
  [[NSBezierPath bezierPathWithRoundedRect:toggle xRadius:9 yRadius:9] fill];
  [NSColor.whiteColor setFill];
  [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(NSMaxX(toggle) - 17, NSMinY(toggle) + 1, 16, 16)] fill];

  // Footer with + and − buttons.
  CGFloat footerY = NSMaxY(row);
  [self drawSeparatorAtY:footerY fromX:NSMinX(group) + 14 toX:NSMaxX(group) - 14];
  [self drawText:@"+" font:[NSFont systemFontOfSize:15] color:NSColor.secondaryLabelColor
         atPoint:NSMakePoint(NSMinX(group) + 14, footerY + 5)];
  [self drawText:@"−" font:[NSFont systemFontOfSize:15] color:NSColor.tertiaryLabelColor
         atPoint:NSMakePoint(NSMinX(group) + 38, footerY + 5)];
}

#pragma mark - Drawing helpers

- (void)drawSeparatorAtY:(CGFloat)y fromX:(CGFloat)fromX toX:(CGFloat)toX
{
  [NSColor.separatorColor setFill];
  NSRectFillUsingOperation(NSMakeRect(fromX, y, toX - fromX, 1), NSCompositingOperationSourceOver);
}

- (void)drawText:(NSString *)text font:(NSFont *)font color:(NSColor *)color atPoint:(NSPoint)point
{
  [text drawAtPoint:point withAttributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: color}];
}

- (void)drawText:(NSString *)text font:(NSFont *)font color:(NSColor *)color inRect:(NSRect)rect
{
  [text drawInRect:rect withAttributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: color}];
}

- (void)drawSymbol:(NSString *)name color:(NSColor *)color inRect:(NSRect)rect
{
  NSImage *symbol = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
  if (!symbol) {
    return;
  }
  NSImageSymbolConfiguration *configuration = [NSImageSymbolConfiguration configurationWithPaletteColors:@[color]];
  symbol = [symbol imageWithSymbolConfiguration:configuration] ?: symbol;
  // Fit the symbol inside the rect, keeping its aspect ratio.
  NSSize size = symbol.size;
  CGFloat scale = MIN(NSWidth(rect) / MAX(size.width, 1), NSHeight(rect) / MAX(size.height, 1));
  NSRect target = NSMakeRect(NSMidX(rect) - size.width * scale / 2, NSMidY(rect) - size.height * scale / 2,
                             size.width * scale, size.height * scale);
  [symbol drawInRect:target fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0
      respectFlipped:YES hints:nil];
}

@end
