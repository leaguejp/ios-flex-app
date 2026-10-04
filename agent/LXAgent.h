#import <Foundation/Foundation.h>
@interface LXAgent : NSObject
+ (instancetype)shared;
- (void)installPairingGesture;
- (void)checkAnalysisLaunch;
- (void)pairFromController:(id)presenter;
#if LX_FIXTURE_AUTOMATION
- (void)connectFixtureTestToken:(NSString *)token;
#endif
@end
