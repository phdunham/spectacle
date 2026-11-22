#import "SpectacleAccessibilityElement.h"

#import <AppKit/AppKit.h>

@implementation SpectacleAccessibilityElement
{
  AXUIElementRef _underlyingElement;
}

- (instancetype)init
{
  if (self = [super init]) {
    _underlyingElement = NULL;
  }

  return self;
}

+ (SpectacleAccessibilityElement *)frontmostApplicationElement
{
  NSRunningApplication *frontmostApplication = [NSWorkspace sharedWorkspace].frontmostApplication;
  if (!frontmostApplication) {
    return nil;
  }
  SpectacleAccessibilityElement *frontmostApplicationElement = [SpectacleAccessibilityElement new];
  AXUIElementRef underlyingElement = AXUIElementCreateApplication(frontmostApplication.processIdentifier);
  frontmostApplicationElement.underlyingElement = underlyingElement;
  CFRelease(underlyingElement);
  return frontmostApplicationElement;
}

+ (SpectacleAccessibilityElement *)frontmostWindowElement
{
  SpectacleAccessibilityElement *frontmostApplicationElement = [SpectacleAccessibilityElement frontmostApplicationElement];
  SpectacleAccessibilityElement *frontmostWindowElement = nil;
  if (frontmostApplicationElement) {
    frontmostWindowElement = [frontmostApplicationElement elementWithAttribute:kAXFocusedWindowAttribute];
    if (!frontmostWindowElement) {
      NSLog(@"Invalid accessibility element provided, unable to determine the size and position of the window.");
    }
  } else {
    NSLog(@"Failed to find the application that currently has focus.");
  }
  return frontmostWindowElement;
}

- (SpectacleAccessibilityElement *)elementWithAttribute:(CFStringRef)attribute
{
  SpectacleAccessibilityElement *newElement = nil;
  if (_underlyingElement == NULL) {
    return nil;
  }
  CFTypeRef underlyingElement = NULL;
  AXError result = AXUIElementCopyAttributeValue(_underlyingElement, attribute, &underlyingElement);
  if (result == kAXErrorSuccess && underlyingElement != NULL && CFGetTypeID(underlyingElement) != AXUIElementGetTypeID()) {
    CFRelease(underlyingElement);
    underlyingElement = NULL;
    result = kAXErrorIllegalArgument;
  }
  if (result == kAXErrorSuccess && underlyingElement != NULL) {
    newElement = [SpectacleAccessibilityElement new];
    newElement.underlyingElement = (AXUIElementRef)underlyingElement;
    CFRelease(underlyingElement);
  } else {
    NSLog(@"Unable to obtain the accessibility element with the specified attribute: %@ (error code %d)", attribute, result);
  }
  return newElement;
}

- (NSString *)stringValueOfAttribute:(CFStringRef)attribute
{
  if (_underlyingElement == NULL || CFGetTypeID(_underlyingElement) != AXUIElementGetTypeID()) {
    return nil;
  }
  CFTypeRef value = NULL;
  AXError result = AXUIElementCopyAttributeValue(_underlyingElement, attribute, &value);
  if (result != kAXErrorSuccess || value == NULL) {
    return nil;
  }
  if (CFGetTypeID(value) != CFStringGetTypeID()) {
    CFRelease(value);
    return nil;
  }
  return CFBridgingRelease(value);
}

- (AXValueRef)valueOfAttribute:(CFStringRef)attribute type:(AXValueType)type
{
  if (_underlyingElement == NULL || CFGetTypeID(_underlyingElement) != AXUIElementGetTypeID()) {
    return NULL;
  }
  CFTypeRef value = NULL;
  AXError result = AXUIElementCopyAttributeValue(_underlyingElement, attribute, &value);
  if (result == kAXErrorSuccess && value != NULL
      && CFGetTypeID(value) == AXValueGetTypeID()
      && AXValueGetType((AXValueRef)value) == type) {
    return (AXValueRef)value;
  }
  if (value != NULL) {
    CFRelease(value);
  }
  NSLog(@"There was a problem getting the value of the specified attribute: %@ (error code %d)", attribute, result);
  return NULL;
}

- (void)setValue:(AXValueRef)value forAttribute:(CFStringRef)attribute
{
  if (_underlyingElement == NULL) {
    return;
  }
  AXError result = AXUIElementSetAttributeValue(_underlyingElement, attribute, (CFTypeRef)value);
  if (result != kAXErrorSuccess) {
    NSLog(@"There was a problem setting the value of the specified attribute: %@ (error code %d)", attribute, result);
  }
}

- (CGRect)rectOfElement
{
  AXValueRef positionValue = [self valueOfAttribute:kAXPositionAttribute type:kAXValueCGPointType];
  AXValueRef sizeValue = [self valueOfAttribute:kAXSizeAttribute type:kAXValueCGSizeType];
  CGRect result = CGRectNull;
  CGPoint position = CGPointZero;
  CGSize size = CGSizeZero;
  if (positionValue != NULL && sizeValue != NULL
      && AXValueGetValue(positionValue, kAXValueCGPointType, &position)
      && AXValueGetValue(sizeValue, kAXValueCGSizeType, &size)) {
    result = CGRectMake(position.x, position.y, size.width, size.height);
  }
  if (positionValue != NULL) {
    CFRelease(positionValue);
  }
  if (sizeValue != NULL) {
    CFRelease(sizeValue);
  }
  return result;
}

