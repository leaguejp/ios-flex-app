#import "LXController.h"
#import "../shared/LXProtocol.h"
#import "../shared/LXAuth.h"
@implementation LXSession
- (instancetype)init { if((self=[super init])) _pending=[NSMutableDictionary new];return self; }
@end
@implementation LXController { LXListener *_listener;NSMutableArray *_sessions;NSUInteger _connections; }
- (instancetype)init { if((self=[super init])) { _sessions=[NSMutableArray new];_store=[LXStore new];_token=LXNewToken(); }return self; }
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
   NSDictionary *p=m[@"payload"];NSMutableDictionary *body=[p mutableCopy];[body removeObjectForKey:@"proof"];
   if(![m[@"command"] isEqual:@"hello"] || ![p[@"nonce"] isKindOfClass:NSString.class] || [p[@"nonce"] length]!=36 || !LXProofMatches(LXProof(weak.token,@"hello",body),p[@"proof"]) || ![p[@"executable"] isKindOfClass:NSString.class] || ![p[@"bundlePath"] isKindOfClass:NSString.class] || ![p[@"bundle"] isEqual:m[@"bundle"]] || ![p[@"pid"] isEqual:m[@"pid"]]) { [s.channel close];return; }
   // Loopback token authorizes a session; claimed PID/bundle are diagnostic, not OS-attested identities.
   NSMutableDictionary *identity=[p mutableCopy];[identity removeObjectForKey:@"proof"];[identity removeObjectForKey:@"nonce"];s.identity=identity;s.active=[identity[@"active"] isKindOfClass:NSNumber.class] && [identity[@"active"] boolValue];
   s.challenge=@{@"agentNonce":p[@"nonce"],@"serverNonce":NSUUID.UUID.UUIDString};NSMutableDictionary *challenge=[s.challenge mutableCopy];challenge[@"proof"]=LXProof(weak.token,@"server",s.challenge);
   [s.channel send:LXMessage(@"helloChallenge",challenge)];return;
  }
  if(![m[@"bundle"] isEqual:s.identity[@"bundle"]] || ![m[@"pid"] isEqual:s.identity[@"pid"]]) { [s.channel close];return; }
  if(!s.authenticated) {
   if(![m[@"command"] isEqual:@"helloFinish"] || !LXProofMatches(LXProof(weak.token,@"client",s.challenge),m[@"payload"][@"proof"])) { [s.channel close];return; }
   s.authenticated=YES;s.challenge=nil;LXController *controller=weak;if(!controller) { [s.channel close];return; }[controller->_sessions addObject:s];handshake=nil;
   [s.channel send:LXMessage(@"helloAck",@{})];if(controller.changed) controller.changed();return;
  }
  if([m[@"command"] isEqual:@"heartbeat"]) { [s.channel send:LXMessage(@"helloAck",@{})];return; }
  NSString *response=m[@"responseID"];void (^callback)(NSDictionary *)=s.pending[response];if(!callback) return;
  [s.pending removeObjectForKey:response];callback(m);
 }); };
 channel.disconnected=^{ dispatch_async(dispatch_get_main_queue(),^{
  LXController *strong=weak;if(!strong) return;LXSession *s=weakSession ?: handshake;
  if(strong->_connections) strong->_connections--;for(void (^callback)(NSDictionary *) in s.pending.allValues) callback(@{@"error":LXError(@"disconnected",@"Agent disconnected; interactive hooks are disabled. Authorized launch patches may remain active.")});
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
   NSString *reason=[response[@"command"] isEqual:command]?LXResultReason(command,response[@"payload"],payload):@"Response command differs from request";
   if(reason) { NSMutableDictionary *invalid=[response mutableCopy];invalid[@"error"]=LXError(@"bad_response",reason);invalid[@"payload"]=@{};completion(invalid);return; }
  }
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
    NSString *key=response[@"payload"][@"key"];if(key) desired[key]=@{ @"enabled":response[@"payload"][@"enabled"] ?: @NO,@"request":[command isEqual:@"hookEnable"]?(payload ?: @{}):(desired[key][@"request"] ?: @{}) };state[@"desiredHooks"]=desired;
   }
   if([command isEqual:@"patchApply"]) { NSMutableDictionary *patches=[state[@"patches"] mutableCopy] ?: [NSMutableDictionary new];patches[payload[@"key"]]=payload[@"patch"];state[@"patches"]=patches; }
   if([command isEqual:@"patchPolicy"]) state[@"applyOnLaunch"]=payload[@"enabled"];if([command isEqual:@"deactivate"]) state[@"applyOnLaunch"]=@NO;
   state[@"autoRestoreHooks"]=@NO;if(![weak.store save:state bundle:bundle]) { NSMutableDictionary *warning=[response mutableCopy];warning[@"persistenceWarning"]=@"Per-bundle state could not be saved; verify writable application documents directory";response=warning; }
  }
  completion(response);
 };
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{ [session.channel send:m]; });
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,30*NSEC_PER_SEC),dispatch_get_main_queue(),^{
  void (^callback)(NSDictionary *)=session.pending[identifier];if(callback) { [session.pending removeObjectForKey:identifier];callback(@{@"error":LXError(@"timeout",@"Agent response timed out")}); }
 });
}
@end
