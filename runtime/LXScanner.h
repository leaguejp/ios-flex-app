#import <Foundation/Foundation.h>
@interface LXScanner : NSObject
- (NSDictionary *)images;
- (NSDictionary *)classesInImage:(NSString *)image offset:(NSUInteger)offset;
- (NSDictionary *)methodsInClass:(NSString *)className;
- (NSDictionary *)methodsInClass:(NSString *)className offset:(NSUInteger)offset;
@end
