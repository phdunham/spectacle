#import <Cocoa/Cocoa.h>

/// A push button that paints its own solid, rounded fill with a white title.
///
/// On recent versions of macOS (26 and later) the system draws standard push buttons as dark grey
/// capsules on a dark window in Dark Mode, ignores bezelColor, and only colors the default button
/// while its window is key. This button draws the same in Light and Dark Mode, focused or not.
@interface SpectacleFilledButton : NSButton

/// The fill color; dynamic system colors are resolved for the button's appearance when drawing.
@property (nonatomic, strong) NSColor *fillColor;

/// The title color. Defaults to white.
@property (nonatomic, strong) NSColor *titleColor;

/// The rounded rectangle the fill is drawn in.
- (NSRect)fillRect;

@end
