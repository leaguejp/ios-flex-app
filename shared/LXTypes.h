#import <Foundation/Foundation.h>
NSArray *LXDescribeEncoding(NSString *encoding);
NSString *LXHookReason(NSString *className,NSString *selector,BOOL classMethod,NSString *encoding);

NSString *LXStaticHookReason(NSString *bundle,NSString *className,NSString *selector,BOOL classMethod,NSString *encoding);
NSString *LXPatchReason(NSDictionary *patch,NSString *encoding);
