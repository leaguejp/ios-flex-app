#import <UIKit/UIKit.h>
#import "LXController.h"
#import "LXApplications.h"
#import "../static/LXStaticAnalyzer.h"
#import "../shared/LXTypes.h"
#import "../shared/LXLaunch.h"
#import "../ui/LXBrowser.h"
@interface LXApp : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation LXApp { LXController *_controller;LXBrowser *_root; UIBackgroundTaskIdentifier _background;NSArray *_installed;NSString *_inventoryFailure;NSString *_shownAnalysis;BOOL _analysisReturnReceived;BOOL _automationLaunchStarted; }
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
 (void)app;(void)options;_background=UIBackgroundTaskInvalid;_controller=[LXController new];_root=[LXBrowser new];_root.title=@"Runtime Atlas";
 self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[[UINavigationController alloc] initWithRootViewController:_root];[self.window makeKeyAndVisible];
 _root.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"Refresh" style:UIBarButtonItemStylePlain target:self action:@selector(reloadApplications)];
 __weak LXApp *weak=self;_controller.changed=^{ [weak refresh];[weak showAnalysisIfReady]; };_root.selected=^(NSDictionary *row) { if([row[@"action"] isEqual:@"manualPair"]) [weak pair];else if(row[@"application"]) [weak installedTarget:row[@"application"]];else [weak target:row[@"session"]]; };
 NSError *error=nil;if(![_controller start:&error]) dispatch_async(dispatch_get_main_queue(),^{ LXApp *strong=weak;if(strong) LXAlert(strong->_root,[NSString stringWithFormat:@"IPC listener failed: %@",error.localizedDescription]); });[self reloadApplications];return YES;
}
- (void)applicationDidEnterBackground:(UIApplication *)application {
 if(_background!=UIBackgroundTaskInvalid) [application endBackgroundTask:_background];
 _background=[application beginBackgroundTaskWithName:@"RuntimeAtlas pairing grace" expirationHandler:^{ [self->_controller cancelAnalysis:@"iOS ended the background analysis window. Retry analysis; prior results are retained."];if(self->_background!=UIBackgroundTaskInvalid) { [application endBackgroundTask:self->_background];self->_background=UIBackgroundTaskInvalid; } }];
}
- (void)applicationWillEnterForeground:(UIApplication *)application { [self reloadApplications];dispatch_async(dispatch_get_main_queue(),^{ [self showAnalysisIfReady]; }); if(_background!=UIBackgroundTaskInvalid) { [application endBackgroundTask:_background];_background=UIBackgroundTaskInvalid; } }
- (void)applicationDidBecomeActive:(UIApplication *)application { (void)application;[self showAnalysisIfReady];
#if LX_CONTROLLER_AUTOMATION
 [self writeLaunchTest];
#endif
}
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
 (void)application;(void)options;if(![url.scheme isEqual:@"runtimeatlas"] || ![url.host isEqual:@"analysis"]) return NO;
 NSString *request=nil;for(NSURLQueryItem *item in [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO].queryItems) if([item.name isEqual:@"requestID"]) request=item.value;
 if(![request isEqual:_controller.analysis[@"requestID"]]) return NO;_analysisReturnReceived=YES;[self showAnalysisIfReady];
#if LX_CONTROLLER_AUTOMATION
 [self writeLaunchTest];
