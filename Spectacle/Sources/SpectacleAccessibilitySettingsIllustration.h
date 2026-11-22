#import <Cocoa/Cocoa.h>

/// A drawing of System Settings > Privacy & Security > Accessibility (macOS 26 and later) with
/// Spectacle switched on, shown in the accessibility-permission dialog.
///
/// It is drawn rather than a screenshot, so it stays sharp at any scale, never shows the user's
/// other apps, and follows the current appearance: it is drawn with Light Mode colors in Light
/// Mode and Dark Mode colors in Dark Mode, and redraws when the appearance changes.
@interface SpectacleAccessibilitySettingsIllustration : NSView

/// The rect of the System Settings window drawn inside the view (it runs off the bottom edge).
@property (nonatomic, readonly) NSRect windowRect;

/// The rects of the sidebar, the selected "Privacy & Security" row, the Spectacle row and its
/// switch, in view coordinates (the view is flipped). Exposed for the tests.
@property (nonatomic, readonly) NSRect sidebarRect;
@property (nonatomic, readonly) NSRect selectedSidebarRowRect;
@property (nonatomic, readonly) NSRect spectacleRowRect;
@property (nonatomic, readonly) NSRect switchRect;

@end
