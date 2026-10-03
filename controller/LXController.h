#import <Foundation/Foundation.h>
#import "../shared/LXChannel.h"
#import "LXStore.h"
@interface LXSession : NSObject
@property(nonatomic,strong) LXChannel *channel;
@property(nonatomic,strong) NSDictionary *identity;
@property(nonatomic,strong) NSMutableDictionary *pending;
@property(nonatomic) BOOL active;
@end
@interface LXController : NSObject
@property(nonatomic,readonly) NSString *token;
@property(nonatomic,readonly) NSArray<LXSession *> *sessions;
@property(nonatomic,strong,readonly) LXStore *store;
@property(nonatomic,copy) void (^changed)(void);
- (BOOL)start:(NSError **)error;
- (void)request:(NSString *)command payload:(NSDictionary *)payload session:(LXSession *)session completion:(void (^)(NSDictionary *))completion;
@end
