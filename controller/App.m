#import <UIKit/UIKit.h>
#import "LXController.h"
#import "../ui/LXBrowser.h"
@interface LXApp : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation LXApp { LXController *_controller;LXBrowser *_root; UIBackgroundTaskIdentifier _background; }
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
 (void)app;(void)options;_background=UIBackgroundTaskInvalid;_controller=[LXController new];_root=[LXBrowser new];_root.title=@"Runtime Atlas";
 self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[[UINavigationController alloc] initWithRootViewController:_root];[self.window makeKeyAndVisible];
 _root.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"Pair" style:UIBarButtonItemStylePlain target:self action:@selector(pair)];
 __weak LXApp *weak=self;_controller.changed=^{ [weak refresh]; };_root.selected=^(NSDictionary *row) { [weak target:row[@"session"]]; };
 NSError *error=nil;if(![_controller start:&error]) dispatch_async(dispatch_get_main_queue(),^{ LXApp *strong=weak;if(strong) LXAlert(strong->_root,[NSString stringWithFormat:@"IPC listener failed: %@",error.localizedDescription]); });[self refresh];return YES;
}
- (void)applicationDidEnterBackground:(UIApplication *)application {
 if(_background!=UIBackgroundTaskInvalid) [application endBackgroundTask:_background];
 _background=[application beginBackgroundTaskWithName:@"RuntimeAtlas pairing grace" expirationHandler:^{ if(self->_background!=UIBackgroundTaskInvalid) { [application endBackgroundTask:self->_background];self->_background=UIBackgroundTaskInvalid; } }];
}
- (void)applicationWillEnterForeground:(UIApplication *)application { if(_background!=UIBackgroundTaskInvalid) { [application endBackgroundTask:_background];_background=UIBackgroundTaskInvalid; } }
- (void)pair { UIPasteboard.generalPasteboard.string=_controller.token;LXAlert(_root,[NSString stringWithFormat:@"Session token copied:\n%@\n\nIn target app, tap three times with three fingers and paste token. Return here promptly to activate. Background execution is finite; suspension disconnects the Agent and disables hooks.",_controller.token]); }
- (void)refresh { NSMutableArray *rows=[NSMutableArray new];for(LXSession *s in _controller.sessions) [rows addObject:@{@"title":[NSString stringWithFormat:@"%@ · PID %@",s.identity[@"bundle"],s.identity[@"pid"]],@"subtitle":[NSString stringWithFormat:@"Agent %@ · %@",s.active?@"Active":@"Connected",s.identity[@"executable"]],@"session":s}];_root.rows=rows;
 if(!rows.count) { UILabel *label=[UILabel new];label.text=@"No paired Agents\n\nChoose Pair to copy a session token.\nOpen an authorized target app,\nthen tap three times with three fingers.\n\nReturn here to select and activate it.";label.numberOfLines=0;label.textAlignment=NSTextAlignmentCenter;label.textColor=UIColor.secondaryLabelColor;label.font=[UIFont systemFontOfSize:15];_root.tableView.backgroundView=label; }else _root.tableView.backgroundView=nil;
}
- (void)request:(NSString *)command payload:(NSDictionary *)payload session:(LXSession *)s view:(UIViewController *)view done:(void (^)(NSDictionary *))done {
 [_controller request:command payload:payload session:s completion:^(NSDictionary *r) { if(r[@"error"] && r[@"error"]!=NSNull.null) LXAlert(view,[NSString stringWithFormat:@"%@: %@",r[@"error"][@"code"],r[@"error"][@"detail"]]);else { done(r[@"payload"] ?: @{});if(r[@"persistenceWarning"]) LXAlert(view,r[@"persistenceWarning"]); } }];
}
- (void)target:(LXSession *)s {
 LXBrowser *menu=[LXBrowser new];menu.title=s.identity[@"bundle"];
 NSArray *actions=@[@"Activate Agent",@"Runtime Loaded images",@"Static Only bundle",@"Hook state",@"Logs",@"Export JSON",@"Saved settings / history",@"IPC feasibility ping",@"Deactivate Agent"];
 NSMutableArray *rows=[NSMutableArray new];for(NSString *action in actions) [rows addObject:@{@"title":action,@"subtitle":@"",@"action":action}];menu.rows=rows;__weak LXApp *weak=self;__weak LXBrowser *weakMenu=menu;
 menu.selected=^(NSDictionary *row) {
  LXApp *a=weak;LXBrowser *v=weakMenu;NSString *action=row[@"action"];
  if([action isEqual:@"Activate Agent"] || [action isEqual:@"Deactivate Agent"]) [a request:[action hasPrefix:@"Activate"]?@"activate":@"deactivate" payload:@{} session:s view:v done:^(NSDictionary *p) { LXShowJSON(v,action,p);[a refresh]; }];
  else if([action isEqual:@"Runtime Loaded images"]) [a request:@"images" payload:@{} session:s view:v done:^(NSDictionary *p) { [a images:p[@"images"] session:s parent:v runtime:YES]; }];
  else if([action isEqual:@"Static Only bundle"]) [a request:@"static" payload:@{} session:s view:v done:^(NSDictionary *p) { [a images:p[@"images"] session:s parent:v runtime:NO];if([p[@"errors"] count]) LXAlert(v,[NSString stringWithFormat:@"%lu static errors; included in saved/exported result",(unsigned long)[p[@"errors"] count]]); }];
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
 for(NSDictionary *image in images) [rows addObject:@{@"title":image[@"name"],@"subtitle":[NSString stringWithFormat:@"%@ · %@",image[@"provenance"],image[@"path"]],@"image":image}];view.rows=rows;__weak LXApp *weak=self;__weak LXBrowser *weakView=view;
 view.selected=^(NSDictionary *row) { NSDictionary *image=row[@"image"];if(!runtime) { LXShowJSON(weakView,@"Static Only metadata",image);return; }
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
  else [weak methods:all session:s parent:parent];
 }];
}
- (void)methods:(NSArray *)methods session:(LXSession *)s parent:(UIViewController *)parent {
 LXBrowser *view=[LXBrowser new];view.title=@"Methods";NSMutableArray *rows=[NSMutableArray new];
 for(NSDictionary *method in methods) [rows addObject:@{@"title":[NSString stringWithFormat:@"%@ %@",[method[@"classMethod"] boolValue]?@"+":@"-",method[@"selector"]],@"subtitle":[NSString stringWithFormat:@"%@ · %@",method[@"encoding"],[method[@"supported"] boolValue]?@"Hook supported":method[@"unsupportedReason"]],@"method":method}];view.rows=rows;__weak LXApp *weak=self;__weak LXBrowser *weakView=view;
 view.selected=^(NSDictionary *row) {
  NSDictionary *m=row[@"method"];LXBrowser *detail=[LXBrowser new];detail.title=m[@"selector"];
  detail.rows=@[@{@"title":@"Selector / type encoding / provenance",@"subtitle":m[@"encoding"],@"action":@"info"},@{@"title":@"Enable hook",@"subtitle":[m[@"supported"] boolValue]?@"Reviewed ABI":m[@"unsupportedReason"],@"action":@"enable",@"enabled":m[@"supported"]},@{@"title":@"Disable hook",@"subtitle":@"Restores original if no conflict",@"action":@"disable",@"enabled":m[@"supported"]}];
  __weak LXBrowser *weakDetail=detail;detail.selected=^(NSDictionary *item) {
   NSString *action=item[@"action"];if([action isEqual:@"info"]) { LXShowJSON(weakDetail,@"Method metadata",m);return; }
   if(![m[@"supported"] boolValue]) { LXAlert(weakDetail,m[@"unsupportedReason"]);return; }
   NSString *key=[NSString stringWithFormat:@"%@%@/%@",[m[@"classMethod"] boolValue]?@"+":@"-",m[@"class"],m[@"selector"]];
   [weak request:[action isEqual:@"enable"]?@"hookEnable":@"hookDisable" payload:[action isEqual:@"enable"]?m:@{@"key":key} session:s view:weakDetail done:^(NSDictionary *result) { LXShowJSON(weakDetail,@"Hook result",result); }];
  };[weakView.navigationController pushViewController:detail animated:YES];
 };[parent.navigationController pushViewController:view animated:YES];
}
- (void)logs:(NSArray *)logs parent:(UIViewController *)parent {
 LXBrowser *view=[LXBrowser new];view.title=@"Bounded call logs";NSMutableArray *rows=[NSMutableArray new];
 for(NSDictionary *event in logs.reverseObjectEnumerator) [rows addObject:@{@"title":event[@"hook"],@"subtitle":[NSString stringWithFormat:@"%@ · thread %@ · %@ ns",event[@"time"],event[@"thread"],event[@"durationNs"]],@"event":event}];view.rows=rows;__weak LXBrowser *weak=view;view.selected=^(NSDictionary *row) { LXShowJSON(weak,@"Call details",row[@"event"]); };[parent.navigationController pushViewController:view animated:YES];
}
@end
int main(int argc,char **argv) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(LXApp.class)); } }
