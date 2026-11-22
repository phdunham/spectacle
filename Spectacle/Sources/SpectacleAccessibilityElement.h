#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

@interface SpectacleAccessibilityElement : NSObject

+ (SpectacleAccessibilityElement *)frontmostApplicationElement;
+ (SpectacleAccessibilityElement *)frontmostWindowElement;

- (SpectacleAccessibilityElement *)elementWithAttribute:(CFStringRef)attribute;

- (NSString *)stringValueOfAttribute:(CFStringRef)attribute;

- (AXValueRef)valueOfAttribute:(CFStringRef)attribute type:(AXValueType)type;
- (void)setValue:(AXValueRef)value forAttribute:(CFStringRef)attribute;

- (CGRect)rectOfElement;
- (void)setRectOfElement:(CGRect)rect;

+ (CGRect)normalizeCoordinatesOfRect:(CGRect)rect frameOfScreen:(CGRect)frameOfScreen;

/// The frame of the primary screen (the one containing the menu bar), in Cocoa coordinates.
+ (CGRect)frameOfPrimaryScreen;

/// Overrides the primary screen frame used for coordinate conversion. Pass CGRectNull to use the
/// real primary screen again. Intended for unit tests.
+ (void)setPrimaryScreenFrameOverride:(CGRect)frame;

- (BOOL)isSheet;
- (BOOL)isSystemDialog;

@end
