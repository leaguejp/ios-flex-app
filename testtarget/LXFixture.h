#import <Foundation/Foundation.h>
typedef struct { double x,y; } LXPoint;
@interface LXFixture : NSObject
@property(nonatomic) NSUInteger pings;
- (void)ping;
- (id)echo:(id)value;
- (long long)addOne:(long long)value;
- (BOOL)invert:(BOOL)value;
- (float)scale:(float)value;
- (double)doubleValue:(double)value;
+ (long long)classValue;
- (LXPoint)point:(LXPoint)value;
- (int)variadic:(int)value, ...;
@end
