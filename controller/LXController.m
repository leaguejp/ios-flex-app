#import "LXController.h"
#import "../shared/LXProtocol.h"
@implementation LXSession
- (instancetype)init { if((self=[super init])) _pending=[NSMutableDictionary new];return self; }
@end
@implementation LXController { LXListener *_listener;NSMutableArray *_sessions;NSUInteger _connections; }
- (instancetype)init { if((self=[super init])) { _sessions=[NSMutableArray new];_store=[LXStore new];_token=[[NSUUID.UUID.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString]; }return self; }
- (NSArray *)sessions { return [_sessions copy]; }
- (BOOL)start:(NSError **)error {
 _listener=[LXListener new];__weak LXController *weak=self;
 _listener.accepted=^(LXChannel *channel) { dispatch_async(dispatch_get_main_queue(),^{ [weak accept:channel]; }); };
 return [_listener start:error];
}
- (void)accept:(LXChannel *)channel {
 if(_connections>=16) { [channel close];return; }_connections++;
 LXSession *session=[LXSession new];session.channel=channel;__weak LXController *weak=self;__weak LXSession *weakSession=session;
 // Hold unauthenticated session only until handshake / disconnect; do not expose it in UI.
 __block LXSession *handshake=session;
 channel.received=^(NSDictionary *m) { dispatch_async(dispatch_get_main_queue(),^{
  LXSession *s=weakSession;if(!s) return;
  if(!s.identity) {
   NSDictionary *p=m[@"payload"];NSString *token=p[@"token"];
   if(![m[@"command"] isEqual:@"hello"] || ![token isKindOfClass:NSString.class] || ![token isEqual:weak.token] || ![p[@"executable"] isKindOfClass:NSString.class] || ![p[@"bundlePath"] isKindOfClass:NSString.class] || ![p[@"bundle"] isEqual:m[@"bundle"]] || ![p[@"pid"] isEqual:m[@"pid"]]) { [s.channel close];return; }
   // Loopback token authorizes a session; claimed PID/bundle are diagnostic, not OS-attested identities.
   NSMutableDictionary *identity=[p mutableCopy];[identity removeObjectForKey:@"token"];s.identity=identity;
   LXController *controller=weak;if(!controller) { [s.channel close];return; }[controller->_sessions addObject:s];handshake=nil;
   [s.channel send:LXMessage(@"helloAck",@{})];if(weak.changed) weak.changed();return;
  }
  if(![m[@"bundle"] isEqual:s.identity[@"bundle"]] || ![m[@"pid"] isEqual:s.identity[@"pid"]]) { [s.channel close];return; }
  if([m[@"command"] isEqual:@"heartbeat"]) { [s.channel send:LXMessage(@"helloAck",@{})];return; }
  NSString *response=m[@"responseID"];void (^callback)(NSDictionary *)=s.pending[response];if(!callback) return;
  [s.pending removeObjectForKey:response];callback(m);
 }); };
 channel.disconnected=^{ dispatch_async(dispatch_get_main_queue(),^{
  LXController *strong=weak;if(!strong) return;LXSession *s=weakSession ?: handshake;
  if(strong->_connections) strong->_connections--;for(void (^callback)(NSDictionary *) in s.pending.allValues) callback(@{@"error":LXError(@"disconnected",@"Agent disconnected; hooks are disabled by Agent")});
  [s.pending removeAllObjects];[strong->_sessions removeObject:s];handshake=nil;if(strong.changed) strong.changed();
 }); };
 [channel start];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC),dispatch_get_main_queue(),^{ if(handshake) [handshake.channel close]; });
}
- (void)request:(NSString *)command payload:(NSDictionary *)payload session:(LXSession *)session completion:(void (^)(NSDictionary *))completion {
 if(session.channel.closed) { completion(@{@"error":LXError(@"disconnected",@"Agent is offline")});return; }
 NSDictionary *m=LXMessage(command,payload);NSString *identifier=m[@"commandID"];
 __weak LXController *weak=self;__weak LXSession *weakSession=session;
 session.pending[identifier]=^(NSDictionary *response) {
  LXSession *s=weakSession;if(!s) return;
  if(response[@"error"]==NSNull.null) {
   if([command isEqual:@"activate"]) s.active=YES;if([command isEqual:@"deactivate"]) s.active=NO;
   NSString *bundle=s.identity[@"bundle"];NSMutableDictionary *state=[[weak.store stateForBundle:bundle] mutableCopy];
   state[@"identity"]=s.identity;state[@"updatedAt"]=@(NSDate.date.timeIntervalSince1970);
   if([command isEqual:@"logs"]) state[@"logs"]=response[@"payload"][@"logs"] ?: @[];
   else if([command isEqual:@"state"]) state[@"hookState"]=response[@"payload"];
   else if([@[@"images",@"classes",@"methods",@"static"] containsObject:command]) {
    NSMutableArray *history=[state[@"history"] mutableCopy] ?: [NSMutableArray new];
    [history addObject:@{@"command":command,@"request":payload ?: @{},@"response":response[@"payload"],@"time":state[@"updatedAt"]}];
    while(history.count>8) [history removeObjectAtIndex:0];state[@"history"]=history;
   }
   if([command isEqual:@"hookEnable"] || [command isEqual:@"hookDisable"]) {
    NSMutableDictionary *desired=[state[@"desiredHooks"] mutableCopy] ?: [NSMutableDictionary new];
    NSString *key=response[@"payload"][@"key"];if(key) desired[key]=@{ @"enabled":response[@"payload"][@"enabled"] ?: @NO,@"request":payload ?: @{} };state[@"desiredHooks"]=desired;
   }
   state[@"autoRestoreHooks"]=@NO;[weak.store save:state bundle:bundle];
  }
  completion(response);
 };
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{ [session.channel send:m]; });
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,30*NSEC_PER_SEC),dispatch_get_main_queue(),^{
  void (^callback)(NSDictionary *)=session.pending[identifier];if(callback) { [session.pending removeObjectForKey:identifier];callback(@{@"error":LXError(@"timeout",@"Agent response timed out")}); }
 });
}
@end
