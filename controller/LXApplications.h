#import <Foundation/Foundation.h>
@interface LXApplications : NSObject
+ (NSArray<NSDictionary *> *)installed:(NSString **)failure;
+ (BOOL)openBundle:(NSString *)bundle;
@end
