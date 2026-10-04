#import <Foundation/Foundation.h>
@class LXScanner;
/* Agent-owned capture, serialized on the Agent queue. Never reads other processes. */
@interface LXCatalog : NSObject
- (NSDictionary *)capture:(LXScanner *)scanner bundlePath:(NSString *)path;
- (NSDictionary *)page:(NSString *)captureID offset:(NSUInteger)offset;
@end