#endif
 return YES;
}
- (void)startAnalysis:(NSDictionary *)application parent:(UIViewController *)parent {
 _analysisReturnReceived=NO;NSString *ticket=[_controller prepareAnalysisForBundle:application[@"bundle"]];if(!ticket) { LXAlert(parent,@"An analysis is already running. Return after it finishes, or retry after the timeout.");return; }
 [UIPasteboard.generalPasteboard setItems:@[@{LXAnalysisPasteboardType(application[@"bundle"]):[ticket dataUsingEncoding:NSUTF8StringEncoding]}] options:@{UIPasteboardOptionLocalOnly:@YES,UIPasteboardOptionExpirationDate:[NSDate dateWithTimeIntervalSinceNow:90]}];
 if(![LXApplications openBundle:application[@"bundle"]]) LXAlert(parent,@"Automatic launch is unavailable. Open the selected app from Home Screen now; the Agent will capture its loaded methods and return to Atlas. If it does not return, switch back and check the status.");
}
- (void)showAnalysisIfReady {
 NSDictionary *job=_controller.analysis;if(!job || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive || [job[@"requestID"] isEqual:_shownAnalysis]) return;
 if(![@[@"complete",@"failed"] containsObject:job[@"status"]]) return;_shownAnalysis=job[@"requestID"];
 NSData *ticketData=[UIPasteboard.generalPasteboard dataForPasteboardType:LXAnalysisPasteboardType(job[@"bundle"])];NSDictionary *ticket=LXReadAnalysisTicket([[NSString alloc] initWithData:ticketData encoding:NSUTF8StringEncoding],job[@"bundle"],NSDate.date.timeIntervalSince1970);if([ticket[@"requestID"] isEqual:job[@"requestID"]]) UIPasteboard.generalPasteboard.items=@[];
 if([job[@"status"] isEqual:@"failed"]) { LXAlert(_root.navigationController.topViewController,job[@"detail"]);return; }
 NSDictionary *catalog=[_controller.store stateForBundle:job[@"bundle"]][@"runtimeCatalog"];
 [self capturedCatalog:catalog parent:_root.navigationController.topViewController];
#if LX_CONTROLLER_AUTOMATION
 [self writeLaunchTest];
#endif
}
#if LX_CONTROLLER_AUTOMATION
- (void)writeLaunchTest {
 if(![NSProcessInfo.processInfo.arguments containsObject:@"--lx-test-launch-analysis"] || ![@[@"complete",@"failed"] containsObject:_controller.analysis[@"status"]]) return;
 NSDictionary *catalog=[_controller.store stateForBundle:_controller.analysis[@"bundle"]][@"runtimeCatalog"] ?: @{};
 NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"analysis":_controller.analysis,@"catalog":catalog,@"returned":@(_analysisReturnReceived),@"foreground":@(UIApplication.sharedApplication.applicationState==UIApplicationStateActive),@"visibleTitle":_root.navigationController.topViewController.title ?: @""} options:NSJSONWritingPrettyPrinted error:nil];
 NSAssert(![[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] containsString:_controller.token],@"Launch evidence must not contain authentication key");
 NSURL *documents=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;[data writeToURL:[documents URLByAppendingPathComponent:@"launch-analysis-test.json"] atomically:YES];
}
#endif
- (void)capturedCatalog:(NSDictionary *)catalog parent:(UIViewController *)parent {
 if(!catalog) { LXAlert(parent,@"No saved runtime capture. Choose Analyze app first.");return; }
 LXBrowser *view=[LXBrowser new];view.title=@"Captured Runtime Loaded";NSMutableArray *rows=[NSMutableArray new];NSDictionary *metadata=catalog[@"metadata"];
 [rows addObject:@{@"title":[NSString stringWithFormat:@"%@ classes · %@ methods",metadata[@"classCount"],metadata[@"methodCount"]],@"subtitle":[NSString stringWithFormat:@"Captured %@ · %@",[NSDate dateWithTimeIntervalSince1970:[metadata[@"capturedAt"] doubleValue]], [metadata[@"partial"] boolValue]?@"Partial — see diagnostics":@"App bundle snapshot"],@"action":@"info"}];
 for(NSDictionary *image in catalog[@"images"]) [rows addObject:@{@"title":image[@"name"],@"subtitle":[NSString stringWithFormat:@"%lu classes · Runtime Loaded at capture",(unsigned long)[image[@"classes"] count]],@"image":image}];view.rows=rows;__weak LXBrowser *weak=view;
 view.selected=^(NSDictionary *row) {
  if([row[@"action"] isEqual:@"info"]) { LXShowJSON(weak,@"Capture counts / diagnostics",metadata);return; }
  NSDictionary *image=row[@"image"];LXBrowser *classes=[LXBrowser new];classes.title=image[@"name"];NSMutableArray *classRows=[NSMutableArray new];
  for(NSDictionary *cls in image[@"classes"]) [classRows addObject:@{@"title":cls[@"name"],@"subtitle":[NSString stringWithFormat:@"%lu methods · superclass %@",(unsigned long)[cls[@"methods"] count],cls[@"superclass"]],@"class":cls}];
  if(!classRows.count) [classRows addObject:@{@"title":@"No Objective-C classes in this image",@"subtitle":@"See capture diagnostics; Swift-only/native code may expose none",@"enabled":@NO}];classes.rows=classRows;__weak LXBrowser *weakClasses=classes;
  classes.selected=^(NSDictionary *item) { [self methods:item[@"class"][@"methods"] bundle:catalog[@"bundle"] session:nil parent:weakClasses]; };
  [weak.navigationController pushViewController:classes animated:YES];
 };[parent.navigationController pushViewController:view animated:YES];
}
- (void)pair { UIPasteboard.generalPasteboard.string=_controller.token;LXAlert(_root,[NSString stringWithFormat:@"Session token copied:\n%@\n\nIn target app, tap three times with three fingers and paste token. Return here promptly to activate. Background execution is finite; suspension disconnects the Agent and disables interactive hooks. Authorized launch patches may remain active.",_controller.token]); }
- (void)reloadApplications {
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{ NSString *failure=nil;NSArray *apps=[LXApplications installed:&failure];dispatch_async(dispatch_get_main_queue(),^{ self->_installed=apps;self->_inventoryFailure=failure;[self refresh];
#if LX_CONTROLLER_AUTOMATION
 if([NSProcessInfo.processInfo.arguments containsObject:@"--lx-test-launch-analysis"] && !self->_automationLaunchStarted) { for(NSDictionary *application in apps) if([application[@"bundle"] isEqual:@"jp.league.runtimeatlas.fixture"]) { self->_automationLaunchStarted=YES;[self startAnalysis:application parent:self->_root];break; } }
 if([NSProcessInfo.processInfo.arguments containsObject:@"--lx-test-inventory"]) {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{ NSDictionary *analysis=@{};for(NSDictionary *app in apps) if([app[@"bundle"] isEqual:@"jp.league.runtimeatlas.fixture"]) { analysis=[[LXStaticAnalyzer new] analyzeBundle:app[@"bundlePath"]];break; }
   NSURL *documents=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"applications":apps,@"failure":failure ?: @"",@"static":analysis} options:NSJSONWritingPrettyPrinted error:nil];[data writeToURL:[documents URLByAppendingPathComponent:@"inventory-test.json"] atomically:YES];
  });
 }
#endif
 }); });
}
- (void)refresh {
 NSMutableArray *rows=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
 for(NSDictionary *app in _installed) {
  NSString *bundle=app[@"bundle"];LXSession *connected=nil;for(LXSession *s in _controller.sessions) if([s.identity[@"bundle"] isEqual:bundle]) { connected=s;break; }
  NSMutableDictionary *row=[@{@"title":app[@"name"],@"subtitle":[NSString stringWithFormat:@"%@ · %@",bundle,connected?(connected.active?@"Agent Active":@"Agent Connected"):@"Installed · Agent Offline"],@"application":app} mutableCopy];if(connected) row[@"session"]=connected;[rows addObject:row];[seen addObject:bundle];
 }
 for(LXSession *s in _controller.sessions) if(![seen containsObject:s.identity[@"bundle"]]) [rows addObject:@{@"title":s.identity[@"bundle"],@"subtitle":[NSString stringWithFormat:@"Agent %@ · PID %@",s.active?@"Active":@"Connected",s.identity[@"pid"]],@"session":s}];
 NSDictionary *job=_controller.analysis;if([@[@"waiting",@"capturing"] containsObject:job[@"status"]]) [rows insertObject:@{@"title":[@"Analyzing " stringByAppendingString:job[@"bundle"]],@"subtitle":job[@"detail"],@"enabled":@NO} atIndex:0];
 if(!_installed.count) [rows addObject:@{@"title":@"Connect an app manually",@"subtitle":_inventoryFailure ?: @"Installed-app inventory is empty",@"action":@"manualPair"}];
 _root.rows=rows;
 if(!rows.count) { UILabel *label=[UILabel new];label.text=_inventoryFailure ?: @"No installed target applications found";label.numberOfLines=0;label.textAlignment=NSTextAlignmentCenter;label.textColor=UIColor.secondaryLabelColor;label.font=[UIFont systemFontOfSize:15];_root.tableView.backgroundView=label; }else _root.tableView.backgroundView=nil;
}
- (void)installedTarget:(NSDictionary *)application {
 NSString *bundle=application[@"bundle"];LXBrowser *menu=[LXBrowser new];menu.title=application[@"name"];
 menu.rows=@[@{@"title":@"Analyze app / return to Atlas",@"subtitle":@"Open app → capture loaded methods → show saved results",@"action":@"runtimeCapture"},@{@"title":@"Live Agent controls",@"subtitle":@"Runtime browsing, hooks, logs and launch policy",@"action":@"controls"},@{@"title":@"Saved runtime analysis",@"subtitle":@"Browse captured methods while the target is offline",@"action":@"catalog"},@{@"title":@"Analyze installed bundle",@"subtitle":@"Static Only · no running process required",@"action":@"static"},@{@"title":@"Enable analysis / open app",@"subtitle":@"Pair Agent, then activate from this app",@"action":@"open"},@{@"title":@"Saved patches / settings",@"subtitle":@"Available while Agent is offline",@"action":@"saved"},@{@"title":@"Export saved JSON",@"subtitle":@"Saved settings, patches and history",@"action":@"export"}];
 __weak LXBrowser *weakMenu=menu;menu.selected=^(NSDictionary *row) {
  if([row[@"action"] isEqual:@"controls"]) { LXSession *session=nil;for(LXSession *candidate in self->_controller.sessions) if([candidate.identity[@"bundle"] isEqual:bundle]) session=candidate;if(session) [self target:session];else LXAlert(weakMenu,@"No live Agent connection. Use Enable analysis / open app for manual pairing. Saved runtime results remain browsable.");return; }
  if([row[@"action"] isEqual:@"runtimeCapture"]) { [self startAnalysis:application parent:weakMenu];return; }
  if([row[@"action"] isEqual:@"catalog"]) { [self capturedCatalog:[self->_controller.store stateForBundle:bundle][@"runtimeCatalog"] parent:weakMenu];return; }
  if([row[@"action"] isEqual:@"static"]) {
   NSString *path=application[@"bundlePath"];if(!path.length) { LXAlert(weakMenu,@"LaunchServices did not provide a bundle path. Connect the Agent to analyze its own bundle.");return; }
   dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{ NSDictionary *result;@try { result=[[LXStaticAnalyzer new] analyzeBundle:path]; } @catch(NSException *exception) { result=@{@"images":@[],@"errors":@[@{@"code":@"static_exception",@"detail":exception.name}],@"provenance":@"Static Only"}; }
    dispatch_async(dispatch_get_main_queue(),^{ NSMutableDictionary *state=[[self->_controller.store stateForBundle:bundle] mutableCopy];NSMutableArray *history=[state[@"history"] mutableCopy] ?: [NSMutableArray new];[history addObject:@{@"command":@"staticOffline",@"response":result,@"time":@(NSDate.date.timeIntervalSince1970)}];while(history.count>8) [history removeObjectAtIndex:0];state[@"history"]=history;BOOL saved=[self->_controller.store save:state bundle:bundle];[self images:result[@"images"] session:nil parent:weakMenu runtime:NO];if(!saved || [result[@"errors"] count]) LXShowJSON(weakMenu,@"Static analysis diagnostics",@{@"saved":@(saved),@"errors":result[@"errors"] ?: @[]}); });
   });return;
  }
  if([row[@"action"] isEqual:@"export"]) { NSError *error=nil;NSURL *url=[self->_controller.store exportBundle:bundle error:&error];if(!url) { LXAlert(weakMenu,error.localizedDescription);return; }UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];share.popoverPresentationController.sourceView=weakMenu.view;[weakMenu presentViewController:share animated:YES completion:nil];return; }
  if([row[@"action"] isEqual:@"saved"]) { [self savedPatchesForBundle:bundle session:nil parent:weakMenu];return; }
  UIPasteboard.generalPasteboard.string=self->_controller.token;
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Connect selected app" message:@"The pairing key is copied internally. Open the app, tap three times with three fingers, and confirm Pair. Return here to activate and create patches. If no gesture appears, verify tweak injection and restart the target app." preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:@"Open app" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { (void)action;if(![LXApplications openBundle:bundle]) LXAlert(weakMenu,@"Automatic launch is unavailable. Open the selected app from the Home Screen."); }]];[weakMenu presentViewController:alert animated:YES completion:nil];
 };[_root.navigationController pushViewController:menu animated:YES];
}
- (void)request:(NSString *)command payload:(NSDictionary *)payload session:(LXSession *)s view:(UIViewController *)view done:(void (^)(NSDictionary *))done {
 [_controller request:command payload:payload session:s completion:^(NSDictionary *r) { if(r[@"error"] && r[@"error"]!=NSNull.null) LXAlert(view,[NSString stringWithFormat:@"%@: %@",r[@"error"][@"code"],r[@"error"][@"detail"]]);else { done(r[@"payload"] ?: @{});if(r[@"persistenceWarning"]) LXAlert(view,r[@"persistenceWarning"]); } }];
}
- (void)target:(LXSession *)s {
 LXBrowser *menu=[LXBrowser new];menu.title=s.identity[@"bundle"];
 NSArray *actions=@[@"Connection details",@"Activate Agent",@"Runtime Loaded images",@"Static Only bundle",@"Hook state",@"Saved patches",@"Enable saved patches on launch",@"Disable saved patches on launch",@"Logs",@"Export JSON",@"Saved settings / history",@"IPC feasibility ping",@"Deactivate Agent"];
 NSMutableArray *rows=[NSMutableArray new];for(NSString *action in actions) [rows addObject:@{@"title":action,@"subtitle":@"",@"action":action}];menu.rows=rows;__weak LXApp *weak=self;__weak LXBrowser *weakMenu=menu;
 menu.selected=^(NSDictionary *row) {
  LXApp *a=weak;LXBrowser *v=weakMenu;NSString *action=row[@"action"];
  if([action isEqual:@"Connection details"]) { NSMutableDictionary *identity=[s.identity mutableCopy];identity[@"active"]=@(s.active);identity[@"authenticated"]=@(s.authenticated);LXShowJSON(v,action,identity); }
  else if([action isEqual:@"Activate Agent"] || [action isEqual:@"Deactivate Agent"]) [a request:[action hasPrefix:@"Activate"]?@"activate":@"deactivate" payload:@{} session:s view:v done:^(NSDictionary *p) { LXShowJSON(v,action,p);[a refresh]; }];
  else if([action isEqual:@"Runtime Loaded images"]) [a request:@"images" payload:@{} session:s view:v done:^(NSDictionary *p) { [a images:p[@"images"] session:s parent:v runtime:YES]; }];
  else if([action isEqual:@"Static Only bundle"]) [a request:@"static" payload:@{} session:s view:v done:^(NSDictionary *p) { [a images:p[@"images"] session:s parent:v runtime:NO];if([p[@"errors"] count]) LXAlert(v,[NSString stringWithFormat:@"%lu static errors; included in saved/exported result",(unsigned long)[p[@"errors"] count]]); }];
  else if([action containsString:@"saved patches on launch"]) [a request:@"patchPolicy" payload:@{@"enabled":@([action hasPrefix:@"Enable"])} session:s view:v done:^(NSDictionary *p) { LXShowJSON(v,action,p); }];
  else if([action isEqual:@"Saved patches"]) [a savedPatches:s parent:v];
  else if([action isEqual:@"Hook state"]) [a request:@"state" payload:@{} session:s view:v done:^(NSDictionary *p) { LXShowJSON(v,action,p); }];
  else if([action isEqual:@"Logs"]) [a request:@"logs" payload:@{} session:s view:v done:^(NSDictionary *p) { [a logs:p[@"logs"] parent:v]; }];
  else if([action isEqual:@"Saved settings / history"]) LXShowJSON(v,action,[a->_controller.store stateForBundle:s.identity[@"bundle"]]);
  else if([action isEqual:@"IPC feasibility ping"]) [a request:@"ping" payload:@{@"nonce":NSUUID.UUID.UUIDString} session:s view:v done:^(NSDictionary *p) { LXShowJSON(v,@"Bidirectional IPC result",p); }];
  else if([action isEqual:@"Export JSON"]) [a request:@"logs" payload:@{} session:s view:v done:^(NSDictionary *logs) {
   (void)logs;[a request:@"state" payload:@{} session:s view:v done:^(NSDictionary *p) { (void)p;NSError *error=nil;NSURL *url=[a->_controller.store exportBundle:s.identity[@"bundle"] error:&error];if(!url) { LXAlert(v,error.localizedDescription);return; }
    UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];share.popoverPresentationController.sourceView=v.view;[v presentViewController:share animated:YES completion:nil]; }];
  }];
 };[_root.navigationController pushViewController:menu animated:YES];
}
- (void)images:(NSArray *)images session:(LXSession *)s parent:(UIViewController *)parent runtime:(BOOL)runtime {
 LXBrowser *view=[LXBrowser new];view.title=runtime?@"Runtime Loaded":@"Static Only";NSMutableArray *rows=[NSMutableArray new];
 for(NSDictionary *image in images) [rows addObject:@{@"title":image[@"name"],@"subtitle":[NSString stringWithFormat:@"%@ · %@",image[@"provenance"],image[@"path"]],@"image":image}];if(runtime) [rows addObject:@{@"title":@"Runtime Generated classes",@"subtitle":@"Registered classes without a Mach-O image",@"image":@{@"name":@"Runtime Generated",@"path":@"runtime://generated",@"kind":@"virtualClassGroup"}}];
 view.rows=rows;__weak LXApp *weak=self;__weak LXBrowser *weakView=view;
 view.selected=^(NSDictionary *row) { NSDictionary *image=row[@"image"];if(!runtime) {
   LXBrowser *classes=[LXBrowser new];classes.title=[image[@"name"] stringByAppendingString:@" · Static Only"];NSMutableArray *classRows=[NSMutableArray new];
   for(NSDictionary *cls in image[@"classes"]) [classRows addObject:@{@"title":cls[@"name"],@"subtitle":@"Static Only · runtime verification required",@"class":cls}];
   [classRows addObject:@{@"title":@"Mach-O metadata / limitations",@"subtitle":@"Architecture, UUID, dependencies and partial metadata",@"action":@"info"}];classes.rows=classRows;__weak LXBrowser *weakClasses=classes;
   classes.selected=^(NSDictionary *item) { if([item[@"action"] isEqual:@"info"]) LXShowJSON(weakClasses,@"Static Only metadata",image);else [weak methods:item[@"class"][@"methods"] bundle:image[@"bundle"] session:s parent:weakClasses]; };
   [weakView.navigationController pushViewController:classes animated:YES];return;
  }
  LXBrowser *classes=[LXBrowser new];classes.title=image[@"name"];[weakView.navigationController pushViewController:classes animated:YES];[weak classes:image[@"path"] offset:0 accumulated:@[] session:s view:classes];
 };[parent.navigationController pushViewController:view animated:YES];
}
- (void)classes:(NSString *)image offset:(NSUInteger)offset accumulated:(NSArray *)previous session:(LXSession *)s view:(LXBrowser *)view {
 __weak LXApp *weak=self;__weak LXBrowser *weakView=view;
 [self request:@"classes" payload:@{@"image":image,@"offset":@(offset)} session:s view:view done:^(NSDictionary *p) {
  NSMutableArray *all=[previous mutableCopy];[all addObjectsFromArray:p[@"classes"] ?: @[]];
  if([p[@"next"] unsignedIntegerValue]<[p[@"total"] unsignedIntegerValue]) { [weak classes:image offset:[p[@"next"] unsignedIntegerValue] accumulated:all session:s view:weakView];return; }
  NSMutableArray *rows=[NSMutableArray new];for(NSDictionary *cls in all) [rows addObject:@{@"title":cls[@"name"],@"subtitle":[NSString stringWithFormat:@"Runtime Loaded · superclass %@",cls[@"superclass"]],@"class":cls}];weakView.rows=rows;
  weakView.selected=^(NSDictionary *row) { [weak loadMethods:row[@"class"][@"name"] offset:0 accumulated:@[] session:s parent:weakView]; };
 }];
}
- (void)loadMethods:(NSString *)name offset:(NSUInteger)offset accumulated:(NSArray *)previous session:(LXSession *)s parent:(UIViewController *)parent {
 __weak LXApp *weak=self;
 [self request:@"methods" payload:@{@"class":name,@"offset":@(offset)} session:s view:parent done:^(NSDictionary *p) {
  NSMutableArray *all=[previous mutableCopy];[all addObjectsFromArray:p[@"methods"] ?: @[]];
  if([p[@"next"] unsignedIntegerValue]<[p[@"total"] unsignedIntegerValue]) [weak loadMethods:name offset:[p[@"next"] unsignedIntegerValue] accumulated:all session:s parent:parent];
  else [weak methods:all bundle:s.identity[@"bundle"] session:s parent:parent];
 }];
}
- (void)methods:(NSArray *)methods bundle:(NSString *)bundle session:(LXSession *)s parent:(UIViewController *)parent {
 LXBrowser *view=[LXBrowser new];view.title=@"Methods";NSMutableArray *rows=[NSMutableArray new];
 for(NSDictionary *method in methods) [rows addObject:@{@"title":[NSString stringWithFormat:@"%@ %@",[method[@"classMethod"] boolValue]?@"+":@"-",method[@"selector"]],@"subtitle":[NSString stringWithFormat:@"%@ · %@",method[@"encoding"],[method[@"supported"] boolValue]?@"Hook supported":method[@"unsupportedReason"]],@"method":method}];view.rows=rows;__weak LXApp *weak=self;__weak LXBrowser *weakView=view;
 view.selected=^(NSDictionary *row) {
  NSDictionary *m=row[@"method"];LXBrowser *detail=[LXBrowser new];detail.title=m[@"selector"];
  detail.rows=@[@{@"title":@"Selector / type encoding / provenance",@"subtitle":m[@"encoding"],@"action":@"info"},@{@"title":@"Enable hook",@"subtitle":[m[@"supported"] boolValue]?@"Reviewed ABI":m[@"unsupportedReason"],@"action":@"enable",@"enabled":@(s!=nil && [m[@"supported"] boolValue])},@{@"title":@"Create / save scalar patch",@"subtitle":@"Save definition; verify runtime types before applying",@"action":@"patch",@"enabled":m[@"supported"]},@{@"title":@"Disable hook",@"subtitle":@"Restores original if no conflict",@"action":@"disable",@"enabled":@(s!=nil && [m[@"supported"] boolValue])}];
  __weak LXBrowser *weakDetail=detail;detail.selected=^(NSDictionary *item) {
   NSString *action=item[@"action"];if([action isEqual:@"info"]) { LXShowJSON(weakDetail,@"Method metadata",m);return; }
   if(![m[@"supported"] boolValue]) { LXAlert(weakDetail,m[@"unsupportedReason"]);return; }
   NSString *key=[NSString stringWithFormat:@"%@%@/%@",[m[@"classMethod"] boolValue]?@"+":@"-",m[@"class"],m[@"selector"]];
   if([action isEqual:@"patch"]) { [weak editPatch:m key:key bundle:bundle session:s parent:weakDetail];return; }
   [weak request:[action isEqual:@"enable"]?@"hookEnable":@"hookDisable" payload:[action isEqual:@"enable"]?m:@{@"key":key} session:s view:weakDetail done:^(NSDictionary *result) { LXShowJSON(weakDetail,@"Hook result",result); }];
  };[weakView.navigationController pushViewController:detail animated:YES];
 };[parent.navigationController pushViewController:view animated:YES];
}
- (void)editPatch:(NSDictionary *)method key:(NSString *)key bundle:(NSString *)bundle session:(LXSession *)session parent:(UIViewController *)parent {
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Scalar patch" message:@"Leave a field empty to preserve its value. BOOL: 0 or 1. Only supported scalar fields are accepted. Original always runs; return override follows original." preferredStyle:UIAlertControllerStyleAlert];
 NSDictionary *saved=[_controller.store stateForBundle:bundle][@"patches"][key];NSUInteger index=0;
 for(NSString *hint in @[@"Argument 1 override",@"Return value override"]) { NSString *fieldKey=index++==0?@"argument":@"return";[alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder=hint;field.keyboardType=UIKeyboardTypeNumbersAndPunctuation;if([saved[fieldKey] isKindOfClass:NSNumber.class]) field.text=[saved[fieldKey] stringValue]; }]; }
 [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
 [alert addAction:[UIAlertAction actionWithTitle:session?@"Save and apply":@"Save patch" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
  (void)action;NSMutableDictionary *patch=[NSMutableDictionary new];NSArray *keys=@[@"argument",@"return"];
  for(NSUInteger i=0;i<2;i++) { NSString *text=[alert.textFields[i].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(!text.length) continue;
   NSData *bytes=[text dataUsingEncoding:NSUTF8StringEncoding];id number=[NSJSONSerialization JSONObjectWithData:bytes options:NSJSONReadingFragmentsAllowed error:nil];if(![number isKindOfClass:NSNumber.class]) { LXAlert(parent,@"Enter a JSON number; BOOL uses 0 or 1.");return; }patch[keys[i]]=number;
  }
  NSString *reason=LXPatchReason(patch,method[@"encoding"]);if(reason) { LXAlert(parent,reason);return; }
  reason=[self->_controller.store savePatch:patch method:method bundle:bundle];if(reason) { LXAlert(parent,reason);return; }
  if(!session) { LXAlert(parent,@"Patch saved for this app. Connect its Agent, activate analysis, then apply it from Saved patches. Enable saved patches on launch once transferred to the Agent. Static metadata has not been verified against a running process.");return; }
  [self request:@"hookEnable" payload:method session:session view:parent done:^(NSDictionary *result) { (void)result;[self request:@"patchApply" payload:@{@"key":key,@"patch":patch} session:session view:parent done:^(NSDictionary *applied) { LXShowJSON(parent,@"Patch applied",applied); }]; }];
 }]];[parent presentViewController:alert animated:YES completion:nil];
}
- (void)savedPatches:(LXSession *)session parent:(UIViewController *)parent { [self savedPatchesForBundle:session.identity[@"bundle"] session:session parent:parent]; }
- (void)savedPatchesForBundle:(NSString *)bundle session:(LXSession *)session parent:(UIViewController *)parent {
 NSDictionary *state=[_controller.store stateForBundle:bundle];NSDictionary *patches=state[@"patches"] ?: @{};NSDictionary *desired=state[@"desiredHooks"] ?: @{};
 LXBrowser *view=[LXBrowser new];view.title=@"Saved patches";NSMutableArray *rows=[NSMutableArray new];for(NSString *key in [[patches allKeys] sortedArrayUsingSelector:@selector(compare:)]) [rows addObject:@{@"title":key,@"subtitle":[NSString stringWithFormat:@"%@ · %@",session?@"Agent connected":@"Saved offline",patches[key]],@"key":key}];view.rows=rows;__weak LXBrowser *weak=view;
 view.selected=^(NSDictionary *row) { NSString *key=row[@"key"];NSDictionary *method=desired[key][@"request"];
  if(![method[@"class"] isKindOfClass:NSString.class] || ![method[@"selector"] isKindOfClass:NSString.class] || ![method[@"encoding"] isKindOfClass:NSString.class]) { LXAlert(weak,@"Saved method metadata is unavailable; reopen method details.");return; }
  UIAlertController *menu=[UIAlertController alertControllerWithTitle:key message:@"Saved definitions are separate from running hook state. Applying always verifies the live method and delegates to its original implementation." preferredStyle:UIAlertControllerStyleActionSheet];
  [menu addAction:[UIAlertAction actionWithTitle:@"Edit patch" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { (void)action;[self editPatch:method key:key bundle:bundle session:session parent:weak]; }]];
  if(session) {
   [menu addAction:[UIAlertAction actionWithTitle:@"Apply patch" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { (void)action;NSString *reason=LXPatchReason(patches[key],method[@"encoding"]);if(reason) { LXAlert(weak,reason);return; }[self request:@"hookEnable" payload:method session:session view:weak done:^(NSDictionary *result) { (void)result;[self request:@"patchApply" payload:@{@"key":key,@"patch":patches[key]} session:session view:weak done:^(NSDictionary *applied) { LXShowJSON(weak,@"Saved patch applied",applied); }]; }]; }]];
   [menu addAction:[UIAlertAction actionWithTitle:@"Disable patch" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { (void)action;[self request:@"hookDisable" payload:@{@"key":key} session:session view:weak done:^(NSDictionary *result) { LXShowJSON(weak,@"Patch disabled",result); }]; }]];
  }
  [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];menu.popoverPresentationController.sourceView=weak.view;[weak presentViewController:menu animated:YES completion:nil];
 };[parent.navigationController pushViewController:view animated:YES];
}
- (void)logs:(NSArray *)logs parent:(UIViewController *)parent {
 LXBrowser *view=[LXBrowser new];view.title=@"Bounded call logs";NSMutableArray *rows=[NSMutableArray new];
 for(NSDictionary *event in logs.reverseObjectEnumerator) [rows addObject:@{@"title":event[@"hook"],@"subtitle":[NSString stringWithFormat:@"%@ · thread %@ · %@ ns",event[@"time"],event[@"thread"],event[@"durationNs"]],@"event":event}];view.rows=rows;__weak LXBrowser *weak=view;view.selected=^(NSDictionary *row) { LXShowJSON(weak,@"Call details",row[@"event"]); };[parent.navigationController pushViewController:view animated:YES];
}
@end
int main(int argc,char **argv) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(LXApp.class)); } }