static CFStringRef const kSpectacleAXEnhancedUserInterfaceAttribute = CFSTR("AXEnhancedUserInterface");

- (void)setRectOfElement:(CGRect)rect
{
  if (_underlyingElement == NULL) {
    return;
  }
  // Many applications (Chromium/Electron apps, Microsoft Office, Firefox, ...) switch on
  // AXEnhancedUserInterface when an assistive client talks to them. While it is on, the
  // application animates frame changes, so the size we set is applied asynchronously and the
  // following position change (and our read-back of the frame) see an intermediate frame. The
  // window ends up the wrong size or in the wrong place, which is the "left half / fullscreen
  // do not put the window in the right place" bug on current versions of macOS. Turn it off
  // for the duration of the change and restore it afterwards (the same approach Rectangle uses).
  AXUIElementRef applicationElement = NULL;
  BOOL enhancedUserInterfaceWasEnabled = NO;
  pid_t processIdentifier = 0;
  if (AXUIElementGetPid(_underlyingElement, &processIdentifier) == kAXErrorSuccess) {
    applicationElement = AXUIElementCreateApplication(processIdentifier);
  }
  if (applicationElement != NULL) {
    CFTypeRef enhancedUserInterface = NULL;
    if (AXUIElementCopyAttributeValue(applicationElement, kSpectacleAXEnhancedUserInterfaceAttribute, &enhancedUserInterface) == kAXErrorSuccess
        && enhancedUserInterface != NULL) {
      enhancedUserInterfaceWasEnabled = CFGetTypeID(enhancedUserInterface) == CFBooleanGetTypeID()
        && CFBooleanGetValue((CFBooleanRef)enhancedUserInterface);
    }
    if (enhancedUserInterface != NULL) {
      CFRelease(enhancedUserInterface);
    }
    if (enhancedUserInterfaceWasEnabled) {
      AXUIElementSetAttributeValue(applicationElement, kSpectacleAXEnhancedUserInterfaceAttribute, kCFBooleanFalse);
    }
  }
  AXValueRef positionRef = AXValueCreate(kAXValueCGPointType, (const void *)&rect.origin);
  AXValueRef sizeRef = AXValueCreate(kAXValueCGSizeType, (const void *)&rect.size);
  // Size, then position, then size again: the first resize may be constrained by the screen the
  // window is currently on (e.g. when moving to a smaller display); the second one, applied once
  // the window is in place, fixes that.
  [self setValue:sizeRef forAttribute:kAXSizeAttribute];
  [self setValue:positionRef forAttribute:kAXPositionAttribute];
  [self setValue:sizeRef forAttribute:kAXSizeAttribute];
  CFRelease(positionRef);
  CFRelease(sizeRef);
  if (applicationElement != NULL) {
    if (enhancedUserInterfaceWasEnabled) {
      AXUIElementSetAttributeValue(applicationElement, kSpectacleAXEnhancedUserInterfaceAttribute, kCFBooleanTrue);
    }
    CFRelease(applicationElement);
  }
}

static CGRect SpectaclePrimaryScreenFrameOverride = {{INFINITY, INFINITY}, {0, 0}};

+ (void)setPrimaryScreenFrameOverride:(CGRect)frame
{
  SpectaclePrimaryScreenFrameOverride = frame;
}

+ (CGRect)frameOfPrimaryScreen
{
  if (!CGRectIsNull(SpectaclePrimaryScreenFrameOverride)) {
    return SpectaclePrimaryScreenFrameOverride;
  }
  // The first screen is always the primary screen (the one with the menu bar); the global
  // accessibility coordinate space has its origin at that screen's top-left corner.
  NSArray<NSScreen *> *screens = [NSScreen screens];
  if (screens.count == 0) {
    return CGRectNull;
  }
  return NSRectToCGRect(screens[0].frame);
}

+ (CGRect)normalizeCoordinatesOfRect:(CGRect)rect frameOfScreen:(CGRect)frameOfScreen
{
  // Converts between Cocoa coordinates (origin at the bottom-left of the primary screen, y up)
  // and accessibility coordinates (origin at the top-left of the primary screen, y down). The
  // conversion is its own inverse. frameOfScreen is retained for API compatibility; only the
  // height of the primary screen matters.
  if (CGRectIsNull(rect)) {
    return rect;
  }
  CGRect frameOfPrimaryScreen = [self frameOfPrimaryScreen];
  if (CGRectIsNull(frameOfPrimaryScreen)) {
    return rect;
  }
  rect.origin.y = CGRectGetMaxY(frameOfPrimaryScreen) - CGRectGetMaxY(rect);
  return rect;
}

- (BOOL)isSheet
{
  return [[self stringValueOfAttribute:kAXRoleAttribute] isEqualToString:(__bridge NSString *)kAXSheetRole];
}

- (BOOL)isSystemDialog
{
  return [[self stringValueOfAttribute:kAXSubroleAttribute] isEqualToString:(__bridge NSString *)kAXSystemDialogSubrole];
}

- (void)dealloc
{
  if (_underlyingElement != NULL) {
    CFRelease(_underlyingElement);
  }
}

- (void)setUnderlyingElement:(AXUIElementRef)underlyingElement
{
  if (_underlyingElement == underlyingElement) {
    return;
  }
  if (_underlyingElement != NULL) {
    CFRelease(_underlyingElement);
  }
  _underlyingElement = underlyingElement != NULL ? (AXUIElementRef)CFRetain(underlyingElement) : NULL;
}

@end
