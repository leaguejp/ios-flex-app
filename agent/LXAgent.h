#import <Foundation/Foundation.h>
@interface LXAgent : NSObject
+ (instancetype)shared;
- (void)installPairingGesture;
- (void)pairFromController:(id)presenter;
@end
