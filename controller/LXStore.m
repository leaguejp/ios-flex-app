#import "LXStore.h"
#import "../shared/LXProtocol.h"
#import "../shared/LXTypes.h"
#import <CommonCrypto/CommonDigest.h>
// Saved JSON is untrusted, including syntactically valid but incorrectly typed records.
static NSDictionary *LXStoredState(id value) {
 if(![value isKindOfClass:NSDictionary.class]) return @{};
 NSMutableDictionary *state=[value mutableCopy];
 NSDictionary *expected=@{@"history":NSArray.class,@"logs":NSArray.class,@"desiredHooks":NSDictionary.class,@"patches":NSDictionary.class,@"identity":NSDictionary.class,@"hookState":NSDictionary.class,@"updatedAt":NSNumber.class,@"applyOnLaunch":NSNumber.class,@"autoRestoreHooks":NSNumber.class};
 for(NSString *key in expected) if(state[key] && ![state[key] isKindOfClass:expected[key]]) [state removeObjectForKey:key];
 NSMutableArray *history=[NSMutableArray new];NSArray *old=state[@"history"] ?: @[];
 for(NSUInteger i=old.count>8?old.count-8:0;i<old.count;i++) {
  id item=old[i];if([item isKindOfClass:NSDictionary.class] && [item[@"command"] isKindOfClass:NSString.class] && [item[@"response"] isKindOfClass:NSDictionary.class] && [item[@"time"] isKindOfClass:NSNumber.class]) [history addObject:item];
 }
 if(state[@"history"]) state[@"history"]=history;
 if(state[@"logs"] && LXResultReason(@"logs",@{@"logs":state[@"logs"]},@{})) [state removeObjectForKey:@"logs"];
 for(NSString *field in @[@"desiredHooks",@"patches"]) {
  if(!state[field]) continue;NSMutableDictionary *clean=[NSMutableDictionary new];
  for(NSString *key in state[field]) {
   id entry=state[field][key];if(![entry isKindOfClass:NSDictionary.class]) continue;
   if([field isEqual:@"desiredHooks"] && (![entry[@"request"] isKindOfClass:NSDictionary.class] || ![entry[@"enabled"] isKindOfClass:NSNumber.class])) continue;
   clean[key]=entry;
  }
  state[field]=clean;
 }
 return state;
}
@implementation LXStore
- (NSURL *)root {
 NSURL *base=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
 NSURL *root=[base URLByAppendingPathComponent:@"jp.league.runtimeatlas.controller" isDirectory:YES];
 [NSFileManager.defaultManager createDirectoryAtURL:root withIntermediateDirectories:YES attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} error:nil];return root;
}
- (NSURL *)file:(NSString *)bundle {
 NSData *bytes=[bundle dataUsingEncoding:NSUTF8StringEncoding];unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(bytes.bytes,(CC_LONG)bytes.length,digest);char hex[65];for(unsigned i=0;i<32;i++) snprintf(hex+i*2,3,"%02x",digest[i]);NSString *name=@(hex);
 return [[self root] URLByAppendingPathComponent:[name stringByAppendingString:@".json"]];
}
- (NSDictionary *)stateForBundle:(NSString *)bundle {
 NSData *data=nil;NSFileHandle *file=nil;
 @try { file=[NSFileHandle fileHandleForReadingFromURL:[self file:bundle] error:nil];data=[file readDataUpToLength:16*1024*1024+1 error:nil]; }
 @catch(NSException *exception) { (void)exception; }
 @finally { [file closeAndReturnError:nil]; }
 if(!data || data.length>16*1024*1024) return @{};
 return LXStoredState([NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
}
- (BOOL)save:(NSDictionary *)state bundle:(NSString *)bundle {
 NSMutableDictionary *bounded=[LXStoredState(state) mutableCopy];NSMutableArray *history=[bounded[@"history"] mutableCopy] ?: [NSMutableArray new];
 NSData *data=[NSJSONSerialization dataWithJSONObject:bounded options:NSJSONWritingSortedKeys error:nil];
 while(data.length>16*1024*1024 && history.count) { [history removeObjectAtIndex:0];bounded[@"history"]=history;bounded[@"historyTruncated"]=@YES;data=[NSJSONSerialization dataWithJSONObject:bounded options:NSJSONWritingSortedKeys error:nil]; }
 return data && data.length<=16*1024*1024 && [data writeToURL:[self file:bundle] options:NSDataWritingAtomic error:nil];
}
- (NSString *)savePatch:(NSDictionary *)patch method:(NSDictionary *)method bundle:(NSString *)bundle {
 if(!bundle.length || ![method isKindOfClass:NSDictionary.class] || ![method[@"class"] isKindOfClass:NSString.class] || ![method[@"selector"] isKindOfClass:NSString.class] || ![method[@"encoding"] isKindOfClass:NSString.class] || ![method[@"classMethod"] isKindOfClass:NSNumber.class] || ![method[@"supported"] isKindOfClass:NSNumber.class] || ![method[@"supported"] boolValue]) return @"Unsupported or malformed method definition";
 NSString *reason=LXPatchReason(patch,method[@"encoding"]);if(reason) return reason;
 if([method[@"provenance"] isEqual:@"Static Only"]) { reason=LXStaticHookReason(bundle,method[@"class"],method[@"selector"],[method[@"classMethod"] boolValue],method[@"encoding"]);if(reason) return reason; }
 else if(![method[@"provenance"] isEqual:@"Runtime Loaded"]) return @"Unknown method provenance";
 NSString *key=[NSString stringWithFormat:@"%@%@/%@",[method[@"classMethod"] boolValue]?@"+":@"-",method[@"class"],method[@"selector"]];
 NSMutableDictionary *state=[[self stateForBundle:bundle] mutableCopy],*patches=[state[@"patches"] mutableCopy] ?: [NSMutableDictionary new],*desired=[state[@"desiredHooks"] mutableCopy] ?: [NSMutableDictionary new];
 patches[key]=patch;desired[key]=@{@"request":method,@"enabled":desired[key][@"enabled"] ?: @NO};state[@"patches"]=patches;state[@"desiredHooks"]=desired;state[@"updatedAt"]=@(NSDate.date.timeIntervalSince1970);
 return [self save:state bundle:bundle]?nil:@"Patch could not be saved";
}
- (NSURL *)exportBundle:(NSString *)bundle error:(NSError **)error {
 NSMutableDictionary *out=[[self stateForBundle:bundle] mutableCopy];out[@"bundle"]=bundle;out[@"schemaVersion"]=@1;out[@"exportedAt"]=@(NSDate.date.timeIntervalSince1970);
 NSData *data=[NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:error];
 NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"RuntimeAtlas-%@.json",NSUUID.UUID.UUIDString]]];
 return [data writeToURL:url options:NSDataWritingAtomic error:error]?url:nil;
}
@end
