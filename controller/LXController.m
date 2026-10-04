#import "LXController.h"
#import "../shared/LXProtocol.h"
#import "../shared/LXAuth.h"
#import "../shared/LXLaunch.h"
@implementation LXSession
- (instancetype)init { if((self=[super init])) _pending=[NSMutableDictionary new];return self; }
@end
@implementation LXController { LXListener *_listener;NSMutableArray *_sessions;NSUInteger _connections;NSMutableDictionary *_analysis;NSMutableArray *_catalogImages;NSMutableDictionary *_catalogClasses;NSUInteger _catalogBytes; }
- (instancetype)init { if((self=[super init])) { _sessions=[NSMutableArray new];_store=[LXStore new];_token=LXNewToken(); }return self; }
- (NSArray *)sessions { return [_sessions copy]; }
- (NSDictionary *)analysis { return [_analysis copy]; }
- (NSString *)prepareAnalysisForBundle:(NSString *)bundle {
 if([_analysis[@"status"] isEqual:@"waiting"] || [_analysis[@"status"] isEqual:@"capturing"]) return nil;
 NSString *identifier=NSUUID.UUID.UUIDString;_analysis=[@{@"bundle":bundle,@"requestID":identifier,@"status":@"waiting",@"transport":@"foregroundResult",@"detail":@"Waiting for target Agent. If nothing appears, return to Atlas and check tweak injection."} mutableCopy];
 if(self.changed) self.changed();
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,90*NSEC_PER_SEC),dispatch_get_main_queue(),^{ if([self->_analysis[@"requestID"] isEqual:identifier] && [@[@"waiting",@"capturing"] containsObject:self->_analysis[@"status"]]) [self cancelAnalysis:@"Analysis did not complete within the background window. After updating, restart the target to load the new Agent. Check injection/paste permission, then retry. Captured methods were not replaced with an empty success result."]; });
 return LXAnalysisTicket(bundle,self.token,identifier);
}
- (void)cancelAnalysis:(NSString *)reason { if(!_analysis) return;if(![@[@"waiting",@"capturing"] containsObject:_analysis[@"status"]]) return;_analysis[@"status"]=@"failed";_analysis[@"detail"]=reason;_catalogImages=nil;_catalogClasses=nil;if(self.changed) self.changed(); }
- (void)acceptAnalysisCatalog:(NSDictionary *)catalog {
 if(![@[@"waiting",@"capturing"] containsObject:_analysis[@"status"]] || ![catalog[@"bundle"] isEqual:_analysis[@"bundle"]] || ![catalog[@"requestID"] isEqual:_analysis[@"requestID"]]) return;
 NSString *reason=LXRuntimeCatalogReason(catalog);if(reason) { [self cancelAnalysis:reason];return; }
 NSMutableDictionary *state=[[self.store stateForBundle:_analysis[@"bundle"]] mutableCopy];state[@"runtimeCatalog"]=catalog;NSError *error=nil;
 if(![self.store save:state bundle:_analysis[@"bundle"] error:&error]) { [self cancelAnalysis:[NSString stringWithFormat:@"Runtime results could not be saved. Previous results are retained.\n%@",error.localizedDescription ?: @"Unknown persistence error"]];return; }
 _analysis[@"status"]=@"complete";_analysis[@"metadata"]=catalog[@"metadata"];_analysis[@"detail"]=@"Runtime results saved after foreground return";if(self.changed) self.changed();
}
- (BOOL)analysisMatches:(LXSession *)session request:(NSString *)request {
 return [_analysis[@"requestID"] isEqual:request] && [_analysis[@"bundle"] isEqual:session.identity[@"bundle"]] && [_analysis[@"status"] isEqual:@"capturing"];
}
- (void)finishAnalysis:(LXSession *)session request:(NSString *)request error:(NSString *)error {
 if(![self analysisMatches:session request:request]) return;
 if(error) [self cancelAnalysis:error];
 else {
  NSDictionary *catalog=@{@"metadata":_analysis[@"metadata"],@"images":_catalogImages,@"bundle":_analysis[@"bundle"],@"requestID":request,@"pid":session.identity[@"pid"]};
  NSString *reason=LXRuntimeCatalogReason(catalog);if(reason) { [self finishAnalysis:session request:request error:reason];return; }
  NSMutableDictionary *state=[[self.store stateForBundle:session.identity[@"bundle"]] mutableCopy];state[@"runtimeCatalog"]=catalog;
  NSError *saveError=nil;
  if(![self.store save:state bundle:session.identity[@"bundle"] error:&saveError]) [self cancelAnalysis:[NSString stringWithFormat:@"Runtime results could not be saved. Previous results are retained.\n%@",saveError.localizedDescription ?: @"Unknown persistence error"]];
  else { _analysis[@"status"]=@"complete";_analysis[@"detail"]=@"Runtime results saved";if(self.changed) self.changed(); }
 }
 [self request:@"analysisReturn" payload:@{@"requestID":request} session:session completion:^(NSDictionary *response) { if(response[@"error"] && response[@"error"]!=NSNull.null) { self->_analysis[@"returnWarning"]=@"Automatic return failed; switch back to Atlas manually.";if(self.changed) self.changed(); } }];
}
- (void)capturePage:(LXSession *)session request:(NSString *)request offset:(NSUInteger)offset {
 if(![self analysisMatches:session request:request]) return;
 [self request:@"catalogPage" payload:@{@"captureID":_analysis[@"metadata"][@"captureID"],@"offset":@(offset)} session:session completion:^(NSDictionary *response) {
  if(![self analysisMatches:session request:request]) return;
  if(response[@"error"]!=NSNull.null) { [self finishAnalysis:session request:request error:response[@"error"][@"detail"]];return; }
  NSDictionary *page=response[@"payload"];
  if([page[@"total"] unsignedIntegerValue]!=[self->_analysis[@"metadata"][@"total"] unsignedIntegerValue]) { [self finishAnalysis:session request:request error:@"Capture total changed during transfer"];return; }
  for(NSDictionary *record in page[@"records"]) {
   NSDictionary *data=record[@"data"];NSString *kind=record[@"kind"];
   self->_catalogBytes+=[NSJSONSerialization dataWithJSONObject:record options:0 error:nil].length;
   if(self->_catalogBytes>8*1024*1024) { [self finishAnalysis:session request:request error:@"Capture transfer exceeded 8 MiB"];return; }
   if([kind isEqual:@"image"]) { NSMutableDictionary *image=[data mutableCopy];image[@"classes"]=[NSMutableArray new];image[@"bundle"]=session.identity[@"bundle"];[self->_catalogImages addObject:image]; }
   else if([kind isEqual:@"class"]) {
    NSMutableDictionary *owner=nil;for(NSMutableDictionary *image in self->_catalogImages) if([image[@"path"] isEqual:data[@"image"]]) owner=image;
    if(!owner || self->_catalogClasses[data[@"name"]]) { [self finishAnalysis:session request:request error:@"Invalid class/image association"];return; }
    NSMutableDictionary *cls=[data mutableCopy];cls[@"methods"]=[NSMutableArray new];[owner[@"classes"] addObject:cls];self->_catalogClasses[data[@"name"]]=cls;
   } else {
    NSMutableDictionary *cls=self->_catalogClasses[data[@"class"]];
    if(!cls || ![cls[@"image"] isEqual:data[@"image"]]) { [self finishAnalysis:session request:request error:@"Invalid method/class association"];return; }
    [cls[@"methods"] addObject:data];
   }
  }
  NSUInteger next=[page[@"next"] unsignedIntegerValue];self->_analysis[@"received"]=@(next);if(self.changed) self.changed();
  if(next<[page[@"total"] unsignedIntegerValue]) [self capturePage:session request:request offset:next];else [self finishAnalysis:session request:request error:nil];
 }];
}
- (void)beginAnalysis:(LXSession *)session {
 NSString *request=_analysis[@"requestID"];
 if(![_analysis[@"status"] isEqual:@"waiting"] || ![session.identity[@"analysisRequestID"] isEqual:request] || ![session.identity[@"bundle"] isEqual:_analysis[@"bundle"]]) return;
 _analysis[@"status"]=@"capturing";_analysis[@"detail"]=@"Capturing loaded Objective-C methods";_catalogImages=[NSMutableArray new];_catalogClasses=[NSMutableDictionary new];_catalogBytes=0;if(self.changed) self.changed();
 [self request:@"activate" payload:@{} session:session completion:^(NSDictionary *response) {
  if(![self analysisMatches:session request:request]) return;
  if(response[@"error"]!=NSNull.null) { [self finishAnalysis:session request:request error:response[@"error"][@"detail"]];return; }
  [self request:@"catalogStart" payload:@{} session:session completion:^(NSDictionary *start) {
   if(![self analysisMatches:session request:request]) return;
   if(start[@"error"]!=NSNull.null) { [self finishAnalysis:session request:request error:start[@"error"][@"detail"]];return; }
   self->_analysis[@"metadata"]=start[@"payload"];[self capturePage:session request:request offset:0];
  }];
 }];
}
- (BOOL)start:(NSError **)error {
 _listener=[LXListener new];__weak LXController *weak=self;
 _listener.accepted=^(LXChannel *channel) { dispatch_async(dispatch_get_main_queue(),^{ [weak accept:channel]; }); };
 return [_listener start:error];
}
- (void)accept:(LXChannel *)channel {
#if LX_CONTROLLER_AUTOMATION
 NSLog(@"Atlas launch: Controller accepted socket");
#endif
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
#if LX_CONTROLLER_AUTOMATION
   NSLog(@"Atlas launch: Controller verified hello");
#endif
   s.challenge=@{@"agentNonce":p[@"nonce"],@"serverNonce":NSUUID.UUID.UUIDString};NSMutableDictionary *challenge=[s.challenge mutableCopy];challenge[@"proof"]=LXProof(weak.token,@"server",s.challenge);
   [s.channel send:LXMessage(@"helloChallenge",challenge)];return;
  }
  if(![m[@"bundle"] isEqual:s.identity[@"bundle"]] || ![m[@"pid"] isEqual:s.identity[@"pid"]]) { [s.channel close];return; }
  if(!s.authenticated) {
   if(![m[@"command"] isEqual:@"helloFinish"] || !LXProofMatches(LXProof(weak.token,@"client",s.challenge),m[@"payload"][@"proof"])) { [s.channel close];return; }
   s.authenticated=YES;s.challenge=nil;LXController *controller=weak;if(!controller) { [s.channel close];return; }[controller->_sessions addObject:s];handshake=nil;
   [s.channel send:LXMessage(@"helloAck",@{})];if(controller.changed) controller.changed();[controller beginAnalysis:s];return;
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
  if([@[@"catalogStart",@"catalogPage",@"analysisReturn"] containsObject:command]) { completion(response);return; }
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
