#import <Foundation/Foundation.h>
#import <objc/runtime.h>
@interface LXHookEngine : NSObject
- (NSDictionary *)enableClass:(NSString *)name selector:(NSString *)selector classMethod:(BOOL)isClass;
- (NSDictionary *)configurePatch:(NSDictionary *)patch key:(NSString *)key;
- (NSDictionary *)disableKey:(NSString *)key;
- (NSArray *)state;
- (NSArray *)logs;
- (void)disableAll;
@end
