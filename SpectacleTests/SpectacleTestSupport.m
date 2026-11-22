#import "SpectacleTestSupport.h"

id SPTBoxValue(const char *type, const void *value)
{
  if (strcmp(type, @encode(id)) == 0 || type[0] == '@') {
    return *(__unsafe_unretained id *)value;
  }
  if (strcmp(type, @encode(CGRect)) == 0) {
    return [NSValue valueWithRect:NSRectFromCGRect(*(const CGRect *)value)];
  }
  if (strcmp(type, @encode(CGPoint)) == 0) {
    return [NSValue valueWithPoint:NSPointFromCGPoint(*(const CGPoint *)value)];
  }
  if (strcmp(type, @encode(CGSize)) == 0) {
    return [NSValue valueWithSize:NSSizeFromCGSize(*(const CGSize *)value)];
  }
#define SPT_BOX_NUMBER(ctype) \
  if (strcmp(type, @encode(ctype)) == 0) { return @(*(const ctype *)value); }
  SPT_BOX_NUMBER(char)
  SPT_BOX_NUMBER(unsigned char)
  SPT_BOX_NUMBER(short)
  SPT_BOX_NUMBER(unsigned short)
  SPT_BOX_NUMBER(int)
  SPT_BOX_NUMBER(unsigned int)
  SPT_BOX_NUMBER(long)
  SPT_BOX_NUMBER(unsigned long)
  SPT_BOX_NUMBER(long long)
  SPT_BOX_NUMBER(unsigned long long)
  SPT_BOX_NUMBER(float)
  SPT_BOX_NUMBER(double)
  SPT_BOX_NUMBER(bool)
#undef SPT_BOX_NUMBER
  if (type[0] == '^' || type[0] == '*') {
    const void *pointer = *(const void *const *)value;
    return pointer ? [NSValue valueWithPointer:pointer] : nil;
  }
  return [NSValue valueWithBytes:value objCType:type];
}
