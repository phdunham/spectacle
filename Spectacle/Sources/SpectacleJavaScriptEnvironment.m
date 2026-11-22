#import "SpectacleJavaScriptEnvironment.h"

#import <JavaScriptCore/JavaScriptCore.h>

@implementation SpectacleJavaScriptEnvironment
{
  JSContext *_context;
}

- (instancetype)initWithContextBuilder:(void(^)(JSContext *))contextBuilder
{
  if (self = [super init]) {
    _context = [JSContext new];
    contextBuilder(_context);
    [self evaluateBundledScripts];
  }
  return self;
}

- (JSValue *)valueWithRect:(CGRect)rect
{
  return [JSValue valueWithRect:rect inContext:_context];
}

- (void)evaluateBundledScripts
{
  // Look the scripts up next to this class (the app bundle) rather than the main bundle, and
  // evaluate them in a stable order: helper modules are referenced lazily, but a predictable
  // order makes failures reproducible.
  NSBundle *bundle = [NSBundle bundleForClass:[SpectacleJavaScriptEnvironment class]];
  NSArray<NSString *> *scriptPaths = [[bundle pathsForResourcesOfType:@"js"
                                                          inDirectory:@"Window Position Calculations"]
                                      sortedArrayUsingSelector:@selector(compare:)];
  if (scriptPaths.count == 0) {
    NSLog(@"No window position calculation scripts were found in %@", bundle.bundlePath);
  }
  [scriptPaths enumerateObjectsUsingBlock:^(NSString *scriptPath, NSUInteger index, BOOL *stop) {
    NSString *script = loadScriptAtPath(scriptPath);
    if (script) {
      [self->_context evaluateScript:script];
    }
  }];
}

static NSString *loadScriptAtPath(NSString *scriptPath)
{
  NSError *error;
  NSString *script = [NSString stringWithContentsOfFile:scriptPath encoding:NSUTF8StringEncoding error:&error];
  if (!script) {
    NSLog(@"Unable to load script at path %@; reason %@", scriptPath, error.localizedDescription);
  }
  return script;
}

@end
