#import <AppKit/AppKit.h>
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

/// Boxes any scalar, object or CGRect/CGPoint/CGSize value so values of different static types
/// (e.g. an NSNumber and an integer literal) can be compared with -isEqual:.
id _Nullable SPTBoxValue(const char *type, const void *value);

#define SPTBox(expression) ({ __typeof__(expression) _sptValue = (expression); SPTBoxValue(@encode(__typeof__(expression)), &_sptValue); })

#define SPTAssertEqual(actual, expected, ...) \
  XCTAssertEqualObjects(SPTBox(actual), SPTBox(expected), ##__VA_ARGS__)

#define SPTAssertNotEqual(actual, expected, ...) \
  XCTAssertNotEqualObjects(SPTBox(actual), SPTBox(expected), ##__VA_ARGS__)

#define SPTAssertRectEqual(actual, expected, ...) \
  XCTAssertTrue(CGRectEqualToRect((actual), (expected)), @"%@ is not equal to %@. %@", \
                NSStringFromRect(NSRectFromCGRect(actual)), NSStringFromRect(NSRectFromCGRect(expected)), \
                [NSString stringWithFormat:@"" __VA_ARGS__])

NS_ASSUME_NONNULL_END
