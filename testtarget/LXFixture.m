#import "LXFixture.h"
#include <limits.h>
@implementation LXFixture
- (void)ping { self.pings++; }
- (id)echo:(id)value { return value; }
- (long long)addOne:(long long)value { if(value==LLONG_MIN) [NSException raise:@"LXFixtureException" format:@"Intentional exception propagation test"];return value+1; }
- (BOOL)invert:(BOOL)value { return !value; }
- (float)scale:(float)value { return value*1.5f; }
- (double)doubleValue:(double)value { return value*2; }
+ (long long)classValue { return 42; }
- (LXPoint)point:(LXPoint)value { value.x+=1;return value; }
- (int)variadic:(int)value, ... { return value; }
@end
