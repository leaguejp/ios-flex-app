// Drives actual UIKit Agent through production Controller session manager and framed IPC.
#import <Foundation/Foundation.h>
#import "../controller/LXController.h"
#include <assert.h>
static void pump(NSTimeInterval seconds) { [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]]; }
static NSDictionary *request(LXController *c,LXSession *s,NSString *cmd,NSDictionary *p) {
 __block NSDictionary *response=nil;
 [c request:cmd payload:p session:s completion:^(NSDictionary *r) { response=r; }];
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:35];while(!response && deadline.timeIntervalSinceNow>0) pump(0.01);
 if(!response || (response[@"error"] && response[@"error"]!=NSNull.null)) { NSLog(@"Failed command %@: %@",cmd,response[@"error"]);abort(); }
 return response[@"payload"];
}
static void checkCalls(NSDictionary *p) {
 assert([p[@"pings"] integerValue]==1 && [p[@"objectIdentity"] boolValue] && [p[@"integer"] integerValue]==42 && [p[@"bool"] boolValue] && [p[@"float"] doubleValue]==3 && [p[@"double"] doubleValue]==5 && [p[@"classValue"] integerValue]==42);
}
int main(void) { @autoreleasepool {
 LXController *controller=[LXController new];assert([controller start:nil]);
 NSString *device=NSProcessInfo.processInfo.environment[@"LX_SIMULATOR_UDID"];assert(device);
 NSTask *launch=[NSTask new];launch.executableURL=[NSURL fileURLWithPath:@"/usr/bin/xcrun"];launch.arguments=@[@"simctl",@"launch",device,@"jp.league.runtimeatlas.fixture",@"--lx-test-token",controller.token];assert([launch launchAndReturnError:nil]);[launch waitUntilExit];assert(launch.terminationStatus==0);
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:30];while(!controller.sessions.count && deadline.timeIntervalSinceNow>0) pump(.01);assert(controller.sessions.count==1);
 LXSession *session=controller.sessions[0];assert([session.identity[@"bundle"] isEqual:@"jp.league.runtimeatlas.fixture"]);
 NSString *nonce=NSUUID.UUID.UUIDString;NSDictionary *ping=request(controller,session,@"ping",@{@"nonce":nonce});assert([ping[@"echo"][@"nonce"] isEqual:nonce]);
 request(controller,session,@"activate",@{});assert(session.active);
 NSDictionary *images=request(controller,session,@"images",@{});NSString *image;
 for(NSDictionary *item in images[@"images"]) { assert([item[@"provenance"] isEqual:@"Runtime Loaded"]);if([item[@"name"] isEqual:@"AtlasTestTarget"]) image=item[@"path"]; }assert(image);
 BOOL found=NO;NSUInteger offset=0;
 do { NSDictionary *page=request(controller,session,@"classes",@{@"image":image,@"offset":@(offset)});
  for(NSDictionary *cls in page[@"classes"]) if([cls[@"name"] isEqual:@"LXFixture"]) found=YES;
  offset=[page[@"next"] unsignedIntegerValue];if(offset>=[page[@"total"] unsignedIntegerValue]) break;
 }while(1);assert(found);
 NSDictionary *methods=request(controller,session,@"methods",@{@"class":@"LXFixture",@"offset":@0});NSMutableArray *supported=[NSMutableArray new];
 for(NSDictionary *m in methods[@"methods"]) { assert([m[@"encoding"] length]>0);assert([m[@"provenance"] isEqual:@"Runtime Loaded"]);
  if([m[@"supported"] boolValue]) [supported addObject:m];
  if([m[@"selector"] isEqual:@"point:"] || [m[@"selector"] isEqual:@"variadic:"]) assert(![m[@"supported"] boolValue] && [m[@"unsupportedReason"] length]);
 }assert(supported.count==7);
 checkCalls(request(controller,session,@"fixtureRun",@{}));assert([request(controller,session,@"logs",@{})[@"logs"] count]==0);
 for(NSDictionary *m in supported) request(controller,session,@"hookEnable",m);
 checkCalls(request(controller,session,@"fixtureRun",@{}));NSArray *logs=request(controller,session,@"logs",@{})[@"logs"];assert(logs.count==7);
 for(NSDictionary *event in logs) assert(event[@"class"] && event[@"selector"] && event[@"encoding"] && event[@"arguments"] && event[@"return"] && event[@"time"] && event[@"thread"] && event[@"durationNs"]);
 for(NSDictionary *state in request(controller,session,@"state",@{})[@"hooks"]) request(controller,session,@"hookDisable",@{@"key":state[@"key"]});
 checkCalls(request(controller,session,@"fixtureRun",@{}));assert([request(controller,session,@"logs",@{})[@"logs"] count]==logs.count);
 NSDictionary *staticResult=request(controller,session,@"static",@{});assert([staticResult[@"images"] count]>0);for(NSDictionary *item in staticResult[@"images"]) assert([item[@"provenance"] isEqual:@"Static Only"]);
 request(controller,session,@"state",@{});NSDictionary *saved=[controller.store stateForBundle:session.identity[@"bundle"]];assert(saved[@"desiredHooks"] && saved[@"hookState"] && [saved[@"logs"] count]==7);
 NSURL *export=[controller.store exportBundle:session.identity[@"bundle"] error:nil];assert(export);NSData *bytes=[NSData dataWithContentsOfURL:export];assert(bytes);assert(![[[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding] containsString:controller.token]);
 [bytes writeToFile:@"artifacts/simulator/integration-export.json" atomically:YES];
 request(controller,session,@"deactivate",@{});assert(!session.active);
 puts("Simulator integration PASS: actual Agent, Controller sessions, IPC, loaded images/classes/methods, 7 hooks/originals/logs/disable, static provenance, per-bundle persistence and export");
 puts("Simulator results are not physical iOS sandbox or jailbreak validation.");
 }return 0; }
