#import "SpectacleLoginItemHelper.h"

#import <ServiceManagement/ServiceManagement.h>

// LSSharedFileList (used by earlier releases) was deprecated in macOS 10.11 and no longer
// manages login items on macOS 13 and later. SMAppService is the supported replacement; it
// always operates on the running application's own bundle, so the bundle argument is kept
// only for API compatibility.
@implementation SpectacleLoginItemHelper

+ (BOOL)isLoginItemEnabledForBundle:(NSBundle *)bundle
{
  SMAppServiceStatus status = SMAppService.mainAppService.status;
  return status == SMAppServiceStatusEnabled || status == SMAppServiceStatusRequiresApproval;
}

+ (void)enableLoginItemForBundle:(NSBundle *)bundle
{
  NSError *error = nil;
  if (![SMAppService.mainAppService registerAndReturnError:&error]) {
    NSLog(@"Unable to enable Spectacle as a login item: %@", error.localizedDescription);
  }
}

+ (void)disableLoginItemForBundle:(NSBundle *)bundle
{
  NSError *error = nil;
  if (![SMAppService.mainAppService unregisterAndReturnError:&error]) {
    NSLog(@"Unable to disable Spectacle as a login item: %@", error.localizedDescription);
  }
}

@end
