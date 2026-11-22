#import "SpectacleFilledButton.h"

@implementation SpectacleFilledButton

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
  _fillColor = NSColor.controlAccentColor;
  _titleColor = NSColor.whiteColor;
  self.bordered = NO;
  self.clipsToBounds = YES;
  self.font = [NSFont systemFontOfSize:NSFont.systemFontSize weight:NSFontWeightSemibold];
  [self updateAttributedTitle];
}

- (void)setFillColor:(NSColor *)fillColor
{
  _fillColor = fillColor;
  self.needsDisplay = YES;
}

- (void)setTitleColor:(NSColor *)titleColor
{
  _titleColor = titleColor;
  [self updateAttributedTitle];
}

- (void)setTitle:(NSString *)title
{
  [super setTitle:title];
  [self updateAttributedTitle];
}

- (void)setFont:(NSFont *)font
{
  [super setFont:font];
  [self updateAttributedTitle];
}

- (void)updateAttributedTitle
{
  NSString *title = self.title ?: @"";
  NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
  paragraphStyle.alignment = NSTextAlignmentCenter;
  NSDictionary *attributes = @{
    NSForegroundColorAttributeName: self.titleColor ?: NSColor.whiteColor,
    NSFontAttributeName: self.font ?: [NSFont systemFontOfSize:NSFont.systemFontSize],
    NSParagraphStyleAttributeName: paragraphStyle,
  };
  super.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:attributes];
}

- (NSRect)fillRect
{
  NSRect bounds = self.bounds;
  CGFloat height = MIN(NSHeight(bounds) - 2.0, 32.0);
  return NSMakeRect(NSMinX(bounds) + 1.0, NSMidY(bounds) - height / 2.0, NSWidth(bounds) - 2.0, height);
}

- (void)drawRect:(NSRect)dirtyRect
{
  NSColor *fill = self.fillColor ?: NSColor.controlAccentColor;
  if (self.isHighlighted) {
    fill = [fill blendedColorWithFraction:0.25 ofColor:NSColor.blackColor] ?: fill;
  } else if (!self.isEnabled) {
    fill = [fill colorWithAlphaComponent:0.4];
  }
  [fill setFill];
  [[NSBezierPath bezierPathWithRoundedRect:[self fillRect] xRadius:8.0 yRadius:8.0] fill];
  [super drawRect:dirtyRect];
}

- (void)viewDidChangeEffectiveAppearance
{
  [super viewDidChangeEffectiveAppearance];
  self.needsDisplay = YES;
}

@end
