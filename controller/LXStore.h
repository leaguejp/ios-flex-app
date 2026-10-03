#import <Foundation/Foundation.h>
@interface LXStore : NSObject
- (NSDictionary *)stateForBundle:(NSString *)bundle;
- (BOOL)save:(NSDictionary *)state bundle:(NSString *)bundle;
- (NSString *)savePatch:(NSDictionary *)patch method:(NSDictionary *)method bundle:(NSString *)bundle;
- (NSURL *)exportBundle:(NSString *)bundle error:(NSError **)error;
@end
