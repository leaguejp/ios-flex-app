#import "LXAgent.h"
#import <UIKit/UIKit.h>
#import "../shared/LXChannel.h"
#import "../shared/LXProtocol.h"
#import "../shared/LXAuth.h"
#import "../runtime/LXScanner.h"
#import "../static/LXStaticAnalyzer.h"
#import "../hook/LXHookEngine.h"
#include <unistd.h>
#import <objc/runtime.h>
#if LX_FIXTURE_AUTOMATION
#import "../testtarget/LXFixture.h"
#endif
@implementation LXAgent {
 LXChannel *_channel;LXScanner *_scanner;LXHookEngine *_hooks;LXStaticAnalyzer *_static;
 dispatch_queue_t _queue;dispatch_source_t _heartbeat;BOOL _active;BOOL _connecting;BOOL _authenticated;BOOL _serverVerified;NSString *_token;NSString *_nonce;
 NSMutableSet *_seenCommands;NSMutableArray *_commandOrder;NSMutableDictionary *_methodProfiles;NSMutableDictionary *_savedPatches;BOOL _launchPatches;NSArray *_restoreErrors;
}
+ (instancetype)shared { static LXAgent *agent;static dispatch_once_t once;dispatch_once(&once,^{ agent=[LXAgent new]; });return agent; }
- (instancetype)init { if((self=[super init])) { _queue=dispatch_queue_create("jp.league.runtimeatlas.agent",DISPATCH_QUEUE_SERIAL);_seenCommands=[NSMutableSet new];_commandOrder=[NSMutableArray new];_methodProfiles=[NSMutableDictionary new];_savedPatches=[NSMutableDictionary new];dispatch_async(_queue,^{ [self restoreLaunchPatches]; }); }return self; }
- (NSDictionary *)enableProfile:(NSDictionary *)profile {
 id encoding=profile[@"encoding"];
 if(encoding) {
  if(![encoding isKindOfClass:NSString.class]) return @{@"error":LXError(@"invalid_profile",@"Encoding must be a string")};
  Class cls=objc_getClass([profile[@"class"] UTF8String]);SEL sel=sel_registerName([profile[@"selector"] UTF8String]);Method method=[profile[@"classMethod"] boolValue]?class_getClassMethod(cls,sel):class_getInstanceMethod(cls,sel);
  const char *actual=method?method_getTypeEncoding(method):NULL;
  if(!actual || ![encoding isEqual:@(actual)]) return @{@"error":LXError(@"encoding_changed",@"Saved/static method encoding differs from the loaded method; analyze again")};
 }
 return [_hooks enableClass:profile[@"class"] selector:profile[@"selector"] classMethod:[profile[@"classMethod"] boolValue]];
}
- (void)saveLaunchPatches {
 [NSUserDefaults.standardUserDefaults setObject:@{@"schema":@1,@"enabled":@(_launchPatches),@"patches":_savedPatches} forKey:@"jp.league.runtimeatlas.launchPatches"];
}
- (void)restoreLaunchPatches {
 id saved=[NSUserDefaults.standardUserDefaults objectForKey:@"jp.league.runtimeatlas.launchPatches"];
 if(![saved isKindOfClass:NSDictionary.class] || ![saved[@"schema"] isEqual:@1] || ![saved[@"patches"] isKindOfClass:NSDictionary.class] || [saved[@"patches"] count]>128) return;
 _savedPatches=[saved[@"patches"] mutableCopy];_launchPatches=[saved[@"enabled"] isKindOfClass:NSNumber.class] && [saved[@"enabled"] boolValue];if(!_launchPatches) return;
 _hooks=[LXHookEngine new];NSMutableArray *errors=[NSMutableArray new];
 for(NSString *key in _savedPatches) { @try {
  NSDictionary *entry=_savedPatches[key];NSDictionary *method=entry[@"method"],*patch=entry[@"patch"];
  if(![method isKindOfClass:NSDictionary.class] || ![method[@"class"] isKindOfClass:NSString.class] || ![method[@"selector"] isKindOfClass:NSString.class] || ![method[@"classMethod"] isKindOfClass:NSNumber.class] || ![patch isKindOfClass:NSDictionary.class]) { [errors addObject:@{@"key":key,@"error":@"Malformed saved patch"}];continue; }
  NSString *expected=[NSString stringWithFormat:@"%@%@/%@",[method[@"classMethod"] boolValue]?@"+":@"-",method[@"class"],method[@"selector"]];if(![key isEqual:expected]) { [errors addObject:@{@"key":key,@"error":@"Saved method identity mismatch"}];continue; }
  NSDictionary *enabled=[self enableProfile:method];
  NSDictionary *result=enabled[@"error"]?enabled:[_hooks configurePatch:patch key:enabled[@"key"]];
  if(result[@"error"]) { if(enabled[@"key"]) [_hooks disableKey:enabled[@"key"]];[errors addObject:@{@"key":key,@"error":result[@"error"]}]; }
  else { _methodProfiles[key]=method;_active=YES; }
 } @catch(NSException *exception) { [errors addObject:@{@"key":key,@"error":exception.name}]; } }
 _restoreErrors=errors;
}
- (UIViewController *)presenter {
 for(UIScene *scene in UIApplication.sharedApplication.connectedScenes) if([scene isKindOfClass:UIWindowScene.class] && scene.activationState==UISceneActivationStateForegroundActive)
  for(UIWindow *window in ((UIWindowScene *)scene).windows) if(window.isKeyWindow) { UIViewController *vc=window.rootViewController;while(vc.presentedViewController) vc=vc.presentedViewController;return vc; }
 return [self legacyPresenter];
}
- (UIViewController *)legacyPresenter {
 id<UIApplicationDelegate> delegate=UIApplication.sharedApplication.delegate;
 UIViewController *vc=[delegate respondsToSelector:@selector(window)]?delegate.window.rootViewController:nil;
 while(vc.presentedViewController) vc=vc.presentedViewController;return vc;
}
- (void)installPairingGesture {
 dispatch_async(dispatch_get_main_queue(),^{
  UIView *view=[self presenter].view;if(!view || objc_getAssociatedObject(view,@selector(installPairingGesture))) return;
  UITapGestureRecognizer *gesture=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pairGesture:)];gesture.numberOfTapsRequired=3;gesture.numberOfTouchesRequired=3;gesture.cancelsTouchesInView=NO;
  [view addGestureRecognizer:gesture];objc_setAssociatedObject(view,@selector(installPairingGesture),gesture,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
 });
}
- (void)pairGesture:(UITapGestureRecognizer *)gesture { if(gesture.state==UIGestureRecognizerStateRecognized) [self pairFromController:[self presenter]]; }
- (void)pairFromController:(UIViewController *)presenter {
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Runtime Atlas pairing" message:@"Paste the session token shown in Controller. Confirm pairing to permit Controller commands. Interactive hooks end on disconnect; explicitly enabled launch patches can persist." preferredStyle:UIAlertControllerStyleAlert];
 [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder=@"Pairing key";NSString *candidate=UIPasteboard.generalPasteboard.string;NSCharacterSet *hex=[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];if(candidate.length==32 && [candidate rangeOfCharacterFromSet:hex.invertedSet].location==NSNotFound) field.text=candidate;field.autocorrectionType=UITextAutocorrectionTypeNo;field.autocapitalizationType=UITextAutocapitalizationTypeNone; }];
 [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
 [alert addAction:[UIAlertAction actionWithTitle:@"Pair" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
  (void)action;NSString *token=alert.textFields.firstObject.text;
  NSCharacterSet *hex=[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
  if(token.length!=32 || [token rangeOfCharacterFromSet:hex.invertedSet].location!=NSNotFound) return;
  dispatch_async(self->_queue,^{ if(self->_channel) [self disconnect:self->_channel];self->_token=token;[self connect]; });
 }]];[presenter presentViewController:alert animated:YES completion:nil];
}
- (NSDictionary *)identity { return @{@"pid":@(getpid()),@"bundle":NSBundle.mainBundle.bundleIdentifier ?: @"unknown",@"executable":NSBundle.mainBundle.executablePath ?: @"",@"bundlePath":NSBundle.mainBundle.bundlePath,@"active":@(_active)}; }
#if LX_FIXTURE_AUTOMATION
- (void)connectFixtureTestToken:(NSString *)token { dispatch_async(_queue,^{ self->_token=token;[self connect]; }); }
#endif
- (void)connect {
 if(_connecting || (_channel && !_channel.closed)) return;_connecting=YES;
 NSError *error=nil;LXChannel *channel=[LXChannel connectLoopback:&error];_connecting=NO;
 if(!channel) { _token=nil;dispatch_async(dispatch_get_main_queue(),^{
  UIViewController *presenter=[self presenter];if(!presenter || presenter.presentedViewController) return;
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Runtime Atlas connection failed" message:error.localizedDescription ?: @"Open Controller and pair again" preferredStyle:UIAlertControllerStyleAlert];[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[presenter presentViewController:alert animated:YES completion:nil];
 });return; }_channel=channel;
 __weak LXAgent *weak=self;__weak LXChannel *weakChannel=channel;
 channel.received=^(NSDictionary *m) { LXAgent *agent=weak;if(agent) dispatch_async(agent->_queue,^{ [agent handle:m channel:weakChannel]; }); };
 channel.disconnected=^{ LXAgent *agent=weak;if(agent) dispatch_async(agent->_queue,^{ [agent disconnect:weakChannel]; }); };
 [channel start];NSMutableDictionary *hello=[[self identity] mutableCopy];_authenticated=NO;_serverVerified=NO;_nonce=NSUUID.UUID.UUIDString;hello[@"nonce"]=_nonce;hello[@"proof"]=LXProof(_token,@"hello",hello);[channel send:LXMessage(@"hello",hello)];
 _heartbeat=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,_queue);
 dispatch_source_set_timer(_heartbeat,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),3*NSEC_PER_SEC,NSEC_PER_SEC/4);
 dispatch_source_set_event_handler(_heartbeat,^{ LXAgent *agent=weak;if(agent && agent->_authenticated) [weakChannel send:LXMessage(@"heartbeat",[agent identity])]; });dispatch_resume(_heartbeat);
}
- (void)disconnect:(LXChannel *)channel {
 if(channel!=_channel) return;_active=NO;_authenticated=NO;if(!_launchPatches) [_hooks disableAll];else for(NSDictionary *hook in [_hooks state]) if(!_savedPatches[hook[@"key"]]) [_hooks disableKey:hook[@"key"]];[_channel close];_channel=nil;_token=nil;_nonce=nil;
 _active=_launchPatches && _savedPatches.count>0;
 if(_heartbeat) { dispatch_source_cancel(_heartbeat);_heartbeat=nil; }[_seenCommands removeAllObjects];[_commandOrder removeAllObjects];
}
- (void)handle:(NSDictionary *)m channel:(LXChannel *)channel {
 if(channel!=_channel || channel.closed) return;
 if([m[@"command"] isEqual:@"helloChallenge"]) {
  NSDictionary *p=m[@"payload"];NSDictionary *body=@{@"agentNonce":_nonce ?: @"",@"serverNonce":[p[@"serverNonce"] isKindOfClass:NSString.class]?p[@"serverNonce"]:@""};
  if(![p[@"agentNonce"] isEqual:_nonce] || [body[@"serverNonce"] length]!=36 || !LXProofMatches(LXProof(_token,@"server",body),p[@"proof"])) { [channel close];return; }
  _serverVerified=YES;NSMutableDictionary *finish=[body mutableCopy];finish[@"proof"]=LXProof(_token,@"client",body);[channel send:LXMessage(@"helloFinish",finish)];return;
 }
 if([m[@"command"] isEqual:@"helloAck"]) { if(!_serverVerified) { [channel close];return; }_authenticated=YES;return; }
 if(!_authenticated) { [channel close];return; }
 NSString *identifier=m[@"commandID"],*command=m[@"command"];NSDictionary *p=m[@"payload"];
 NSMutableDictionary *reply=[LXMessage(command,@{}) mutableCopy];reply[@"responseID"]=identifier;
 NSDictionary *out;
 if([_seenCommands containsObject:identifier]) out=@{@"error":LXError(@"duplicate_command",@"Command already handled")};
 else {
  [_seenCommands addObject:identifier];[_commandOrder addObject:identifier];if(_commandOrder.count>256) { [_seenCommands removeObject:_commandOrder[0]];[_commandOrder removeObjectAtIndex:0]; }
  @try {
   if(_active && [@[@"images",@"classes",@"methods"] containsObject:command] && !_scanner) _scanner=[LXScanner new];
   if(_active && [command isEqual:@"static"] && !_static) _static=[LXStaticAnalyzer new];
   if([command isEqual:@"activate"]) { _active=YES;if(!_scanner) _scanner=[LXScanner new];if(!_hooks) _hooks=[LXHookEngine new];if(!_static) _static=[LXStaticAnalyzer new];out=[self identity]; }
   else if([command isEqual:@"deactivate"]) { _active=NO;_launchPatches=NO;[self saveLaunchPatches];[_hooks disableAll];out=[self identity]; }
   else if([command isEqual:@"ping"]) out=@{@"echo":p,@"sandboxProbe":@YES};
   else if(!_active) out=@{@"error":LXError(@"inactive",@"Activate this Agent explicitly first")};
   else if([command isEqual:@"images"]) out=[_scanner images];
   else if([command isEqual:@"classes"] && [p[@"image"] isKindOfClass:NSString.class] && [p[@"offset"] isKindOfClass:NSNumber.class] && [p[@"offset"] longLongValue]>=0) out=[_scanner classesInImage:p[@"image"] offset:[p[@"offset"] unsignedIntegerValue]];
   else if([command isEqual:@"methods"] && [p[@"class"] isKindOfClass:NSString.class] && (!p[@"offset"] || ([p[@"offset"] isKindOfClass:NSNumber.class] && [p[@"offset"] longLongValue]>=0))) out=[_scanner methodsInClass:p[@"class"] offset:[p[@"offset"] unsignedIntegerValue]];
   else if([command isEqual:@"hookEnable"] && [p[@"class"] isKindOfClass:NSString.class] && [p[@"selector"] isKindOfClass:NSString.class] && [p[@"classMethod"] isKindOfClass:NSNumber.class]) {
    out=[self enableProfile:p];if(!out[@"error"]) { NSMutableDictionary *profile=[@{@"class":p[@"class"],@"selector":p[@"selector"],@"classMethod":p[@"classMethod"]} mutableCopy];if(p[@"encoding"]) profile[@"encoding"]=p[@"encoding"];_methodProfiles[out[@"key"]]=profile; }
   }
   else if([command isEqual:@"patchApply"] && [p[@"key"] isKindOfClass:NSString.class] && [p[@"patch"] isKindOfClass:NSDictionary.class]) {
    if(_savedPatches.count>=128 && !_savedPatches[p[@"key"]]) out=@{@"error":LXError(@"patch_limit",@"At most 128 saved patches per app")};
    else { out=[_hooks configurePatch:p[@"patch"] key:p[@"key"]];if(!out[@"error"]) { if([p[@"patch"] count]) _savedPatches[p[@"key"]]=@{@"method":_methodProfiles[p[@"key"]] ?: @{},@"patch":p[@"patch"]};else [_savedPatches removeObjectForKey:p[@"key"]];[self saveLaunchPatches]; } }
   }
   else if([command isEqual:@"patchPolicy"] && [p[@"enabled"] isKindOfClass:NSNumber.class]) { _launchPatches=[p[@"enabled"] boolValue];[self saveLaunchPatches];out=@{@"applyOnLaunch":@(_launchPatches)}; }
   else if([command isEqual:@"hookDisable"] && [p[@"key"] isKindOfClass:NSString.class]) { out=[_hooks disableKey:p[@"key"]];[_savedPatches removeObjectForKey:p[@"key"]];[self saveLaunchPatches]; }
   else if([command isEqual:@"state"]) out=@{@"hooks":[_hooks state] ?: @[],@"active":@(_active),@"applyOnLaunch":@(_launchPatches),@"restoreErrors":_restoreErrors ?: @[]};
   else if([command isEqual:@"logs"]) out=@{@"logs":[_hooks logs]};
   else if([command isEqual:@"static"]) out=[_static analyzeBundle:NSBundle.mainBundle.bundlePath];
#if LX_FIXTURE_AUTOMATION
   else if([command isEqual:@"fixturePresenterCheck"]) {
    [self installPairingGesture];__block NSDictionary *result;dispatch_sync(dispatch_get_main_queue(),^{ UIViewController *presenter=[self presenter];result=@{@"legacyAvailable":@([self legacyPresenter]!=nil),@"available":@(presenter!=nil),@"gestureInstalled":@(objc_getAssociatedObject(presenter.view,@selector(installPairingGesture))!=nil),@"sceneCount":@(UIApplication.sharedApplication.connectedScenes.count)}; });out=result;
   }
   else if([command isEqual:@"fixtureRun"]) {
    LXFixture *fixture=[LXFixture new];[fixture ping];id marker=[NSObject new];id echoed=[fixture echo:marker];
    out=@{@"pings":@(fixture.pings),@"objectIdentity":@(echoed==marker),@"integer":@([fixture addOne:41]),@"bool":@([fixture invert:NO]),@"float":@([fixture scale:2]),@"double":@([fixture doubleValue:2.5]),@"classValue":@([LXFixture classValue])};
   }
   else if([command isEqual:@"fixtureUIKitRun"]) {
    __block NSDictionary *values;dispatch_sync(dispatch_get_main_queue(),^{
     UIView *view=[UIView new];view.hidden=YES;view.alpha=.25;
     UIViewController *controller=[UIViewController new];[controller viewWillAppear:YES];[controller viewDidAppear:YES];
     values=@{@"hidden":@(view.hidden),@"alpha":@(view.alpha)};
    });out=values;
   }
#endif
   else out=@{@"error":LXError(@"bad_command",@"Unknown command or invalid arguments")};
  } @catch(NSException *exception) { out=@{@"error":LXError(@"agent_exception",exception.name)}; }
 }
 if(out[@"error"]) reply[@"error"]=out[@"error"];reply[@"payload"]=out ?: @{};
 if([NSJSONSerialization dataWithJSONObject:reply options:0 error:nil].length>LXMaxFrame) { reply[@"payload"]=@{};reply[@"error"]=LXError(@"response_limit",@"Result exceeds frame budget; narrow analysis scope"); }
 [channel send:reply];
}
@end
