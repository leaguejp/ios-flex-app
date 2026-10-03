#import <Foundation/Foundation.h>
@interface LXChannel : NSObject
@property(nonatomic,copy) void (^received)(NSDictionary *);
@property(nonatomic,copy) void (^disconnected)(void);
@property(nonatomic,readonly) BOOL closed;
- (instancetype)initWithSocket:(int)fd;
- (void)start;
- (BOOL)send:(NSDictionary *)message;
- (void)close;
+ (instancetype)connectLoopback:(NSError **)error;
@end
@interface LXListener : NSObject
@property(nonatomic,copy) void (^accepted)(LXChannel *);
- (BOOL)start:(NSError **)error;
- (void)stop;
@end
